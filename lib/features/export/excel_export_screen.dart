import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';

const _kRed = Color(0xFFA80000);
const _kNoRoom = '⚠️ Без помещения';

class ExcelExportScreen extends StatefulWidget {
  const ExcelExportScreen({super.key});

  @override
  State<ExcelExportScreen> createState() => _ExcelExportScreenState();
}

class _ExcelExportScreenState extends State<ExcelExportScreen> {
  // Выбранные помещения (ключ — название помещения или _kNoRoom)
  final Set<String> _selected = {};

  // Все предметы из Hive
  late final List<Item> _allItems;

  // Сгруппированные: помещение → список предметов
  late final Map<String, List<Item>> _byRoom;

  // Список помещений для отображения (включая «Без помещения»)
  late final List<String> _rooms;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _allItems = Hive.box<Item>('items').values.toList();
    _buildGroups();
    // По умолчанию выбираем все помещения
    _selected.addAll(_rooms);
  }

  // ── Группировка предметов по помещениям ──────────────────────────────────

  void _buildGroups() {
    final map = <String, List<Item>>{};
    for (final item in _allItems) {
      final room = item.location.room.trim().isEmpty
          ? _kNoRoom
          : item.location.room.trim();
      map.putIfAbsent(room, () => []).add(item);
    }

    // Сначала обычные помещения (по алфавиту), потом «Без помещения»
    final sorted = map.keys
        .where((r) => r != _kNoRoom)
        .toList()
      ..sort();
    if (map.containsKey(_kNoRoom)) sorted.add(_kNoRoom);

    _rooms = sorted;
    _byRoom = map;
  }

  // ── Количество предметов в выбранных помещениях ───────────────────────────

  int get _selectedItemCount => _selected.fold(
        0,
        (sum, room) => sum + (_byRoom[room]?.length ?? 0),
      );

  // ── Переключение чекбоксов ────────────────────────────────────────────────

  void _toggleAll() {
    setState(() {
      if (_selected.length == _rooms.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_rooms);
      }
    });
  }

  void _toggleRoom(String room) {
    setState(() {
      if (_selected.contains(room)) {
        _selected.remove(room);
      } else {
        _selected.add(room);
      }
    });
  }

  // ── Экспорт в Excel ───────────────────────────────────────────────────────

  Future<void> _export() async {
    if (_selected.isEmpty) return;
    setState(() => _isExporting = true);

    try {
      // Путь для сохранения файла
      final filePath = await _resolveSavePath();
      if (filePath == null) {
        // Разрешение не выдано — уже показали диалог
        setState(() => _isExporting = false);
        return;
      }

      // Генерация xlsx
      final bytes = _buildExcel();
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _isExporting = false);

      if (Platform.isIOS) {
        // На iOS файлы в директории приложения недоступны пользователю напрямую —
        // сразу открываем Share для передачи или сохранения файла
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'Инвентаризация — выгрузка Excel',
        );
      } else {
        // Показываем шторку с результатом
        _showSuccessSheet(filePath);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при создании файла: $e')),
      );
    }
  }

  // ── Определение пути для сохранения файла ────────────────────────────────

  Future<String?> _resolveSavePath() async {
    final now = DateTime.now();
    final stamp = DateFormat('dd.MM.yyyy_HH-mm').format(now);
    final fileName = 'Инвентаризация_$stamp.xlsx';

    if (Platform.isAndroid) {
      return await _androidPath(fileName);
    } else {
      // iOS — директория документов приложения
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/$fileName';
    }
  }

  Future<String?> _androidPath(String fileName) async {
    // Android 11+ требует MANAGE_EXTERNAL_STORAGE для записи в Downloads
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      return '/storage/emulated/0/Download/$fileName';
    }

    // Пробуем запросить разрешение
    final result = await Permission.manageExternalStorage.request();
    if (result.isGranted) {
      return '/storage/emulated/0/Download/$fileName';
    }

    if (!mounted) return null;

    // Разрешение не выдано — предлагаем открыть настройки или сохранить
    // во временную директорию и поделиться
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нет доступа к файлам'),
        content: const Text(
          'Для сохранения файла в папку Downloads необходимо '
          'разрешить доступ к файлам в настройках телефона.\n\n'
          'Или продолжите — файл будет сохранён во временную '
          'папку и доступен через «Поделиться».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, false);
              openAppSettings();
            },
            child: const Text(
              'Открыть настройки',
              style: TextStyle(color: _kRed),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );

    if (choice != true) return null;

    // Временная директория (share_plus откроет диалог сохранения)
    final tmp = await getTemporaryDirectory();
    return '${tmp.path}/$fileName';
  }

  // ── Построение Excel файла ────────────────────────────────────────────────

  List<int> _buildExcel() {
    final excel = xl.Excel.createExcel();
    // Переименовываем стандартный лист
    excel.rename('Sheet1', 'Инвентаризация');
    final sheet = excel['Инвентаризация'];

    // Стиль заголовка: жирный шрифт
    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#FFDDDDDD'),
    );

    // Заголовки столбцов
    final headers = [
      '№',
      'Артикул',
      'Наименование',
      'Категория',
      'Помещение',
      'Количество',
      'QR-данные',
      'Дата добавления',
      'Дата изменения',
    ];

    for (int c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = headerStyle;
    }

    // Формат дат
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    // Собираем предметы из выбранных помещений, сортируем
    final items = <Item>[];
    // Помещения — по алфавиту, _kNoRoom последним
    final orderedRooms = _rooms.where(_selected.contains).toList();
    for (final room in orderedRooms) {
      final roomItems = List<Item>.from(_byRoom[room] ?? [])
        ..sort((a, b) => a.name.compareTo(b.name));
      items.addAll(roomItems);
    }

    int rowIndex = 1;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final cat = categoryByKey(item.category);
      final room = item.location.room.trim().isEmpty
          ? 'Без помещения'
          : item.location.room.trim();

      final values = [
        xl.IntCellValue(i + 1),
        xl.TextCellValue(item.itemId ?? '—'),
        xl.TextCellValue(item.name),
        xl.TextCellValue(cat != null ? '${cat.emoji} ${cat.name}' : '—'),
        xl.TextCellValue(room),
        xl.IntCellValue(item.quantity ?? 0),
        xl.TextCellValue(item.itemId ?? '—'),
        xl.TextCellValue(
            item.createdAt != null ? dateFmt.format(item.createdAt!) : '—'),
        xl.TextCellValue(
            item.updatedAt != null ? dateFmt.format(item.updatedAt!) : '—'),
      ];

      for (int c = 0; c < values.length; c++) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: rowIndex))
            .value = values[c];
      }
      rowIndex++;
    }

    // Итоговая строка
    final totalCell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    totalCell.value = xl.TextCellValue('Итого: ${items.length} предметов');
    totalCell.cellStyle = xl.CellStyle(bold: true);

    // Ширина столбцов (в символах)
    final colWidths = [6, 12, 32, 18, 22, 10, 24, 20, 20];
    for (int c = 0; c < colWidths.length; c++) {
      sheet.setColumnWidth(c, colWidths[c].toDouble());
    }

    return excel.encode()!;
  }

  // ── BottomSheet после успешного сохранения ────────────────────────────────

  void _showSuccessSheet(String filePath) {
    final fileName = filePath.split('/').last;
    final isDownloads = filePath.contains('/Download/');
    final folderLabel = isDownloads ? 'Downloads' : 'Документы приложения';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ручка шторки
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Иконка успеха
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline,
                    size: 32, color: Colors.green),
              ),

              const SizedBox(height: 12),

              const Text(
                '✅ Файл сохранён',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 16),

              // Имя файла
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Папка: $folderLabel',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Кнопка «Открыть файл»
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => OpenFilex.open(filePath),
                  icon: const Icon(Icons.open_in_new_outlined,
                      size: 18, color: _kRed),
                  label: const Text('Открыть файл',
                      style: TextStyle(color: _kRed)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _kRed),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Кнопка «Поделиться файлом»
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Share.shareXFiles(
                      [XFile(filePath)],
                      subject: 'Инвентаризация — выгрузка Excel',
                    );
                  },
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('📤 Поделиться файлом'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Кнопка «Закрыть»
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allSelected = _selected.length == _rooms.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/back_button.svg',
              width: 85,
              height: 43,
            ),
          ),
        ),
        title: const Text(
          '📊 Выгрузка в Excel',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: _allItems.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                Expanded(child: _buildRoomList(allSelected)),
                _buildFooter(),
              ],
            ),
    );
  }

  // ── Пустое состояние ─────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Нет предметов для выгрузки',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Список помещений с чекбоксами ────────────────────────────────────────

  Widget _buildRoomList(bool allSelected) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        // Секция «Выберите помещения»
        const Text(
          'Выберите помещения',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),

        // Кнопка «Выбрать все» / «Снять все»
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggleAll,
            icon: Icon(
              allSelected
                  ? Icons.deselect_outlined
                  : Icons.select_all_outlined,
              size: 18,
              color: _kRed,
            ),
            label: Text(
              allSelected ? 'Снять все' : 'Выбрать все',
              style: const TextStyle(color: _kRed, fontSize: 14),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Карточка со списком помещений
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _rooms.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 1, color: Colors.grey.shade100, indent: 16),
                _RoomCheckRow(
                  room: _rooms[i],
                  count: _byRoom[_rooms[i]]?.length ?? 0,
                  selected: _selected.contains(_rooms[i]),
                  onToggle: () => _toggleRoom(_rooms[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Нижняя панель с итогом и кнопкой ────────────────────────────────────

  Widget _buildFooter() {
    final count = _selectedItemCount;
    final roomCount = _selected.length;
    final canExport = _selected.isNotEmpty && !_isExporting;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Итог
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Будет выгружено: $count '
                    '${_pluralItems(count)} '
                    'из $roomCount '
                    '${_pluralRooms(roomCount)}',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          // Кнопка «Выгрузить Excel»
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canExport ? _export : null,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
              label: Text(
                _isExporting ? 'Создание файла...' : '📥 Выгрузить Excel',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Склонение слов ────────────────────────────────────────────────────────

  String _pluralItems(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return 'предметов';
    switch (n % 10) {
      case 1:
        return 'предмет';
      case 2:
      case 3:
      case 4:
        return 'предмета';
      default:
        return 'предметов';
    }
  }

  String _pluralRooms(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return 'помещений';
    switch (n % 10) {
      case 1:
        return 'помещения';
      case 2:
      case 3:
      case 4:
        return 'помещения';
      default:
        return 'помещений';
    }
  }
}

// ── Строка помещения с чекбоксом ─────────────────────────────────────────

class _RoomCheckRow extends StatelessWidget {
  final String room;
  final int count;
  final bool selected;
  final VoidCallback onToggle;

  const _RoomCheckRow({
    required this.room,
    required this.count,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Чекбокс
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? _kRed : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: selected ? _kRed : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),

            const SizedBox(width: 14),

            // Название помещения
            Expanded(
              child: Text(
                room,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? Colors.black87 : Colors.black54,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),

            // Количество предметов
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? _kRed.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count пр.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? _kRed : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
