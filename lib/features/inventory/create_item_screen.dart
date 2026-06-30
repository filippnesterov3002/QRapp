import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';
import '../../services/photo_service.dart';

const _kRed = Color(0xFFA80000);

/// Возможные действия при обнаружении дубликата
enum _MergeChoice { merge, separate }

/// Форма создания нового предмета с выбранной категорией.
///
/// [onCreated] вызывается со списком созданных предметов и
/// необязательным текстом предупреждения (не null при объединении).
class CreateItemScreen extends StatefulWidget {
  final ItemCategory category;
  final void Function(List<Item> items, String? mergeWarning) onCreated;

  const CreateItemScreen({
    super.key,
    required this.category,
    required this.onCreated,
  });

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _quantityController = TextEditingController();

  /// Путь к выбранному фото (null = не выбрано)
  String? _imagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  /// Открывает шторку выбора фото.
  /// Временный артикул нужен для имени файла — используем timestamp если itemId ещё не сгенерирован.
  Future<void> _pickPhoto() async {
    final tempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final result = await PhotoService.pickAndSave(
      context,
      itemId: tempId,
      hasPhoto: _imagePath != null,
    );
    if (result == null) return; // Пользователь нажал «Пропустить»
    setState(() {
      // Пустая строка = «Удалить фото»
      _imagePath = result.isEmpty ? null : result;
    });
  }

  /// Генерирует следующий артикул на основе текущего размера ящика Hive
  String _nextItemId(Box<Item> box) =>
      'ITEM-${(box.length + 1).toString().padLeft(3, '0')}';

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty) {
      _showError('Введите наименование');
      return;
    }
    if (location.isEmpty) {
      _showError('Введите положение');
      return;
    }
    if (quantityText.isEmpty) {
      _showError('Введите количество');
      return;
    }

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      _showError('Количество должно быть числом больше 0');
      return;
    }

    final box = Hive.box<Item>('items');

    // ── Способ 1: проверка на дубликат (только для типа "по виду") ─────────
    if (!widget.category.perUnit) {
      final existing = box.values
          .cast<Item>()
          .where((item) =>
              item.name.trim().toLowerCase() == name.toLowerCase() &&
              item.location.room.trim().toLowerCase() == location.toLowerCase())
          .firstOrNull;

      if (existing != null) {
        // Найден дубликат — предлагаем объединить или создать отдельно
        final choice = await _showDuplicateDialog(existing, quantity);
        if (!mounted) return;
        if (choice == null) return; // Пользователь нажал «Назад»

        if (choice == _MergeChoice.merge) {
          // Объединяем: новый itemId, суммарное количество
          final newItemId = _nextItemId(box);
          final mergedItem = _buildItem(
            box: box,
            name: name,
            location: location,
            quantity: (existing.quantity ?? 0) + quantity,
            itemId: newItemId,
            existing: existing,
          );
          existing.delete(); // Удаляем старую запись
          box.add(mergedItem);
          await ChangeLogService.logCreated(mergedItem);

          if (!mounted) return;
          Navigator.of(context).pop();
          widget.onCreated(
            [mergedItem],
            '⚠️ Старый QR-код недействителен!\nЗамените наклейку на предмете',
          );
        } else {
          // Создаём отдельно с новым артикулом
          final newItem = _buildItem(
            box: box,
            name: name,
            location: location,
            quantity: quantity,
            itemId: _nextItemId(box),
          );
          box.add(newItem);
          await ChangeLogService.logCreated(newItem);
          if (!mounted) return;
          Navigator.of(context).pop();
          widget.onCreated([newItem], null);
        }
        return;
      }
    }

    // ── Обычное создание ───────────────────────────────────────────────────
    final createdItems = <Item>[];

    if (widget.category.perUnit) {
      // Тип "по единице" — N отдельных записей, каждая со своим артикулом
      for (int i = 0; i < quantity; i++) {
        final itemId =
            'ITEM-${(box.length + i + 1).toString().padLeft(3, '0')}';
        final item = _buildItem(
          box: box,
          name: name,
          location: location,
          quantity: 1,
          itemId: itemId,
        );
        box.add(item);
        await ChangeLogService.logCreated(item);
        createdItems.add(item);
      }
    } else {
      // Тип "по виду" — 1 запись с указанным количеством
      final item = _buildItem(
        box: box,
        name: name,
        location: location,
        quantity: quantity,
        itemId: _nextItemId(box),
      );
      box.add(item);
      await ChangeLogService.logCreated(item);
      createdItems.add(item);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onCreated(createdItems, null);
  }

  /// Создаёт объект Item из введённых данных.
  /// Если [existing] задан — копирует его вспомогательные поля.
  /// [overrideImagePath] позволяет явно задать путь к фото.
  Item _buildItem({
    required Box<Item> box,
    required String name,
    required String location,
    required int quantity,
    required String itemId,
    Item? existing,
    String? overrideImagePath,
  }) {
    return Item(
      id: DateTime.now().millisecondsSinceEpoch,
      name: name,
      description: existing?.description ?? '',
      location: existing?.location ??
          Location(
            id: DateTime.now().millisecondsSinceEpoch,
            floor: '',
            room: location,
            type: widget.category.name,
          ),
      quantity: quantity,
      itemId: itemId,
      category: widget.category.key,
      // Приоритет: явно переданный путь → путь из формы → путь из существующей записи
      imagePath: overrideImagePath ?? _imagePath ?? existing?.imagePath,
      inventoryNumber: existing?.inventoryNumber,
      responsiblePerson: existing?.responsiblePerson,
      // При merge сохраняем дату создания оригинала; при новом — DateTime.now()
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      qrCodeData: itemId,
    );
  }

  /// Диалог при обнаружении дубликата.
  /// Возвращает выбор пользователя или null при отмене.
  Future<_MergeChoice?> _showDuplicateDialog(Item existing, int newQty) async {
    return showDialog<_MergeChoice>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final oldQty = existing.quantity ?? 0;
        final total = oldQty + newQty;
        return AlertDialog(
          title: const Text('Похожий предмет уже существует'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Информация об уже существующем предмете
              _DialogInfoRow('Наименование', existing.name),
              _DialogInfoRow('Положение', existing.location.room),
              const Divider(height: 24),
              // Сравнение количеств
              _DialogInfoRow('Уже в базе', '$oldQty шт.'),
              _DialogInfoRow('Добавляется', '$newQty шт.'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Итого: $total шт.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            // Отмена — закрыть диалог
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Назад'),
            ),
            // Создать отдельно — новая запись с новым артикулом
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, _MergeChoice.separate),
              child: const Text('Создать отдельно'),
            ),
            // Объединить — сложить количества
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, _MergeChoice.merge),
              child: const Text('Объединить'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

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
          'Новый предмет',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Блок с информацией о выбранной категории
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(cat.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Тип учёта — только для чтения
                        Text(
                          'Учёт ${cat.accountingType}',
                          style:
                              const TextStyle(fontSize: 13, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildField(
              controller: _nameController,
              label: 'Наименование *',
              hint: 'Например: стул офисный',
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _locationController,
              label: 'Положение *',
              hint: 'Например: Этаж 2, кабинет 205',
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _quantityController,
              label: cat.perUnit
                  ? 'Количество * (будет создано N QR-кодов)'
                  : 'Количество *',
              hint: 'Например: 5',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Область добавления фото
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _imagePath != null ? _kRed : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: _imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(_imagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Добавить фото (необязательно)',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[500]),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.qr_code, size: 20),
                label: const Text(
                  'СОЗДАТЬ QR',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        fillColor: Colors.white,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kRed)),
      ),
    );
  }
}

/// Вспомогательная строка в диалоге: метка + значение
class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogInfoRow(this.label, this.value);

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
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
