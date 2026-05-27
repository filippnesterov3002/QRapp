// StatefulWidget для основного экрана, так как он будет хранить состояние фильтра и списка товаров.
// class InventoryScreen extends StatefulWidget {
//   const InventoryScreen({super.key});
//
//   @override
//   State<InventoryScreen> createState() => _InventoryScreenState();
// }
//
// class _InventoryScreenState extends State<InventoryScreen> {
//   // Переменная для хранения выбранной категории
//   String _selectedCategory = 'All';
//
//   // Список всех товаров (например, получаем из базы или API)
//   final List<String> allItems = [
//     'Laptop',
//     'Monitor',
//     'Keyboard',
//     'Mouse',
//     'Printer',
//   ];
//
//   // Метод для фильтрации товаров на основе выбранной категории
//   List<String> get _filteredItems {
//     if (_selectedCategory == 'All') {
//       return allItems; // Показать все товары
//     } else {
//       return allItems.where((item) => item.startsWith(_selectedCategory)).toList();
//     }
//   }
//
//   // Метод для обновления состояния при изменении категории
//   void _updateCategory(String newCategory) {
//     setState(() {
//       _selectedCategory = newCategory; // Установить новую категорию
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Inventory Screen'),
//       ),
//       body: Column(
//         children: [
//           // StatelessWidget для выбора категории (фильтра)
//           FilterDropdown(
//             selectedCategory: _selectedCategory,
//             onCategorySelected: _updateCategory, // Передаем функцию для обновления категории
//           ),
//           // Отображение списка товаров
//           Expanded(
//             child: ListView.builder(
//               itemCount: _filteredItems.length,
//               itemBuilder: (context, index) {
//                 return ListTile(
//                   title: Text(_filteredItems[index]),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // StatelessWidget для выпадающего меню выбора категории
// class FilterDropdown extends StatelessWidget {
//   final String selectedCategory;
//   final Function(String) onCategorySelected;
//
//   const FilterDropdown({
//     super.key,
//     required this.selectedCategory,
//     required this.onCategorySelected,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: DropdownButton<String>(
//         value: selectedCategory,
//         items: <String>['All', 'L', 'M', 'K', 'P'].map((String category) {
//           return DropdownMenuItem<String>(
//             value: category,
//             child: Text(category),
//           );
//         }).toList(),
//         onChanged: (String? newCategory) {
//           if (newCategory != null) {
//             onCategorySelected(newCategory); // Вызов функции для обновления категории
//           }
//         },
//       ),
//     );
//   }
// }
//
