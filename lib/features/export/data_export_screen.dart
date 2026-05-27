import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final TextEditingController floorController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  String selectedItem = "Шкаф";

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
        title: const Text("Выбрать положение", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: floorController,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: "Этаж",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
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
            const SizedBox(height: 20),
            TextField(
              controller: roomController,
              decoration: InputDecoration(
                alignLabelWithHint: true,
                labelText: "Помещение",
                labelStyle: const TextStyle(color: Colors.black, fontSize: 20),
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
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: selectedItem,
              items: const [
                DropdownMenuItem(value: "Шкаф", child: Text("Шкаф",style: TextStyle(color: Colors.black, fontSize: 20),)),
                DropdownMenuItem(value: "Полка", child: Text("Полка",style: TextStyle(color: Colors.black, fontSize: 20))),
                DropdownMenuItem(value: "Стол", child: Text("Стол",style: TextStyle(color: Colors.black, fontSize: 20))),
              ],

              onChanged: (value) {
                setState(() {
                  selectedItem = value!;
                });
              },
              decoration: InputDecoration(
                alignLabelWithHint: true,
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
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Растягиваем кнопки на всю ширину
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Действие выгрузить конкретное
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text(
                    "Выгрузить конкретное",
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 25), // Отступ между кнопками
                ElevatedButton(
                  onPressed: () {
                    // Действие выгрузить все
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text(
                    "Выгрузить все",
                    style: TextStyle(color: Colors.black, fontSize: 20),
                  ),
                ),
                const SizedBox(height: 30,)
              ],
            ),

          ],
        ),
      ),
    );
  }
}