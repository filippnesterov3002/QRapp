/// Модель категории предмета и список доступных категорий

class ItemCategory {
  final String key;       // Внутренний ключ для хранения в Hive
  final String name;      // Название категории
  final String emoji;     // Иконка-эмодзи
  final bool perUnit;     // true = "по единице", false = "по виду"

  const ItemCategory({
    required this.key,
    required this.name,
    required this.emoji,
    required this.perUnit,
  });

  /// Читаемый тип учёта
  String get accountingType => perUnit ? 'по единице' : 'по виду';
}

/// Все доступные категории
const kCategories = [
  ItemCategory(key: 'furniture',   name: 'Мебель',       emoji: '🪑', perUnit: false),
  ItemCategory(key: 'tech',        name: 'Техника',       emoji: '💻', perUnit: true),
  ItemCategory(key: 'office_tech', name: 'Оргтехника',    emoji: '🖨',  perUnit: true),
  ItemCategory(key: 'supplies',    name: 'Расходники',    emoji: '📦', perUnit: false),
  ItemCategory(key: 'tools',       name: 'Инструменты',   emoji: '🔧', perUnit: false),
];

/// Возвращает категорию по ключу, или null если не найдена
ItemCategory? categoryByKey(String? key) {
  if (key == null || key.isEmpty) return null;
  try {
    return kCategories.firstWhere((c) => c.key == key);
  } catch (_) {
    return null;
  }
}
