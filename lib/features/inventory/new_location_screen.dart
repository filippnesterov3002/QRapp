import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/items.dart';
class NewLocationScreen extends StatefulWidget {
  const NewLocationScreen({super.key});

  @override
  State<NewLocationScreen> createState() => _NewLocationScreenState();
}

class _NewLocationScreenState extends State<NewLocationScreen> {
  final TextEditingController floorController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  String selectedItem = "Стол";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(

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
        title: const Text("Новое положение",style: TextStyle(color: Colors.black),),
      ),
      body: SingleChildScrollView(  // Оборачиваем в SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Поле "Этаж"
            TextField(
              controller: floorController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Этаж",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular (16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 25),
            // Поле "Помещение"
            TextField(
              controller: roomController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Помещение",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 22),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 25),
            // Выпадающий список/////////////////////////
            DropdownButtonFormField<String>(
              isDense: false,
              initialValue: selectedItem,
              items: const [
                DropdownMenuItem(value: "Стол", child: Text("Стол",style: TextStyle(fontSize: 22),)),
                DropdownMenuItem(value: "Шкаф", child: Text("Шкаф",style: TextStyle(fontSize: 22),)),
                DropdownMenuItem(value: "Помещение", child: Text("Помещение",style: TextStyle(fontSize: 22),)),

              ],
              onChanged: (value) {
                setState(() {
                  selectedItem = value!;
                });
              },
              decoration: InputDecoration(
                labelStyle: const TextStyle(color: Colors.black, fontSize: 22),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 25),
            // Поле "Описание"
            TextField(
              controller: descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: "Описание",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 22),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 180),  // Оставляем пространство перед кнопкой
            // Кнопка "Добавить"
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (floorController.text.isEmpty || roomController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заполните все поля', style: TextStyle(fontSize: 24))),
                    );
                    return;
                  }
                  final newLocation = Location(
                    id: DateTime.now().millisecondsSinceEpoch,
                    floor: floorController.text,
                    room: roomController.text,
                    type: selectedItem,
                    description: descriptionController.text,
                  );
                  debugPrint(newLocation.toJson().toString());
                  Navigator.pop(context, newLocation);
                  // Действие при нажатии на кнопку
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 25.0, horizontal: 70.0),  // Высокая кнопка
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0), // Скругление углов кнопки
                  ),
                  backgroundColor: Colors.white,  // Белый цвет фона кнопки
                  textStyle: const TextStyle(color: Colors.black), // Чёрный цвет текста
                  elevation: 0, // Без тени
                ),
                child: const Text(
                  "Добавить",  // Текст кнопки
                  style: TextStyle(color: Colors.black, fontSize: 24),  // Чёрный текст
                ),
              ),
            )
          ],
        ),
      ),

    );
  }
}