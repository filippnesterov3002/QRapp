import 'package:flutter/material.dart';
import '../../models/item_category.dart';

const _kRed = Color(0xFFA80000);

/// Шторка выбора категории предмета перед созданием QR-кода
class CategorySelectionSheet extends StatelessWidget {
  final void Function(ItemCategory category) onCategorySelected;

  const CategorySelectionSheet({super.key, required this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок шторки
              const Text(
                'Выберите категорию',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'От категории зависит тип учёта предмета',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Сетка категорий — 2 колонки
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.9,
                ),
                itemCount: kCategories.length,
                itemBuilder: (context, index) {
                  final cat = kCategories[index];
                  return _CategoryCard(
                    category: cat,
                    onTap: () {
                      // Закрываем шторку и передаём выбранную категорию
                      Navigator.of(context).pop();
                      onCategorySelected(cat);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка одной категории
class _CategoryCard extends StatelessWidget {
  final ItemCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Иконка-эмодзи в круглом контейнере
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(category.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            // Название и тип учёта
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    category.accountingType,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
