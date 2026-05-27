import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../inventory/category_selection_screen.dart';
import '../inventory/create_item_screen.dart';
import '../inventory/item_card_screen.dart';
import '../inventory/multi_qr_screen.dart';
import '../inventory/qr_code_screen.dart';

const _kBorderColor = Color(0xFFA80000);
const _kHeaderColor = Color(0xFFA80000);
const _kAltRowColor = Color(0xFFF9F0F0);
// Цвета для режима объединения
const _kMergeHighlight = Color(0xFFE8F5E9);
const _kMergeSelected  = Color(0xFFC8E6C9);

class InventoryScreen extends StatefulWidget {
  final List<Item> items;
  final void Function(Item item) onItemAdded;
  final String searchQuery;

  const InventoryScreen({
    super.key,
    required this.items,
    required this.onItemAdded,
    this.searchQuery = '',
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // ── Состояние фильтра ─────────────────────────────────────────────────────
  /// Выбранные ключи категорий (пусто = все категории)
  Set<String> _selectedCategories = {};
  /// Выбранные названия помещений (пусто = все помещения)
  Set<String> _selectedRooms = {};
  /// Диапазон дат по createdAt (null = без ограничения)
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // ── Состояние сортировки ──────────────────────────────────────────────────
  /// Активный параметр сортировки (null = без сортировки)
  _SortField? _sortField;
  /// Направление сортировки: true = по возрастанию / А→Я
  bool _sortAscending = true;

  /// Активна ли сортировка
  bool get _isSortActive => _sortField != null;

  // ── Состояние режима мультивыбора ─────────────────────────────────────────
  bool _isSelectMode = false;
  /// Hive-ключи выбранных предметов
  final Set<dynamic> _selectedKeys = {};
  /// Группы объединяемых предметов: ключ = "наименование|комната"
  Map<String, List<Item>> _mergeableGroups = {};
  /// Hive-ключи всех предметов в объединяемых группах
  Set<dynamic> _mergeableKeys = {};
  /// Ключ группы, разрешённой для добавления в текущий выбор
  String? _currentGroupKey;

  // ── Логика фильтрации ─────────────────────────────────────────────────────

  /// Активен ли хоть один фильтр
  bool get _isFilterActive =>
      _selectedCategories.isNotEmpty ||
      _selectedRooms.isNotEmpty ||
      _dateFrom != null ||
      _dateTo != null;

  /// Итоговый список: фильтр → сортировка → поиск
  List<Item> get _filteredItems {
    // ШАГ 1: фильтрация по категории, помещению и диапазону дат
    var result = widget.items.where((item) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(item.category ?? '')) {
        return false;
      }
      if (_selectedRooms.isNotEmpty &&
          !_selectedRooms.contains(item.location.room)) {
        return false;
      }
      if (_dateFrom != null) {
        final created = item.createdAt;
        if (created == null || created.isBefore(_dateFrom!)) return false;
      }
      if (_dateTo != null) {
        final created = item.createdAt;
        // Включаем весь последний день
        final endOfDay = DateTime(
            _dateTo!.year, _dateTo!.month, _dateTo!.day, 23, 59, 59);
        if (created == null || created.isAfter(endOfDay)) return false;
      }
      return true;
    }).toList();

    // ШАГ 2: сортировка отфильтрованного списка
    if (_sortField != null) {
      result.sort((a, b) {
        int cmp;
        switch (_sortField!) {
          case _SortField.number:
            // Сортировка по порядковому номеру (позиция в Hive)
            cmp = (a.id).compareTo(b.id);
          case _SortField.name:
            cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case _SortField.room:
            cmp = a.location.room.toLowerCase()
                .compareTo(b.location.room.toLowerCase());
          case _SortField.quantity:
            cmp = (a.quantity ?? 0).compareTo(b.quantity ?? 0);
          case _SortField.category:
            final catA = categoryByKey(a.category)?.name ?? '';
            final catB = categoryByKey(b.category)?.name ?? '';
            cmp = catA.toLowerCase().compareTo(catB.toLowerCase());
          case _SortField.createdAt:
            final dtA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            cmp = dtA.compareTo(dtB);
          case _SortField.updatedAt:
            final dtA = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dtB = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            cmp = dtA.compareTo(dtB);
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // ШАГ 3: поиск по тексту (передаётся из home_screen)
    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery;
      result = result.where((item) {
        return item.name.toLowerCase().contains(q) ||
            (item.inventoryNumber?.toLowerCase().contains(q) ?? false) ||
            item.location.room.toLowerCase().contains(q);
      }).toList();
    }

    return result;
  }

  /// Сбросить все фильтры
  void _clearFilter() {
    setState(() {
      _selectedCategories = {};
      _selectedRooms = {};
      _dateFrom = null;
      _dateTo = null;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _groupKey(Item item) =>
      '${item.name.trim().toLowerCase()}|'
      '${item.location.room.trim().toLowerCase()}';

  String _nextItemId(Box<Item> box) =>
      'ITEM-${(box.length + 1).toString().padLeft(3, '0')}';

  /// Стабильный номер предмета: позиция в Hive-боксе (порядок добавления).
  /// Не меняется при фильтрации, поиске или сортировке.
  Map<dynamic, int> _buildItemNumberMap() {
    final allItems = Hive.box<Item>('items').values.toList();
    return {
      for (var i = 0; i < allItems.length; i++) allItems[i].key: i + 1,
    };
  }

  // ── Открыть BottomSheet сортировки ───────────────────────────────────────

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SortSheet(
        initialField: _sortField,
        initialAscending: _sortAscending,
        onApply: (field, ascending) {
          setState(() {
            _sortField = field;
            _sortAscending = ascending;
          });
        },
      ),
    );
  }

  // ── Открыть BottomSheet фильтра ───────────────────────────────────────────

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        allItems: widget.items,
        initialCategories: Set.from(_selectedCategories),
        initialRooms: Set.from(_selectedRooms),
        initialDateFrom: _dateFrom,
        initialDateTo: _dateTo,
        onApply: (cats, rooms, dateFrom, dateTo) {
          setState(() {
            _selectedCategories = cats;
            _selectedRooms = rooms;
            _dateFrom = dateFrom;
            _dateTo = dateTo;
          });
        },
      ),
    );
  }

  // ── Создание предмета ─────────────────────────────────────────────────────

  void _openCreateFlow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CategorySelectionSheet(
        onCategorySelected: (category) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreateItemScreen(
                category: category,
                onCreated: (items, mergeWarning) =>
                    _afterCreated(items, category, mergeWarning: mergeWarning),
              ),
            ),
          );
        },
      ),
    );
  }

  void _afterCreated(List<Item> items, ItemCategory category,
      {String? mergeWarning}) {
    if (items.isEmpty) return;
    if (category.perUnit && items.length > 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MultiQrScreen(items: items)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            item: items.first,
            mergeWarning: mergeWarning,
          ),
        ),
      );
    }
  }

  // ── Режим мультивыбора ────────────────────────────────────────────────────

  void _computeMergeableGroups() {
    final groups = <String, List<Item>>{};
    for (final item in widget.items) {
      groups.putIfAbsent(_groupKey(item), () => []).add(item);
    }
    _mergeableGroups =
        Map.fromEntries(groups.entries.where((e) => e.value.length >= 2));
    _mergeableKeys = {
      for (final list in _mergeableGroups.values)
        for (final item in list) item.key,
    };
  }

  void _enterSelectMode(Item item) {
    _computeMergeableGroups();
    setState(() {
      _isSelectMode = true;
      _selectedKeys.clear();
      _currentGroupKey = null;
    });
    _toggleSelection(item);
  }

  void _exitSelectMode() {
    setState(() {
      _isSelectMode = false;
      _selectedKeys.clear();
      _currentGroupKey = null;
      _mergeableGroups = {};
      _mergeableKeys = {};
    });
  }

  void _toggleSelection(Item item) {
    final hiveKey = item.key;
    final groupKey = _groupKey(item);

    if (_selectedKeys.contains(hiveKey)) {
      setState(() {
        _selectedKeys.remove(hiveKey);
        if (_selectedKeys.isEmpty) _currentGroupKey = null;
      });
      return;
    }

    if (_currentGroupKey != null && _currentGroupKey != groupKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '❌ Нельзя объединить предметы с разным наименованием или положением'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _selectedKeys.add(hiveKey);
      _currentGroupKey = groupKey;
    });
  }

  Future<void> _confirmMerge() async {
    if (_selectedKeys.length < 2) return;

    final box = Hive.box<Item>('items');
    final selectedItems = widget.items
        .where((item) => _selectedKeys.contains(item.key))
        .toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _MergeConfirmDialog(items: selectedItems),
    );
    if (confirmed != true || !mounted) return;

    final first = selectedItems.first;
    final totalQty =
        selectedItems.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
    final newItemId = _nextItemId(box);

    final mergedItem = Item(
      id: DateTime.now().millisecondsSinceEpoch,
      name: first.name,
      description: first.description,
      location: first.location,
      quantity: totalQty,
      itemId: newItemId,
      category: first.category,
      imagePath: first.imagePath,
      inventoryNumber: first.inventoryNumber,
      responsiblePerson: first.responsiblePerson,
      createdAt: first.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    box.add(mergedItem);
    for (final item in selectedItems) {
      item.delete();
    }

    _exitSelectMode();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QrCodeScreen(
            item: mergedItem,
            mergeWarning:
                '⚠️ Старые QR-коды недействительны!\nЗамените наклейки на предметах',
          ),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final itemNumbers = _buildItemNumberMap();

    // База пустая — показываем полноэкранный empty state
    if (widget.items.isEmpty) {
      return Column(
        children: [
          Expanded(child: _buildEmptyState(context)),
          _buildBottomNav(),
        ],
      );
    }

    return Column(
      children: [
        // Подсказка в режиме мультивыбора
        if (_isSelectMode)
          Container(
            width: double.infinity,
            color: const Color(0xFFE8F5E9),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '✅ Зелёным выделены позиции, которые можно объединить',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
          ),

        // Строка с кнопкой фильтра (скрыта в режиме выбора)
        if (!_isSelectMode) _buildFilterRow(),

        // Баннер активного фильтра
        if (!_isSelectMode && _isFilterActive) _buildActiveFilterBanner(),

        // Таблица
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              children: [
                _buildHeaderRow(),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              left:
                                  BorderSide(color: _kBorderColor, width: 1.5),
                              right:
                                  BorderSide(color: _kBorderColor, width: 1.5),
                              bottom:
                                  BorderSide(color: _kBorderColor, width: 1.5),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.searchQuery.isNotEmpty || _isFilterActive
                                ? 'Ничего не найдено'
                                : 'Нет записей',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final location = item.location.floor.isNotEmpty
                                ? '${item.location.floor} / ${item.location.room}'
                                : item.location.room;
                            final category = categoryByKey(item.category);
                            final isSelected =
                                _selectedKeys.contains(item.key);
                            final isHighlighted =
                                _mergeableKeys.contains(item.key);
                            final isLast = index == filteredItems.length - 1;

                            return GestureDetector(
                              onTap: () {
                                if (_isSelectMode) {
                                  _toggleSelection(item);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ItemCardScreen(item: item),
                                    ),
                                  );
                                }
                              },
                              onLongPress: _isSelectMode
                                  ? null
                                  : () => _enterSelectMode(item),
                              child: _buildDataRow(
                                index: index,
                                itemNumber:
                                    itemNumbers[item.key] ?? (index + 1),
                                item: item,
                                name: item.name,
                                location: location,
                                quantity: item.quantity?.toString() ?? '—',
                                categoryEmoji: category?.emoji,
                                isLast: isLast,
                                isSelectMode: _isSelectMode,
                                isSelected: isSelected,
                                isHighlighted: isHighlighted,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Панель объединения или нижняя навигация
        if (_isSelectMode) _buildMergePanel() else _buildBottomNav(),
      ],
    );
  }

  // ── Пустая база ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          // Иконка
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kBorderColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: _kBorderColor,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Список пуст',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Добавьте первый предмет,\nчтобы начать работу',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),

          const SizedBox(height: 36),

          // Подсказки
          const _HintCard(
            icon: Icons.add_circle_outline_rounded,
            iconColor: _kBorderColor,
            title: 'Добавить предмет вручную',
            subtitle: 'Нажмите кнопку «+» в нижней панели',
          ),
          const SizedBox(height: 12),
          const _HintCard(
            icon: Icons.qr_code_scanner_rounded,
            iconColor: Color(0xFF1565C0),
            title: 'Отсканировать QR-код',
            subtitle: 'Наведите камеру на наклейку предмета',
          ),
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.upload_file_outlined,
            iconColor: const Color(0xFF2E7D32),
            title: 'Импортировать данные',
            subtitle: 'Загрузите Excel или JSON из Аксиомы\nили другой системы',
            onTap: () => Navigator.pushNamed(context, '/data_exchange'),
          ),
          const SizedBox(height: 12),
          _HintCard(
            icon: Icons.wifi_rounded,
            iconColor: const Color(0xFF6A1B9A),
            title: 'Передача по Wi-Fi',
            subtitle: 'Получите данные с компьютера\nчерез браузер',
            onTap: () => Navigator.pushNamed(context, '/data_exchange'),
          ),
        ],
      ),
    );
  }

  // ── Строка с кнопками сортировки и фильтра ───────────────────────────────

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        children: [
          const Spacer(),
          // Кнопка сортировки с бейджем при активной сортировке
          Badge(
            isLabelVisible: _isSortActive,
            backgroundColor: _kBorderColor,
            smallSize: 8,
            child: GestureDetector(
              onTap: _openSortSheet,
              child: SvgPicture.asset(
                'assets/icons/home_p/1sort.svg',
                width: 40,
                height: 40,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Кнопка фильтра с бейджем при активном фильтре
          Badge(
            isLabelVisible: _isFilterActive,
            backgroundColor: _kBorderColor,
            smallSize: 8,
            child: GestureDetector(
              onTap: _openFilterSheet,
              child: SvgPicture.asset(
                'assets/icons/home_p/filter.svg',
                width: 40,
                height: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Баннер активного фильтра ──────────────────────────────────────────────

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';

  Widget _buildActiveFilterBanner() {
    // Собираем метки: имена категорий, помещения и диапазон дат через •
    final parts = <String>[
      for (final key in _selectedCategories)
        if (categoryByKey(key) case final cat?)
          '${cat.emoji} ${cat.name}',
      ..._selectedRooms,
      if (_dateFrom != null && _dateTo != null)
        '${_fmtDate(_dateFrom!)} – ${_fmtDate(_dateTo!)}'
      else if (_dateFrom != null)
        'с ${_fmtDate(_dateFrom!)}'
      else if (_dateTo != null)
        'по ${_fmtDate(_dateTo!)}',
    ];

    return Container(
      width: double.infinity,
      color: _kBorderColor.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Фильтр: ${parts.join(' • ')}',
              style: const TextStyle(fontSize: 12, color: _kBorderColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _clearFilter,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 8),
                Icon(Icons.close, size: 14, color: _kBorderColor),
                SizedBox(width: 2),
                Text(
                  'Сбросить',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kBorderColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Нижняя навигация ──────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF8B0000),
          borderRadius: BorderRadius.circular(40),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Кнопка «Добавить QR-объект» — иконка с встроенной подписью
            Expanded(
              child: GestureDetector(
                onTap: _openCreateFlow,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/home_p/3add.svg',
                    width: 63,
                    height: 49,
                  ),
                ),
              ),
            ),
            // Кнопка «Отсканировать QR-объект» — иконка с встроенной подписью
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/qr_scanner',
                  arguments: widget.items,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/home_p/scan.svg',
                    width: 74,
                    height: 46,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Панель объединения ────────────────────────────────────────────────────

  Widget _buildMergePanel() {
    final canMerge = _selectedKeys.length >= 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canMerge ? _confirmMerge : null,
              icon: const Icon(Icons.link, size: 18),
              label: Text('Объединить выбранные (${_selectedKeys.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    const Color(0xFF2E7D32).withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _exitSelectMode,
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              side: const BorderSide(color: Colors.grey),
            ),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── Заголовок таблицы ─────────────────────────────────────────────────────

  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: _kHeaderColor,
        border: Border.all(color: _kBorderColor, width: 1.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(6),
          topRight: Radius.circular(6),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (_isSelectMode)
              _headerCell('☑', flex: 1, center: true)
            else
              _headerCell('№', flex: 1,
                  center: true, sortField: _SortField.number),
            _vDivider(),
            _headerCell('Наим.', flex: 5, sortField: _SortField.name),
            _vDivider(),
            _headerCell('Положение', flex: 3, sortField: _SortField.room),
            _vDivider(),
            _headerCell('Кол.', flex: 1,
                center: true, sortField: _SortField.quantity),
          ],
        ),
      ),
    );
  }

  /// Ячейка заголовка: если это активная колонка сортировки — подсвечивается
  Widget _headerCell(String text,
      {required int flex, bool center = false, _SortField? sortField}) {
    final isActive = sortField != null && _sortField == sortField;
    // Иконка стрелки показывает направление сортировки
    final arrow = isActive ? (_sortAscending ? ' ↑' : ' ↓') : '';
    return Expanded(
      flex: flex,
      child: Container(
        // Слегка более светлый фон для активной колонки
        color: isActive
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Text(
          '$text$arrow',
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _vDivider() =>
      Container(width: 1, color: Colors.white.withValues(alpha: 0.5));

  // ── Строка данных таблицы ─────────────────────────────────────────────────

  Widget _buildDataRow({
    required int index,
    required int itemNumber,
    required Item item,
    required String name,
    required String location,
    required String quantity,
    required String? categoryEmoji,
    required bool isLast,
    required bool isSelectMode,
    required bool isSelected,
    required bool isHighlighted,
  }) {
    Color rowColor;
    if (isSelected) {
      rowColor = _kMergeSelected;
    } else if (isHighlighted) {
      rowColor = _kMergeHighlight;
    } else {
      rowColor = index.isEven ? Colors.white : _kAltRowColor;
    }

    final displayName =
        categoryEmoji != null ? '$categoryEmoji  $name' : name;

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          left: const BorderSide(color: _kBorderColor, width: 1.5),
          right: const BorderSide(color: _kBorderColor, width: 1.5),
          bottom: BorderSide(
            color: _kBorderColor,
            width: isLast ? 1.5 : 0.8,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (isSelectMode)
              Expanded(
                flex: 1,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(item),
                      activeColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Colors.grey),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              )
            else
              _dataCell('$itemNumber', flex: 1, center: true),
            _rowDivider(),
            _dataCell(displayName, flex: 5),
            _rowDivider(),
            _dataCell(location, flex: 3),
            _rowDivider(),
            _dataCell(quantity, flex: 1, center: true),
          ],
        ),
      ),
    );
  }

  Widget _dataCell(String text, {required int flex, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ),
    );
  }

  Widget _rowDivider() =>
      Container(width: 1, color: _kBorderColor.withValues(alpha: 0.3));
}

// ── Параметры сортировки ───────────────────────────────────────────────────

enum _SortField {
  number,
  name,
  room,
  quantity,
  category,
  createdAt,
  updatedAt,
}

extension _SortFieldX on _SortField {
  /// Отображаемое название
  String get label => switch (this) {
        _SortField.number    => 'По номеру №',
        _SortField.name      => 'По наименованию',
        _SortField.room      => 'По помещению',
        _SortField.quantity  => 'По количеству',
        _SortField.category  => 'По категории',
        _SortField.createdAt => 'По дате создания',
        _SortField.updatedAt => 'По дате изменения',
      };

  /// Подпись для направления «по возрастанию»
  String get ascLabel => switch (this) {
        _SortField.number    => '1 → 100',
        _SortField.quantity  => '1 → 100',
        _SortField.name      => 'А → Я',
        _SortField.room      => 'А → Я',
        _SortField.category  => 'А → Я',
        _SortField.createdAt => 'Старые',
        _SortField.updatedAt => 'Старые',
      };

  /// Подпись для направления «по убыванию»
  String get descLabel => switch (this) {
        _SortField.number    => '100 → 1',
        _SortField.quantity  => '100 → 1',
        _SortField.name      => 'Я → А',
        _SortField.room      => 'Я → А',
        _SortField.category  => 'Я → А',
        _SortField.createdAt => 'Новые',
        _SortField.updatedAt => 'Новые',
      };
}

// ── Карточка подсказки на пустом экране ───────────────────────────────────

class _HintCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HintCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
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
                        fontSize: 14,
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
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BottomSheet сортировки ─────────────────────────────────────────────────

class _SortSheet extends StatefulWidget {
  final _SortField? initialField;
  final bool initialAscending;
  final void Function(_SortField? field, bool ascending) onApply;

  const _SortSheet({
    required this.initialField,
    required this.initialAscending,
    required this.onApply,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  _SortField? _field;
  bool _ascending = true;

  @override
  void initState() {
    super.initState();
    _field = widget.initialField;
    _ascending = widget.initialAscending;
  }

  void _apply() {
    widget.onApply(_field, _ascending);
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _field = null;
      _ascending = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Заголовок ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Сортировка',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Список параметров ─────────────────────────────────────────
            for (final field in _SortField.values) ...[
              _SortOption(
                field: field,
                selectedField: _field,
                ascending: _ascending,
                onSelect: (f, asc) => setState(() {
                  _field = f;
                  _ascending = asc;
                }),
              ),
              if (field != _SortField.values.last)
                const Divider(height: 1, indent: 8, endIndent: 8),
            ],

            const SizedBox(height: 16),

            // ── Кнопки «Сбросить» / «Применить» ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: _kBorderColor),
                    ),
                    child: const Text(
                      'Сбросить',
                      style: TextStyle(color: _kBorderColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBorderColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Строка параметра сортировки ────────────────────────────────────────────

class _SortOption extends StatelessWidget {
  final _SortField field;
  final _SortField? selectedField;
  final bool ascending;
  final void Function(_SortField field, bool ascending) onSelect;

  const _SortOption({
    required this.field,
    required this.selectedField,
    required this.ascending,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedField == field;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Название параметра
          Expanded(
            child: Text(
              field.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? _kBorderColor : Colors.black87,
              ),
            ),
          ),
          // Кнопка «по возрастанию»
          _DirectionButton(
            label: field.ascLabel,
            icon: Icons.arrow_upward,
            selected: isSelected && ascending,
            onTap: () => onSelect(field, true),
          ),
          const SizedBox(width: 6),
          // Кнопка «по убыванию»
          _DirectionButton(
            label: field.descLabel,
            icon: Icons.arrow_downward,
            selected: isSelected && !ascending,
            onTap: () => onSelect(field, false),
          ),
        ],
      ),
    );
  }
}

// ── Кнопка направления сортировки ─────────────────────────────────────────

class _DirectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kBorderColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kBorderColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: selected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.black87,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BottomSheet фильтра ────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final List<Item> allItems;
  final Set<String> initialCategories;
  final Set<String> initialRooms;
  final DateTime? initialDateFrom;
  final DateTime? initialDateTo;
  final void Function(
      Set<String> cats, Set<String> rooms,
      DateTime? dateFrom, DateTime? dateTo) onApply;

  const _FilterSheet({
    required this.allItems,
    required this.initialCategories,
    required this.initialRooms,
    required this.onApply,
    this.initialDateFrom,
    this.initialDateTo,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<String> _cats;
  late Set<String> _rooms;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// Все уникальные помещения из Hive, отсортированные по алфавиту
  late List<String> _allRooms;

  @override
  void initState() {
    super.initState();
    _cats = Set.from(widget.initialCategories);
    _rooms = Set.from(widget.initialRooms);
    _dateFrom = widget.initialDateFrom;
    _dateTo = widget.initialDateTo;
    _allRooms = widget.allItems
        .map((e) => e.location.room)
        .toSet()
        .toList()
      ..sort();
  }

  // ── Динамические счётчики ─────────────────────────────────────────────────

  /// Количество предметов в категории с учётом выбранных помещений
  int _countForCategory(String catKey) {
    return widget.allItems.where((item) {
      if (item.category != catKey) return false;
      if (_rooms.isNotEmpty && !_rooms.contains(item.location.room)) {
        return false;
      }
      return true;
    }).length;
  }

  /// Количество предметов в помещении с учётом выбранных категорий
  int _countForRoom(String room) {
    return widget.allItems.where((item) {
      if (item.location.room != room) return false;
      if (_cats.isNotEmpty && !_cats.contains(item.category ?? '')) {
        return false;
      }
      return true;
    }).length;
  }

  /// Общее количество предметов с учётом выбранных помещений (для чипа "Все")
  int get _totalCount {
    if (_rooms.isEmpty) return widget.allItems.length;
    return widget.allItems
        .where((item) => _rooms.contains(item.location.room))
        .length;
  }

  // ── Логика выбора категорий ───────────────────────────────────────────────

  void _toggleAllCategories() {
    setState(() => _cats.clear());
  }

  void _toggleCategory(String key) {
    setState(() {
      if (_cats.contains(key)) {
        _cats.remove(key);
      } else {
        _cats.add(key);
      }
    });
  }

  void _toggleRoom(String room) {
    setState(() {
      if (_rooms.contains(room)) {
        _rooms.remove(room);
      } else {
        _rooms.add(room);
      }
    });
  }

  void _reset() {
    setState(() {
      _cats.clear();
      _rooms.clear();
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _apply() {
    widget.onApply(Set.from(_cats), Set.from(_rooms), _dateFrom, _dateTo);
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          // Учитываем высоту клавиатуры
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Заголовок ─────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Фильтр',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Секция «По категории» ─────────────────────────────────────
            const Text(
              'По категории',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Чип «Все»
                _FilterChip(
                  label: 'Все ($_totalCount)',
                  selected: _cats.isEmpty,
                  onTap: _toggleAllCategories,
                ),
                // Чипы категорий
                for (final cat in kCategories)
                  _FilterChip(
                    label: '${cat.emoji} ${cat.name} (${_countForCategory(cat.key)})',
                    selected: _cats.contains(cat.key),
                    onTap: () => _toggleCategory(cat.key),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Секция «По помещению» ─────────────────────────────────────
            const Text(
              'По помещению',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            _allRooms.isEmpty
                ? const Text(
                    'Нет данных',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final room in _allRooms)
                        _FilterChip(
                          label: '$room (${_countForRoom(room)})',
                          selected: _rooms.contains(room),
                          onTap: () => _toggleRoom(room),
                        ),
                    ],
                  ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Секция «По дате создания» ─────────────────────────────────
            const Text(
              'По дате создания',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DatePickerField(
                    label: 'С',
                    value: _dateFrom,
                    lastDate: _dateTo,
                    onPicked: (d) => setState(() => _dateFrom = d),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'По',
                    value: _dateTo,
                    firstDate: _dateFrom,
                    onPicked: (d) => setState(() => _dateTo = d),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Кнопки «Сбросить» / «Применить» ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      side: const BorderSide(color: _kBorderColor),
                    ),
                    child: const Text(
                      'Сбросить',
                      style: TextStyle(color: _kBorderColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBorderColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text('Применить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Чип фильтра ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kBorderColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kBorderColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Галочка у выбранных чипов
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.white : Colors.black87,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Поле выбора даты ───────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.onPicked,
    this.value,
    this.firstDate,
    this.lastDate,
  });

  String _format(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2020),
          lastDate: lastDate ?? DateTime(2100),
          locale: const Locale('ru'),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: value != null ? _kBorderColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value != null ? _kBorderColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15,
                color: value != null ? _kBorderColor : Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? _format(value!) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null ? _kBorderColor : Colors.grey,
                  fontWeight: value != null ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPicked(null),
                child: const Icon(Icons.close, size: 14, color: _kBorderColor),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Диалог подтверждения объединения ──────────────────────────────────────

class _MergeConfirmDialog extends StatelessWidget {
  final List<Item> items;

  const _MergeConfirmDialog({required this.items});

  @override
  Widget build(BuildContext context) {
    final first = items.first;
    final totalQty =
        items.fold<int>(0, (sum, item) => sum + (item.quantity ?? 0));
    final location = first.location.floor.isNotEmpty
        ? '${first.location.floor} / ${first.location.room}'
        : first.location.room;

    return AlertDialog(
      title: const Text('Подтвердите объединение'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow('Наименование', first.name),
          _InfoRow('Положение', location),
          const Divider(height: 20),
          const Text('Количество:',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            '${items.map((e) => '${e.quantity ?? 0} шт.').join(' + ')} = $totalQty шт.',
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFF9800)),
            ),
            child: const Text(
              '⚠️ Старые QR-коды станут недействительными',
              style:
                  TextStyle(fontSize: 12, color: Color(0xFFE65100)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Подтвердить'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
