import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';
import '../../services/photo_service.dart';

const _kRed = Color(0xFFA80000);

/// Экран редактирования существующего предмета.
/// Возвращает обновлённый [Item] через Navigator.pop при сохранении.
class EditItemScreen extends StatefulWidget {
  final Item item;

  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _quantityController;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.item.name);
    _locationController =
        TextEditingController(text: widget.item.location.room);
    _quantityController =
        TextEditingController(text: widget.item.quantity?.toString() ?? '');
    _imagePath = widget.item.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final itemId = widget.item.itemId ?? 'item_${widget.item.id}';
    final result = await PhotoService.pickAndSave(
      context,
      itemId: itemId,
      hasPhoto: _imagePath != null && _imagePath!.isNotEmpty,
    );
    if (result == null) return;
    setState(() {
      _imagePath = result.isEmpty ? null : result;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final quantityText = _quantityController.text.trim();

    if (name.isEmpty) { _showError('Введите наименование'); return; }
    if (location.isEmpty) { _showError('Введите положение'); return; }
    if (quantityText.isEmpty) { _showError('Введите количество'); return; }

    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      _showError('Количество должно быть числом больше 0');
      return;
    }

    final box = Hive.box<Item>('items');

    final updatedItem = Item(
      id: widget.item.id,
      name: name,
      description: widget.item.description,
      location: Location(
        id: widget.item.location.id,
        floor: widget.item.location.floor,
        room: location,
        type: widget.item.location.type,
        description: widget.item.location.description,
      ),
      quantity: quantity,
      imagePath: _imagePath,
      inventoryNumber: widget.item.inventoryNumber,
      responsiblePerson: widget.item.responsiblePerson,
      itemId: widget.item.itemId,
      category: widget.item.category,
      createdAt: widget.item.createdAt,
      updatedAt: DateTime.now(),
    );

    await box.delete(widget.item.key);
    await box.add(updatedItem);
    await ChangeLogService.logUpdated(widget.item, updatedItem);

    if (!mounted) return;
    Navigator.of(context).pop(updatedItem);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Предмет обновлён')),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryByKey(widget.item.category);

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
          'Редактирование',
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
            // Информация о категории (только для чтения)
            if (cat != null)
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
                      child: Text(cat.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Учёт ${cat.accountingType}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
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
              label: 'Количество *',
              hint: 'Например: 5',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Фото
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _imagePath != null
                        ? _kRed
                        : const Color(0xFFE0E0E0),
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
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 20),
                label: const Text(
                  'СОХРАНИТЬ',
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
