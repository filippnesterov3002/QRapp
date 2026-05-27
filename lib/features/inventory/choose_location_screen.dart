import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/items.dart';
class ChooseLocationScreen extends StatefulWidget {
  const ChooseLocationScreen({super.key});

  @override
  State<ChooseLocationScreen> createState() => _ChooseLocationScreenState();
}

class _ChooseLocationScreenState extends State<ChooseLocationScreen> {
  final TextEditingController floorController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  Location? selectedLocation;
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
        title: const Text("Выбор положения",style: TextStyle(color: Colors.black),),
      ),
      body: SingleChildScrollView(  // Оборачиваем в SingleChildScrollView
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),
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
                labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
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
              isDense:false,
              initialValue: selectedItem,
              items: const [
                DropdownMenuItem(value: "Стол", child: Text("Стол",style: TextStyle(fontSize: 20),)),
                DropdownMenuItem(value: "Шкаф", child: Text("Шкаф",style: TextStyle(fontSize: 20),)),
                DropdownMenuItem(value: "Помещение", child: Text("Помещение",style: TextStyle(fontSize: 20),)),
              ],
              onChanged: (value) {
                setState(() {
                  selectedItem = value!;
                });
              },
              decoration: InputDecoration(
                labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
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

            const SizedBox(height: 250,),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (floorController.text.isEmpty || roomController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заполните все поля',style: TextStyle(fontSize: 23),)),
                    );
                    return;
                  }
                  final selectedLocation=Location(
                    id: DateTime.now().millisecondsSinceEpoch,
                    floor: floorController.text,
                    room: roomController.text,
                    type: selectedItem,
                  );
                  debugPrint(selectedLocation.toJson().toString());

                  Navigator.pop(context,selectedLocation);
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
                  "Выбрать",  // Текст кнопки
                  style: TextStyle(color: Colors.black, fontSize: 25),  // Чёрный текст
                ),
              ),
            )
          ],
        ),
      ),

    );
  }
}