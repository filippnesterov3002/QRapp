import 'package:hive_flutter/hive_flutter.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';

class ToolExecutionResult {
  final bool success;
  final bool needsClarification;
  final String message;
  final Map<String, dynamic> data;

  const ToolExecutionResult({
    required this.success,
    required this.message,
    this.needsClarification = false,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'needs_clarification': needsClarification,
        'message': message,
        'data': data,
      };
}

class AddItemParams {
  final String name;
  final int quantity;
  final String location;
  final String category;
  final String? description;
  final String? serialNumber;

  const AddItemParams({
    required this.name,
    required this.quantity,
    required this.location,
    required this.category,
    this.description,
    this.serialNumber,
  });

  factory AddItemParams.fromJson(Map<String, dynamic> json) => AddItemParams(
        name: _asString(json['name']),
        quantity: _asInt(json['quantity']),
        location: _asString(json['location']),
        category: _asString(json['category']),
        description: _asNullableString(json['description']),
        serialNumber: _asNullableString(json['serial_number']),
      );
}

class UpdateQuantityParams {
  final String? name;
  final String? itemId;
  final String? inventoryNumber;
  final String? location;
  final String operation;
  final int quantity;

  const UpdateQuantityParams({
    this.name,
    this.itemId,
    this.inventoryNumber,
    this.location,
    required this.operation,
    required this.quantity,
  });

  factory UpdateQuantityParams.fromJson(Map<String, dynamic> json) =>
      UpdateQuantityParams(
        name: _asNullableString(json['name']),
        itemId: _asNullableString(json['item_id']),
        inventoryNumber: _asNullableString(json['inventory_number']),
        location: _asNullableString(json['location']),
        operation: _asString(json['operation']),
        quantity: _asInt(json['quantity']),
      );
}

class MoveItemParams {
  final String? name;
  final String? itemId;
  final String? inventoryNumber;
  final String? fromLocation;
  final String toLocation;

  const MoveItemParams({
    this.name,
    this.itemId,
    this.inventoryNumber,
    this.fromLocation,
    required this.toLocation,
  });

  factory MoveItemParams.fromJson(Map<String, dynamic> json) => MoveItemParams(
        name: _asNullableString(json['name']),
        itemId: _asNullableString(json['item_id']),
        inventoryNumber: _asNullableString(json['inventory_number']),
        fromLocation: _asNullableString(json['from_location']),
        toLocation: _asString(json['to_location']),
      );
}

class DisposeItemParams {
  final String? name;
  final String? itemId;
  final String? inventoryNumber;
  final String? location;
  final String mode;

  const DisposeItemParams({
    this.name,
    this.itemId,
    this.inventoryNumber,
    this.location,
    required this.mode,
  });

  factory DisposeItemParams.fromJson(Map<String, dynamic> json) =>
      DisposeItemParams(
        name: _asNullableString(json['name']),
        itemId: _asNullableString(json['item_id']),
        inventoryNumber: _asNullableString(json['inventory_number']),
        location: _asNullableString(json['location']),
        mode: _asString(json['mode']),
      );
}

/// Hive-репозиторий, через который агент меняет данные инвентаря.
class InventoryRepository {
  static const _source = 'ai_agent';

  Box<Item> get _box => Hive.box<Item>('items');

  String buildInventorySnapshot({int limit = 80}) {
    final items = _box.values.toList();
    if (items.isEmpty) return 'Инвентарь пока пуст.';

    final visible = items.take(limit).map((item) {
      final location = _locationLabel(item.location);
      return '- item_id=${item.itemId ?? 'нет'}, '
          'name="${item.name}", '
          'location="$location", '
          'quantity=${item.quantity ?? 0}, '
          'inventory_number=${item.inventoryNumber ?? 'нет'}, '
          'category=${item.category ?? 'нет'}';
    }).join('\n');

    if (items.length <= limit) return visible;
    return '$visible\n...и ещё ${items.length - limit} предметов.';
  }

  Future<ToolExecutionResult> addItem(AddItemParams params) async {
    final name = params.name.trim();
    final location = params.location.trim();
    final quantity = params.quantity;
    final category = _resolveCategory(params.category);

    if (name.isEmpty) {
      return _clarification('Уточните название предмета.');
    }
    if (location.isEmpty) {
      return _clarification('Уточните местоположение предмета.');
    }
    if (quantity <= 0) {
      return _clarification('Количество должно быть больше нуля.');
    }
    if (category == null) {
      return _clarification(
        'Уточните категорию. Доступные категории: ${_categoryList()}.',
      );
    }

    final itemId = _nextItemId();
    final now = DateTime.now();
    final item = Item(
      id: now.microsecondsSinceEpoch,
      name: name,
      description: params.description?.trim() ?? '',
      location: _locationFromText(
        location,
        type: category.name,
      ),
      quantity: quantity,
      inventoryNumber: params.serialNumber?.trim(),
      itemId: itemId,
      category: category.key,
      createdAt: now,
      updatedAt: now,
      qrCodeData: itemId,
    );

    await _box.add(item);
    await ChangeLogService.logCreated(item, source: _source);

    return ToolExecutionResult(
      success: true,
      message: 'Добавлен предмет "$name" в "$location", количество: $quantity.',
      data: _itemData(item),
    );
  }

  Future<ToolExecutionResult> updateQuantity(
    UpdateQuantityParams params,
  ) async {
    final resolved = _resolveSingle(
      name: params.name,
      itemId: params.itemId,
      inventoryNumber: params.inventoryNumber,
      location: params.location,
    );
    if (resolved.problem != null) return resolved.problem!;

    final item = resolved.item!;
    final currentQuantity = item.quantity ?? 0;
    final operation = params.operation.trim().toLowerCase();
    final delta = params.quantity;
    int newQuantity;

    switch (operation) {
      case 'increase':
        if (delta <= 0) {
          return _clarification('Уточните, на сколько увеличить количество.');
        }
        newQuantity = currentQuantity + delta;
      case 'decrease':
        if (delta <= 0) {
          return _clarification('Уточните, на сколько уменьшить количество.');
        }
        newQuantity = currentQuantity - delta;
      case 'set':
        newQuantity = delta;
      default:
        return _clarification(
          'Уточните операцию с количеством: increase, decrease или set.',
        );
    }

    if (newQuantity < 0) {
      return ToolExecutionResult(
        success: false,
        message:
            'Нельзя установить отрицательное количество для "${item.name}".',
        data: {'current_quantity': currentQuantity},
      );
    }

    final updatedItem = item.copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now(),
    );
    await _putExisting(item, updatedItem);
    await ChangeLogService.logUpdated(item, updatedItem, source: _source);

    return ToolExecutionResult(
      success: true,
      message:
          'Количество "${item.name}" изменено: $currentQuantity -> $newQuantity.',
      data: _itemData(updatedItem),
    );
  }

  Future<ToolExecutionResult> moveItem(MoveItemParams params) async {
    if (params.toLocation.trim().isEmpty) {
      return _clarification('Уточните новое местоположение.');
    }

    final resolved = _resolveSingle(
      name: params.name,
      itemId: params.itemId,
      inventoryNumber: params.inventoryNumber,
      location: params.fromLocation,
    );
    if (resolved.problem != null) return resolved.problem!;

    final item = resolved.item!;
    final oldLocation = _locationLabel(item.location);
    final updatedItem = item.copyWith(
      location: _locationFromText(
        params.toLocation,
        previous: item.location,
      ),
      updatedAt: DateTime.now(),
    );

    await _putExisting(item, updatedItem);
    await ChangeLogService.logUpdated(item, updatedItem, source: _source);

    return ToolExecutionResult(
      success: true,
      message:
          '"${item.name}" перемещён: $oldLocation -> ${_locationLabel(updatedItem.location)}.',
      data: _itemData(updatedItem),
    );
  }

  Future<ToolExecutionResult> disposeItem(DisposeItemParams params) async {
    final mode = params.mode.trim().toLowerCase();
    final resolved = _resolveSingle(
      name: params.name,
      itemId: params.itemId,
      inventoryNumber: params.inventoryNumber,
      location: params.location,
    );
    if (resolved.problem != null) return resolved.problem!;

    final item = resolved.item!;
    if (mode == 'delete') {
      await _box.delete(item.key);
      await ChangeLogService.logDeleted(item, source: _source);
      return ToolExecutionResult(
        success: true,
        message: 'Предмет "${item.name}" удалён.',
        data: _itemData(item),
      );
    }

    if (mode != 'write_off') {
      return _clarification('Уточните действие: delete или write_off.');
    }

    final oldLocation = _locationLabel(item.location);
    final stamp = DateTime.now().toIso8601String().split('.').first;
    final oldDescription = item.description.trim();
    final writeOffNote = 'Списано $stamp. Было: $oldLocation.';
    final updatedItem = item.copyWith(
      location: Location(
        id: DateTime.now().microsecondsSinceEpoch,
        floor: '',
        room: 'Списано',
        type: item.location.type,
        description: oldLocation,
      ),
      description: oldDescription.isEmpty
          ? writeOffNote
          : '$oldDescription\n$writeOffNote',
      updatedAt: DateTime.now(),
    );

    await _putExisting(item, updatedItem);
    await ChangeLogService.logUpdated(item, updatedItem, source: _source);

    return ToolExecutionResult(
      success: true,
      message: 'Предмет "${item.name}" отмечен как списанный.',
      data: _itemData(updatedItem),
    );
  }

  _ItemResolution _resolveSingle({
    String? name,
    String? itemId,
    String? inventoryNumber,
    String? location,
  }) {
    final matches = _findItems(
      name: name,
      itemId: itemId,
      inventoryNumber: inventoryNumber,
      location: location,
    );

    if (matches.isEmpty) {
      return _ItemResolution.problem(ToolExecutionResult(
        success: false,
        needsClarification: true,
        message:
            'Предмет не найден. Уточните название, артикул, инвентарный номер или местоположение.',
        data: {
          'query': {
            'name': name,
            'item_id': itemId,
            'inventory_number': inventoryNumber,
            'location': location,
          },
        },
      ));
    }

    if (matches.length > 1) {
      return _ItemResolution.problem(ToolExecutionResult(
        success: false,
        needsClarification: true,
        message:
            'Найдено несколько подходящих предметов. Уточните, какой нужен.',
        data: {
          'candidates': matches.take(10).map(_itemData).toList(),
        },
      ));
    }

    return _ItemResolution.item(matches.first);
  }

  List<Item> _findItems({
    String? name,
    String? itemId,
    String? inventoryNumber,
    String? location,
  }) {
    Iterable<Item> result = _box.values;

    final itemIdQuery = _normalize(itemId);
    if (itemIdQuery.isNotEmpty) {
      result = result.where((item) => _normalize(item.itemId) == itemIdQuery);
    }

    final inventoryQuery = _normalize(inventoryNumber);
    if (inventoryQuery.isNotEmpty) {
      result = result.where(
        (item) => _normalize(item.inventoryNumber) == inventoryQuery,
      );
    }

    final nameQuery = _normalize(name);
    if (nameQuery.isNotEmpty) {
      result = result.where((item) => _matchesText(item.name, nameQuery));
    }

    final locationQuery = _normalize(location);
    if (locationQuery.isNotEmpty) {
      result = result.where(
        (item) => _matchesText(_locationLabel(item.location), locationQuery),
      );
    }

    return result.toList();
  }

  Future<void> _putExisting(Item oldItem, Item newItem) async {
    final key = oldItem.key;
    if (key == null) {
      await _box.add(newItem);
      return;
    }
    await _box.put(key, newItem);
  }

  ItemCategory? _resolveCategory(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    for (final category in kCategories) {
      if (_normalize(category.key) == normalized ||
          _normalize(category.name) == normalized) {
        return category;
      }
    }

    const aliases = {
      'furniture': ['мебель', 'стул', 'столы', 'стол', 'chair', 'table'],
      'tech': ['техника', 'компьютер', 'ноутбук', 'laptop', 'computer', 'pc'],
      'office_tech': ['оргтехника', 'принтер', 'сканер', 'printer', 'scanner'],
      'supplies': ['расходники', 'канцелярия', 'бумага', 'supplies'],
      'tools': ['инструменты', 'инструмент', 'tools'],
    };

    for (final entry in aliases.entries) {
      if (entry.value.any((alias) => _normalize(alias) == normalized)) {
        return categoryByKey(entry.key);
      }
    }

    return null;
  }

  Location _locationFromText(
    String raw, {
    Location? previous,
    String? type,
  }) {
    final cleaned = raw.trim();
    final parts = cleaned
        .split(RegExp(r'\s*/\s*|\s*,\s*'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    final hasExplicitFloor = parts.length >= 2 &&
        (parts.first.toLowerCase().contains('этаж') ||
            parts.first.toLowerCase().contains('floor'));

    return Location(
      id: previous?.id ?? DateTime.now().microsecondsSinceEpoch,
      floor: hasExplicitFloor ? parts.first.trim() : (previous?.floor ?? ''),
      room: hasExplicitFloor ? parts.sublist(1).join(', ') : cleaned,
      type: type ?? previous?.type ?? '',
      description: previous?.description,
    );
  }

  String _nextItemId() {
    final existing = _box.values
        .map((item) => item.itemId)
        .whereType<String>()
        .map(_normalize)
        .toSet();

    var number = _box.length + 1;
    while (existing
        .contains(_normalize('ITEM-${number.toString().padLeft(3, '0')}'))) {
      number++;
    }
    return 'ITEM-${number.toString().padLeft(3, '0')}';
  }

  Map<String, dynamic> _itemData(Item item) => {
        'item_id': item.itemId,
        'name': item.name,
        'location': _locationLabel(item.location),
        'quantity': item.quantity ?? 0,
        'inventory_number': item.inventoryNumber,
        'category': item.category,
      };

  ToolExecutionResult _clarification(String message) => ToolExecutionResult(
        success: false,
        needsClarification: true,
        message: message,
      );

  String _categoryList() => kCategories
      .map((category) => '${category.key} (${category.name})')
      .join(', ');

  String _locationLabel(Location location) {
    if (location.floor.trim().isEmpty) return location.room;
    return '${location.floor} / ${location.room}';
  }

  bool _matchesText(String source, String normalizedQuery) {
    final normalizedSource = _normalize(source);
    if (normalizedSource == normalizedQuery) return true;
    if (normalizedSource.contains(normalizedQuery)) return true;
    if (normalizedQuery.contains(normalizedSource)) return true;

    final sourceTokens = normalizedSource.split(' ');
    final queryTokens = normalizedQuery.split(' ');
    return queryTokens.every((queryToken) {
      final queryStem = _roughStem(queryToken);
      return sourceTokens.any((sourceToken) {
        final sourceStem = _roughStem(sourceToken);
        return sourceStem == queryStem ||
            sourceStem.startsWith(queryStem) ||
            queryStem.startsWith(sourceStem);
      });
    });
  }

  String _normalize(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _roughStem(String value) {
    const endings = [
      'иями',
      'ями',
      'ами',
      'ьев',
      'ого',
      'ему',
      'ими',
      'ыми',
      'ая',
      'яя',
      'ые',
      'ие',
      'ый',
      'ий',
      'ой',
      'ых',
      'их',
      'ов',
      'ев',
      'ья',
      'ам',
      'ям',
      'ах',
      'ях',
      'ом',
      'ем',
      'а',
      'я',
      'ы',
      'и',
      'е',
      'у',
      'ю',
    ];

    for (final ending in endings) {
      if (value.length > ending.length + 2 && value.endsWith(ending)) {
        return value.substring(0, value.length - ending.length);
      }
    }
    return value;
  }
}

class _ItemResolution {
  final Item? item;
  final ToolExecutionResult? problem;

  const _ItemResolution.item(this.item) : problem = null;
  const _ItemResolution.problem(this.problem) : item = null;
}

String _asString(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

String? _asNullableString(Object? value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
