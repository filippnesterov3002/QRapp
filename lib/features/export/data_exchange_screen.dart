import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';
import '../wifi/wifi_transfer_screen.dart';
import 'excel_export_screen.dart';

const _kRed = Color(0xFFA80000);

class DataExchangeScreen extends StatelessWidget {
  const DataExchangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset('assets/back_button.svg',
                width: 85, height: 43),
          ),
        ),
        title: const Text(
          'Обмен данными',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ── Беспроводной ────────────────────────────────────────────────────
          const _SectionLabel('Беспроводной'),
          const SizedBox(height: 8),
          _ExchangeTile(
            icon: Icons.wifi_rounded,
            iconColor: const Color(0xFF1565C0),
            title: 'Передача по Wi-Fi',
            subtitle: 'Экспорт и импорт через браузер в одной сети',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WifiTransferScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // ── Ручной обмен ────────────────────────────────────────────────────
          const _SectionLabel('Ручной обмен'),
          const SizedBox(height: 8),
          _ExchangeTile(
            icon: Icons.table_chart_outlined,
            iconColor: const Color(0xFF2E7D32),
            title: 'Выгрузить Excel',
            subtitle: 'Сохранить .xlsx файл с выбором помещений',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExcelExportScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _ExchangeTile(
            icon: Icons.upload_file_outlined,
            iconColor: _kRed,
            title: 'Экспорт JSON',
            subtitle: 'Поделиться / сохранить файл совместимый с Аксиомой',
            onTap: () => _exportJson(context),
          ),
          const SizedBox(height: 10),
          _ExchangeTile(
            icon: Icons.download_for_offline_outlined,
            iconColor: const Color(0xFF6A1B9A),
            title: 'Импорт JSON',
            subtitle: 'Загрузить данные из файла (InventoryApp или Аксиома)',
            onTap: () => _importJson(context),
          ),
          const SizedBox(height: 10),
          _ExchangeTile(
            icon: Icons.table_view_outlined,
            iconColor: const Color(0xFF00695C),
            title: 'Импорт Excel',
            subtitle: 'Загрузить .xlsx файл (наш формат или Аксиома)',
            onTap: () => _importExcel(context),
          ),
        ],
      ),
    );
  }

  // ── JSON-экспорт ───────────────────────────────────────────────────────────

  Future<void> _exportJson(BuildContext context) async {
    final box = Hive.box<Item>('items');
    if (box.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет данных для экспорта')),
      );
      return;
    }

    final now = DateTime.now();
    final body = jsonEncode({
      'version': '1.0',
      'exported_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now),
      'app': 'InventoryApp',
      'axioma_compatible': true,
      'items': box.values.map(_itemToJson).toList(),
      'total': box.length,
    });

    final tmp = await getTemporaryDirectory();
    final fileName =
        'Инвентаризация_${DateFormat('yyyy-MM-dd').format(now)}.json';
    final file = File('${tmp.path}/$fileName');
    await file.writeAsString(body, encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Инвентаризация — экспорт JSON',
    );
  }

  // ── JSON-импорт ────────────────────────────────────────────────────────────

  Future<void> _importJson(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final String content;
    try {
      content = await File(result.files.single.path!).readAsString();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
      }
      return;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный формат JSON')),
        );
      }
      return;
    }

    if (data['items'] is! List) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не содержит список предметов')),
        );
      }
      return;
    }

    final rawList =
        (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    if (rawList.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В файле нет предметов')),
        );
      }
      return;
    }

    final isOurFormat = data['app'] == 'InventoryApp';
    final isAxioma = !isOurFormat && _isAxiomaItem(rawList.first);
    if (!isOurFormat && !isAxioma) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неподдерживаемый формат файла'),
          ),
        );
      }
      return;
    }

    final normalized = rawList.map(_normalizeItem).toList();

    if (!context.mounted) return;
    await _doImport(
      context,
      normalized,
      source: isAxioma ? 'import_axioma' : 'import_json',
    );
  }

  Future<void> _doImport(
    BuildContext context,
    List<Map<String, dynamic>> rawItems, {
    String source = 'import_json',
  }) async {
    final box = Hive.box<Item>('items');
    final existingById = <String, Item>{
      for (final i in box.values)
        if (i.itemId != null) i.itemId!: i,
    };

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

    // Спросить про дубликаты
    bool updateDuplicates = false;
    if (duplicateIds.isNotEmpty && context.mounted) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Найдены дубликаты'),
          content: Text(
            'Найдено ${duplicateIds.length} предметов, которые уже есть в базе.\n\n'
            'Обновить их данными из файла?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Пропустить'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Обновить'),
            ),
          ],
        ),
      );
      updateDuplicates = choice == true;
    }

    final usedItemIds = existingById.keys.toSet();
    int nextInt = box.isEmpty
        ? 1
        : box.values.map((i) => i.id).reduce(max) + 1;

    int added = 0;
    int updated = 0;

    for (final raw in newRaws) {
      final name = raw['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final itemId = _uniqueId(raw['item_id']?.toString() ?? '', usedItemIds);
      usedItemIds.add(itemId);
      final item = _makeItem(raw, itemId: itemId, intId: nextInt++);
      await box.add(item);
      await ChangeLogService.logImported(item, source: source);
      added++;
    }

    if (updateDuplicates) {
      for (final id in duplicateIds) {
        final existing = existingById[id];
        if (existing == null) continue;
        final raw = rawItems.firstWhere(
          (r) => r['item_id']?.toString() == id,
          orElse: () => {},
        );
        if (raw.isEmpty) continue;
        final name = raw['name']?.toString().trim() ?? '';
        if (name.isEmpty) continue;
        final newItem =
            _makeItem(raw, itemId: id, intId: existing.id, base: existing);
        await box.put(existing.key, newItem);
        await ChangeLogService.logConflict(existing, newItem, source: source);
        updated++;
      }
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        content: Text(
          '✅ Импорт завершён: добавлено $added, обновлено $updated',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Excel-импорт ──────────────────────────────────────────────────────────

  Future<void> _importExcel(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.path == null) return;

    List<int> bytes;
    try {
      bytes = await File(result.files.single.path!).readAsBytes();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
      }
      return;
    }

    xl.Excel workbook;
    try {
      workbook = xl.Excel.decodeBytes(bytes);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Неверный формат Excel файла')),
        );
      }
      return;
    }

    if (workbook.tables.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не содержит листов')),
        );
      }
      return;
    }

    final sheet = workbook.tables[workbook.tables.keys.first]!;
    if (sheet.rows.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет данных для импорта')),
        );
      }
      return;
    }

    // Заголовки из первой строки (в нижнем регистре для сравнения)
    final headers = sheet.rows.first
        .map((c) => c?.value?.toString().trim().toLowerCase() ?? '')
        .toList();

    // Определяем формат по заголовкам
    final isAxioma = headers.contains('assetnum') ||
        headers.contains('description') ||
        headers.contains('classstructureid');

    String cell(List<xl.Data?> row, String header) {
      final idx = headers.indexOf(header.toLowerCase());
      if (idx < 0 || idx >= row.length) return '';
      final v = row[idx]?.value;
      if (v == null) return '';
      // DateCellValue возвращает DateTime через toString — нормализуем к ISO
      if (v is xl.DateCellValue) {
        return v.asDateTimeLocal().toIso8601String();
      }
      return v.toString().trim();
    }

    final rawItems = <Map<String, dynamic>>[];

    for (var i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.every((c) => c == null || c.value == null)) continue;

      final Map<String, dynamic> raw;
      if (isAxioma) {
        final room = cell(row, 'reatroom').isNotEmpty
            ? cell(row, 'reatroom')
            : cell(row, 'axiroom').isNotEmpty
                ? cell(row, 'axiroom')
                : cell(row, 'location');
        raw = {
          'item_id': cell(row, 'assetnum').isNotEmpty
              ? cell(row, 'assetnum')
              : cell(row, 'x_inventarnum'),
          'name': cell(row, 'description'),
          'category': cell(row, 'classstructureid'),
          'location': room,
          'quantity': int.tryParse(cell(row, 'orderqty')) ??
              int.tryParse(cell(row, 'quantity')) ?? 0,
          'created_at': _toIso(cell(row, 'installdate').isNotEmpty
              ? cell(row, 'installdate')
              : cell(row, 'commdate')),
          'updated_at': _toIso(cell(row, 'changedate')),
          'responsible_person': cell(row, 'responsible'),
        };
      } else {
        // Наш формат: заголовки на русском
        raw = {
          'item_id': cell(row, 'артикул'),
          'name': cell(row, 'наименование'),
          'category': cell(row, 'категория'),
          'location': cell(row, 'помещение'),
          'quantity': int.tryParse(cell(row, 'количество')) ?? 0,
          'created_at': _toIso(cell(row, 'дата добавления')),
          'updated_at': _toIso(cell(row, 'дата изменения')),
          'responsible_person': '',
        };
      }

      if ((raw['name'] as String).isEmpty) continue;
      rawItems.add(raw);
    }

    if (rawItems.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не найдено предметов для импорта')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await _doImport(
      context,
      rawItems,
      source: isAxioma ? 'import_axioma' : 'import_excel',
    );
  }

  /// Приводит строки "dd.MM.yyyy HH:mm" и ISO к единому ISO-формату.
  /// Нужно потому что Excel-экспорт пишет даты как "21.04.2026 14:30".
  String _toIso(String s) {
    if (s.isEmpty || s == '—') return '';
    if (DateTime.tryParse(s) != null) return s;
    for (final fmt in ['dd.MM.yyyy HH:mm', 'dd.MM.yyyy']) {
      try {
        return DateFormat(fmt).parse(s).toIso8601String();
      } catch (_) {}
    }
    return '';
  }

  // ── Вспомогательные методы (повторяют логику WifiServer) ──────────────────

  Map<String, dynamic> _itemToJson(Item item) {
    final cat = categoryByKey(item.category);
    return {
      'assetnum': item.itemId ?? '',
      'x_inventarnum': item.itemId ?? '',
      'description': item.name,
      'classstructureid': item.category ?? '',
      'reatroom': item.location.room.trim(),
      'location': item.location.room.trim(),
      'orderqty': item.quantity ?? 0,
      'installdate': item.createdAt?.toIso8601String() ?? '',
      'changedate': item.updatedAt?.toIso8601String() ?? '',
      '_category_name': cat?.name ?? '',
    };
  }

  bool _isAxiomaItem(Map<String, dynamic> raw) =>
      raw.containsKey('assetnum') ||
      raw.containsKey('x_inventarnum') ||
      raw.containsKey('assetuid');

  Map<String, dynamic> _normalizeItem(Map<String, dynamic> raw) {
    if (!_isAxiomaItem(raw)) return raw;
    final room = (raw['reatroom']?.toString().trim().isNotEmpty == true
            ? raw['reatroom']
            : raw['axiroom']?.toString().trim().isNotEmpty == true
                ? raw['axiroom']
                : raw['location'])
        ?.toString()
        .trim() ?? '';
    return {
      'item_id': raw['assetnum']?.toString().trim() ??
          raw['x_inventarnum']?.toString().trim() ?? '',
      'name': raw['description']?.toString().trim() ?? '',
      'category': raw['classstructureid']?.toString().trim() ?? '',
      'location': room,
      'quantity': raw['orderqty'] ?? raw['quantity'] ?? 0,
      'created_at': raw['installdate']?.toString() ??
          raw['commdate']?.toString() ?? '',
      'updated_at': raw['changedate']?.toString() ?? '',
      'responsible_person': raw['responsible']?.toString().trim() ?? '',
    };
  }

  String _uniqueId(String proposed, Set<String> used) {
    if (proposed.isNotEmpty && !used.contains(proposed)) return proposed;
    var n = 1;
    while (true) {
      final c = 'ITEM-${n.toString().padLeft(3, '0')}';
      if (!used.contains(c)) return c;
      n++;
    }
  }

  Item _makeItem(
    Map<String, dynamic> raw, {
    required String itemId,
    required int intId,
    Item? base,
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

  ItemCategory? _catByName(String? name) {
    if (name == null || name.isEmpty) return null;
    try {
      return kCategories.firstWhere((c) => c.key == name);
    } catch (_) {}
    try {
      return kCategories.firstWhere(
          (c) => name.toLowerCase().contains(c.name.toLowerCase()));
    } catch (_) {
      return null;
    }
  }
}

// ── Подзаголовок секции ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── Тайл опции обмена ──────────────────────────────────────────────────────

class _ExchangeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExchangeTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
