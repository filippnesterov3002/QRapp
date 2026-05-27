import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';

// CORS-заголовки для браузерных запросов
const _kCors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// Порты, которые пробуем по порядку
const _kPorts = [8080, 8081, 8082];

class WifiServer {
  HttpServer? _server;
  int? _port;
  final void Function(String) _onLog;

  WifiServer({required void Function(String) onLog}) : _onLog = onLog;

  bool get isRunning => _server != null;
  int? get port => _port;

  // Запустить сервер, вернуть занятый порт или null
  Future<int?> start() async {
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware)
        .addHandler(_buildRouter());

    for (final p in _kPorts) {
      try {
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, p);
        _port = p;
        _logEvent('Сервер запущен на порту $p');
        return p;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  // Остановить сервер
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
    _logEvent('Сервер остановлен');
  }

  void _logEvent(String msg) {
    final t = DateFormat('HH:mm').format(DateTime.now());
    _onLog('$t — $msg');
  }

  // Middleware: добавляет CORS-заголовки и обрабатывает preflight
  static Handler _corsMiddleware(Handler inner) {
    return (Request req) async {
      if (req.method == 'OPTIONS') {
        return Response.ok('', headers: _kCors);
      }
      final resp = await inner(req);
      return resp.change(headers: {...resp.headers, ..._kCors});
    };
  }

  // Построить роутер со всеми маршрутами
  Router _buildRouter() {
    final r = Router();
    r.get('/', _handleRoot);
    r.get('/rooms', _handleRooms);
    r.get('/export', _handleExport);
    r.post('/import', _handleImport);
    r.get('/status', _handleStatus);
    return r;
  }

  // ── GET / — HTML-страница ─────────────────────────────────────────────────

  Future<Response> _handleRoot(Request req) async {
    return Response.ok(_kHtmlPage,
        headers: {'Content-Type': 'text/html; charset=utf-8'});
  }

  // ── GET /rooms — список помещений ────────────────────────────────────────

  Future<Response> _handleRooms(Request req) async {
    try {
      final box = Hive.box<Item>('items');
      final counts = <String, int>{};
      for (final item in box.values) {
        final room = item.location.room.trim();
        if (room.isEmpty) continue;
        counts[room] = (counts[room] ?? 0) + 1;
      }
      final rooms = (counts.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .map((e) => {'name': e.key, 'count': e.value})
          .toList();
      _logEvent('Запрос помещений (${rooms.length})');
      return _json({'rooms': rooms});
    } catch (e) {
      return _json({'error': e.toString()}, status: 500);
    }
  }

  // ── GET /export?rooms=name1,name2 — скачать JSON ─────────────────────────

  Future<Response> _handleExport(Request req) async {
    try {
      final param = req.url.queryParameters['rooms'];
      final selected = (param != null && param.isNotEmpty)
          ? param.split(',').map((s) => s.trim()).toSet()
          : null;

      final box = Hive.box<Item>('items');
      final items = box.values.where((item) {
        if (selected == null || selected.isEmpty) return true;
        return selected.contains(item.location.room.trim());
      }).toList();

      final now = DateTime.now();
      final fileDate = DateFormat('yyyy-MM-dd').format(now);
      final fileName = 'Инвентаризация_$fileDate.json';

      final body = jsonEncode({
        'version': '1.0',
        'exported_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now),
        'app': 'InventoryApp',
        'axioma_compatible': true,   // поля совместимы с axioma.asset
        'items': items.map(_itemToJson).toList(),
        'total': items.length,
      });

      _logEvent('Скачан файл (${items.length} предметов)');
      return Response.ok(body, headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Disposition': 'attachment; filename="$fileName"',
      });
    } catch (e) {
      return _json({'error': e.toString()}, status: 500);
    }
  }

  // ── POST /import — загрузить JSON ────────────────────────────────────────

  Future<Response> _handleImport(Request req) async {
    try {
      final body = await req.readAsString();
      Map<String, dynamic> data;
      try {
        data = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        return _json({'status': 'error', 'message': 'Неверный формат JSON'});
      }

      // Проверка наличия поля items
      if (data['items'] is! List) {
        return _json({'status': 'error', 'message': 'Неверный формат файла'});
      }
      final rawItemsRaw =
          (data['items'] as List).whereType<Map<String, dynamic>>().toList();
      if (rawItemsRaw.isEmpty) {
        return _json(
            {'status': 'error', 'message': 'Файл не содержит предметов'});
      }

      // Определяем формат: наш (InventoryApp) или Аксиомы
      final isOurFormat = data['app'] == 'InventoryApp';
      final isAxiomaFmt = !isOurFormat && _isAxiomaItem(rawItemsRaw.first);
      if (!isOurFormat && !isAxiomaFmt) {
        return _json({
          'status': 'error',
          'message': 'Неверный формат файла. Поддерживается формат InventoryApp и Аксиома.'
        });
      }

      // Нормализуем все записи к внутреннему формату (ключи нашего приложения)
      final rawItems = rawItemsRaw.map(_normalizeItem).toList();

      final box = Hive.box<Item>('items');
      final existingById = <String, Item>{
        for (final i in box.values)
          if (i.itemId != null) i.itemId!: i,
      };
      final existingRooms = box.values
          .map((i) => i.location.room.trim())
          .where((r) => r.isNotEmpty)
          .toSet();

      // Разделить на новые и дубликаты
      final duplicateIds = <String>[];
      final newRaws = <Map<String, dynamic>>[];
      for (final raw in rawItems) {
        final id = raw['item_id']?.toString() ?? '';
        if (id.isNotEmpty && existingById.containsKey(id)) {
          duplicateIds.add(id);
        } else {
          newRaws.add(raw);
        }
      }

      // Если дубликаты есть, а решение не принято — спросить
      final dupAction = req.url.queryParameters['duplicates'];
      if (duplicateIds.isNotEmpty && dupAction == null) {
        return _json({
          'status': 'duplicates_found',
          'duplicates': duplicateIds,
          'message': 'Найдено ${duplicateIds.length} дубликатов. Что сделать?',
        });
      }

      // Новые помещения (после нормализации поле называется 'location')
      final newRooms = <String>{};
      for (final raw in rawItems) {
        final room = raw['location']?.toString().trim() ?? '';
        if (room.isNotEmpty && !existingRooms.contains(room)) {
          newRooms.add(room);
        }
      }

      // Генерация уникальных id
      final usedItemIds = existingById.keys.toSet();
      int nextInt = box.isEmpty
          ? 1
          : box.values.map((i) => i.id).reduce(max) + 1;

      int added = 0;
      int updated = 0;

      // Добавить новые предметы
      for (final raw in newRaws) {
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final itemId = _uniqueId(raw['item_id']?.toString() ?? '', usedItemIds);
        usedItemIds.add(itemId);
        final item = _makeItem(raw, itemId: itemId, intId: nextInt++);
        await box.add(item);
        await ChangeLogService.logImported(item, source: 'import_wifi');
        added++;
      }

      // Обработать дубликаты
      if (dupAction == 'update') {
        for (final itemId in duplicateIds) {
          final existing = existingById[itemId];
          if (existing == null) continue;
          final raw = rawItems.firstWhere(
              (r) => r['item_id']?.toString() == itemId,
              orElse: () => {});
          if (raw.isEmpty) continue;
          final name = raw['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final updatedItem = _makeItem(
            raw,
            itemId: itemId,
            intId: existing.id,
            base: existing,
          );
          await box.put(existing.key, updatedItem);
          await ChangeLogService.logConflict(
              existing, updatedItem, source: 'import_wifi');
          updated++;
        }
      }

      final skipped =
          (dupAction == 'skip' || dupAction == null) ? duplicateIds.length : 0;
      _logEvent('Загружен файл ($added новых, $updated обновлено, $skipped пропущено)');

      return _json({
        'status': 'ok',
        'new_items': added,
        'duplicates': updated + skipped,
        'new_rooms': newRooms.length,
      });
    } catch (e) {
      return _json({'status': 'error', 'message': e.toString()}, status: 500);
    }
  }

  // ── GET /status ───────────────────────────────────────────────────────────

  Future<Response> _handleStatus(Request req) async {
    final box = Hive.box<Item>('items');
    final rooms = box.values
        .map((i) => i.location.room.trim())
        .where((r) => r.isNotEmpty)
        .toSet();
    return _json({
      'status': 'running',
      'app': 'InventoryApp',
      'total_items': box.length,
      'total_rooms': rooms.length,
    });
  }

  // ── Вспомогательные методы ────────────────────────────────────────────────

  Response _json(Map<String, dynamic> body, {int status = 200}) => Response(
        status,
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );

  Map<String, dynamic> _itemToJson(Item item) {
    final cat = categoryByKey(item.category);
    return {
      // Поля axioma.asset — совместимый формат
      'assetnum':         item.itemId ?? '',
      'x_inventarnum':    item.itemId ?? '',
      'description':      item.name,
      'classstructureid': item.category ?? '',
      'reatroom':         item.location.room.trim(),
      'location':         item.location.room.trim(),
      'orderqty':         item.quantity ?? 0,
      'installdate':      item.createdAt?.toIso8601String() ?? '',
      'changedate':       item.updatedAt?.toIso8601String() ?? '',
      // Вспомогательное поле: читаемое название категории
      '_category_name':   cat?.name ?? '',
    };
  }

  // Создать Item из сырых данных JSON
  Item _makeItem(
    Map<String, dynamic> raw, {
    required String itemId,
    required int intId,
    Item? base, // если обновление — берём поля из оригинала
  }) {
    final name = raw['name']?.toString().trim() ?? '';
    final room = raw['location']?.toString().trim() ?? '';
    final qty =
        int.tryParse(raw['quantity']?.toString() ?? '') ?? base?.quantity ?? 0;
    final cat = _catByName(raw['category']?.toString());
    final responsible = raw['responsible_person']?.toString().trim();
    final createdAt = base?.createdAt ??
        DateTime.tryParse(raw['created_at']?.toString() ?? '') ??
        DateTime.now();
    final updatedAt = base != null
        ? DateTime.now()
        : DateTime.tryParse(raw['updated_at']?.toString() ?? '') ??
            DateTime.now();

    return Item(
      id: intId,
      name: name,
      description: base?.description ?? '',
      location: Location(
        id: base?.location.id ?? 0,
        floor: base?.location.floor ?? '',
        room: room.isNotEmpty ? room : (base?.location.room ?? ''),
        type: base?.location.type ?? '',
        description: base?.location.description,
      ),
      quantity: qty,
      imagePath: base?.imagePath,
      inventoryNumber: base?.inventoryNumber,
      responsiblePerson: (responsible?.isNotEmpty == true)
          ? responsible
          : base?.responsiblePerson,
      itemId: itemId,
      category: cat?.key ?? base?.category,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Гарантировать уникальный itemId
  String _uniqueId(String proposed, Set<String> used) {
    if (proposed.isNotEmpty && !used.contains(proposed)) return proposed;
    var n = 1;
    while (true) {
      final c = 'ITEM-${n.toString().padLeft(3, '0')}';
      if (!used.contains(c)) return c;
      n++;
    }
  }

  // Поиск категории по названию или ключу
  ItemCategory? _catByName(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      // Сначала ищем по точному ключу (наш формат: 'furniture', 'tech' …)
      return kCategories.firstWhere((c) => c.key == name);
    } catch (_) {}
    try {
      // Затем по вхождению отображаемого названия
      return kCategories
          .firstWhere((c) => name.toLowerCase().contains(c.name.toLowerCase()));
    } catch (_) {
      return null;
    }
  }

  // Определить, является ли запись форматом Аксиомы
  bool _isAxiomaItem(Map<String, dynamic> raw) {
    return raw.containsKey('assetnum') ||
        raw.containsKey('x_inventarnum') ||
        raw.containsKey('assetuid');
  }

  // Нормализация записи: привести поля Аксиомы к внутреннему формату приложения.
  // Если запись уже в нашем формате — возвращаем без изменений.
  Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw) {
    if (!_isAxiomaItem(raw)) return raw;

    // Помещение: предпочитаем reatroom → axiroom → location (код)
    final room = (raw['reatroom']?.toString().trim().isNotEmpty == true
            ? raw['reatroom']
            : raw['axiroom']?.toString().trim().isNotEmpty == true
                ? raw['axiroom']
                : raw['location'])
        ?.toString()
        .trim() ?? '';

    return {
      'item_id':    raw['assetnum']?.toString().trim() ??
                    raw['x_inventarnum']?.toString().trim() ?? '',
      'name':       raw['description']?.toString().trim() ?? '',
      'category':   raw['classstructureid']?.toString().trim() ?? '',
      'location':   room,
      'quantity':   raw['orderqty'] ?? raw['quantity'] ?? 0,
      'created_at': raw['installdate']?.toString() ??
                    raw['commdate']?.toString() ?? '',
      'updated_at': raw['changedate']?.toString() ?? '',
      'responsible_person': raw['responsible']?.toString().trim() ?? '',
    };
  }
}

// ── Встроенная HTML-страница ─────────────────────────────────────────────────

const _kHtmlPage = '''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Инвентаризация — WiFi передача</title>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:sans-serif;background:#f5f5f5;color:#333;min-height:100vh}
  header{background:#A80000;color:#fff;padding:16px 20px}
  header h1{font-size:20px;font-weight:700}
  header p{font-size:13px;opacity:.8;margin-top:4px}
  main{padding:20px;max-width:700px;margin:0 auto}
  section{background:#fff;border-radius:12px;padding:20px;margin-bottom:16px;
          box-shadow:0 1px 4px rgba(0,0,0,.08)}
  h2{font-size:16px;color:#A80000;margin-bottom:12px;font-weight:600}
  .hint{font-size:13px;color:#888;margin-bottom:10px}
  .room-list{border:1px solid #f0f0f0;border-radius:8px;overflow:hidden;margin:10px 0}
  .room-row{display:flex;align-items:center;padding:10px 14px;
            border-bottom:1px solid #f5f5f5;transition:background .15s}
  .room-row:last-child{border-bottom:none}
  .room-row:hover{background:#fafafa}
  .room-row input[type=checkbox]{width:17px;height:17px;accent-color:#A80000;
                                  margin-right:12px;flex-shrink:0;cursor:pointer}
  .room-row label{flex:1;font-size:14px;cursor:pointer}
  .room-badge{font-size:12px;color:#888;white-space:nowrap}
  .ctrl{display:flex;gap:12px;margin-bottom:8px}
  .ctrl a{font-size:13px;color:#A80000;cursor:pointer;text-decoration:underline}
  .empty{padding:14px;text-align:center;color:#aaa;font-size:14px}
  button{display:block;width:100%;background:#A80000;color:#fff;border:none;
         border-radius:8px;padding:13px;font-size:15px;cursor:pointer;
         margin-top:12px;font-weight:500;transition:background .15s}
  button:hover{background:#8B0000}
  button:disabled{background:#ccc;cursor:default}
  .file-wrap{border:2px dashed #ddd;border-radius:8px;padding:12px;
             margin:10px 0;text-align:center}
  .file-wrap input[type=file]{display:block;width:100%;
                               font-size:14px;cursor:pointer}
  .status{margin-top:12px;padding:12px 14px;border-radius:8px;
          font-size:14px;display:none;white-space:pre-line;line-height:1.5}
  .ok{background:#e8f5e9;color:#2e7d32;display:block}
  .err{background:#ffebee;color:#c62828;display:block}
  .info{background:#e3f2fd;color:#1565c0;display:block}
</style>
</head>
<body>
<header>
  <h1>📦 Инвентаризация</h1>
  <p>Передача файлов по WiFi</p>
</header>
<main>

<section>
  <h2>📥 Скачать данные с телефона</h2>
  <p class="hint">Выберите помещения для выгрузки:</p>
  <div class="ctrl">
    <a onclick="selAll()">Выбрать все</a>
    <span style="color:#ddd">|</span>
    <a onclick="selNone()">Снять все</a>
  </div>
  <div class="room-list" id="roomList">
    <div class="empty">Загрузка...</div>
  </div>
  <button onclick="download()">📥 Скачать JSON файл</button>
</section>

<section>
  <h2>📤 Загрузить данные на телефон</h2>
  <p class="hint">Выберите JSON файл, экспортированный из приложения:</p>
  <div class="file-wrap">
    <input type="file" accept=".json" id="fileInput">
  </div>
  <button onclick="upload()">📤 Загрузить JSON файл</button>
  <div class="status" id="st"></div>
</section>

</main>
<script>
var rooms=[];
async function loadRooms(){
  try{
    var r=await fetch('/rooms');
    var d=await r.json();
    rooms=d.rooms||[];
    renderRooms();
  }catch(e){
    document.getElementById('roomList').innerHTML=
      '<div class="empty" style="color:#c62828">Ошибка загрузки помещений</div>';
  }
}
function renderRooms(){
  var el=document.getElementById('roomList');
  if(!rooms.length){el.innerHTML='<div class="empty">Нет помещений</div>';return;}
  el.innerHTML=rooms.map(function(r,i){
    return '<div class="room-row">'
      +'<input type="checkbox" id="r'+i+'" value="'+encodeURIComponent(r.name)+'" checked>'
      +'<label for="r'+i+'">'+r.name+'</label>'
      +'<span class="room-badge">'+r.count+' пр.</span>'
      +'</div>';
  }).join('');
}
function selAll(){document.querySelectorAll('#roomList input').forEach(function(c){c.checked=true});}
function selNone(){document.querySelectorAll('#roomList input').forEach(function(c){c.checked=false});}
function download(){
  var checked=[].slice.call(document.querySelectorAll('#roomList input:checked')).map(function(c){return c.value;});
  if(!checked.length){alert('Выберите хотя бы одно помещение');return;}
  window.location.href='/export?rooms='+checked.join(',');
}
async function upload(){
  var fi=document.getElementById('fileInput');
  var st=document.getElementById('st');
  if(!fi.files||!fi.files.length){showSt(st,'Выберите файл для загрузки','err');return;}
  var text;
  try{text=await fi.files[0].text();JSON.parse(text);}
  catch(e){showSt(st,'Файл повреждён или не является JSON','err');return;}
  showSt(st,'Отправка файла...','info');
  try{
    var r=await fetch('/import',{method:'POST',headers:{'Content-Type':'application/json'},body:text});
    var d=await r.json();
    if(d.status==='duplicates_found'){
      var yes=confirm('Найдено '+d.duplicates.length+' дубликатов.\n\nОК — обновить данными из файла.\nОтмена — пропустить дубликаты.');
      showSt(st,'Обработка дубликатов...','info');
      var r2=await fetch('/import?duplicates='+(yes?'update':'skip'),
        {method:'POST',headers:{'Content-Type':'application/json'},body:text});
      var d2=await r2.json();
      showResult(st,d2);
    }else{showResult(st,d);}
  }catch(e){showSt(st,'Ошибка соединения с сервером','err');}
}
function showResult(el,d){
  if(d.status==='ok'){
    showSt(el,'✅ Импорт завершён!\nДобавлено: '+d.new_items+' пр.\nДубликатов обработано: '+d.duplicates+'\nНовых помещений: '+d.new_rooms,'ok');
  }else{showSt(el,'❌ '+(d.message||'Ошибка импорта'),'err');}
}
function showSt(el,msg,cls){el.textContent=msg;el.className='status '+cls;}
loadRooms();
</script>
</body>
</html>''';
