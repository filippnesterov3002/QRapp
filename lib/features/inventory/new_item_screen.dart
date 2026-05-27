import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/items.dart';
import 'choose_location_screen.dart';
class NewItemScreen extends StatefulWidget {
  const NewItemScreen({super.key});

  @override
  State<NewItemScreen> createState() => _NewItemScreenState();
}

class _NewItemScreenState extends State<NewItemScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  Location? selectedLocation; // Переменная для хранения выбранного положения

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white70,
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
        title: const Text("Новая вещь", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 25),
            TextField(
              maxLines: 2,
              controller: nameController,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: "Название",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: "Описание",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 22),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
            const SizedBox(height: 25),
            // Кнопка "Выбрать положение"
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  // Открываем экран выбора положения и ждем результат
                  final selectedLocation = await Navigator.push<Location>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChooseLocationScreen(),
                    ),
                  );

                  // Если пользователь выбрал положение, сохраняем его
                  if (selectedLocation != null) {
                    setState(() {
                      this.selectedLocation = selectedLocation;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 80.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  backgroundColor: Colors.lightBlue[100],
                  textStyle: const TextStyle(color: Colors.black),
                  elevation: 0,
                ),
                child: const Text(
                  "Выбрать положение",
                  style: TextStyle(color: Colors.black, fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty || descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните все поля', style: TextStyle(fontSize: 24))),
                  );
                  return;
                }

                if (selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Выберите положение', style: TextStyle(fontSize: 24))),
                  );
                  return;
                }

                final newItem = Item(
                  id: DateTime.now().millisecondsSinceEpoch,
                  name: nameController.text,
                  description: descriptionController.text,
                  location: selectedLocation!,
                );

                Hive.box<Item>('items').add(newItem);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 70),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text("Добавить", style: TextStyle(color: Colors.black, fontSize: 25)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}