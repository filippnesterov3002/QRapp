import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/items.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  File? _pickedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  void _submit() {
    if (_nameController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название и положение')),
      );
      return;
    }

    final newItem = Item(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _nameController.text,
      description: '',
      location: Location(
        id: DateTime.now().millisecondsSinceEpoch,
        floor: '',
        room: _locationController.text,
        type: 'Помещение',
      ),
      quantity: int.tryParse(_quantityController.text),
      imagePath: _pickedImage?.path,
    );

    // Сохраняем напрямую в Hive
    Hive.box<Item>('items').add(newItem);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
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
        title: const Text('Добавить предмет',
            style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Название
            _buildField(
              controller: _nameController,
              label: 'Название имущества',
              hint: 'например: стол',
            ),
            const SizedBox(height: 16),

            // Положение
            _buildField(
              controller: _locationController,
              label: 'Положение имущества',
              hint: 'например: этаж 5 кабинет 112',
            ),
            const SizedBox(height: 16),

            // Количество
            _buildField(
              controller: _quantityController,
              label: 'Количество',
              hint: 'например: 10',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Кнопка выбора изображения
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: _pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(_pickedImage!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Иконка стопки фотографий
                          SizedBox(
                            width: 72,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: _photoIcon(offset: true),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: _photoIcon(offset: true),
                                ),
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: _photoIcon(offset: false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Выберите изображение',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFFA80000),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Кнопка сохранить
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'СОХРАНИТЬ',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.black, fontSize: 16),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA80000)),
        ),
      ),
    );
  }

  Widget _photoIcon({required bool offset}) {
    return Container(
      width: 46,
      height: 38,
      decoration: BoxDecoration(
        color: offset ? Colors.white : Colors.white,
        border: Border.all(color: const Color(0xFFA80000), width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: offset
          ? null
          : const Icon(Icons.image_outlined,
              color: Color(0xFFA80000), size: 22),
    );
  }
}
