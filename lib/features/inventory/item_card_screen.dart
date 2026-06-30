import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';
import '../../services/photo_service.dart';
import 'edit_item_screen.dart';
import 'item_history_screen.dart';
import 'qr_code_screen.dart';

const _kRed = Color(0xFFA80000);

class ItemCardScreen extends StatefulWidget {
  final Item item;

  const ItemCardScreen({super.key, required this.item});

  @override
  State<ItemCardScreen> createState() => _ItemCardScreenState();
}

class _ItemCardScreenState extends State<ItemCardScreen> {
  late Item _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMMM yyyy, HH:mm', 'ru').format(dt);
  }

  Future<void> _saveUpdatedItem(Item updatedItem,
      {String source = 'manual'}) async {
    final box = Hive.box<Item>('items');
    final key = _item.key;
    if (key != null) {
      await box.put(key, updatedItem);
    } else {
      await box.add(updatedItem);
    }
    await ChangeLogService.logUpdated(_item, updatedItem, source: source);

    if (mounted) {
      setState(() => _item = updatedItem);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openQrCode({Item? item}) async {
    final targetItem = item ?? _item;
    final qrData = targetItem.qrCodeData?.trim().isNotEmpty == true
        ? targetItem.qrCodeData!.trim()
        : targetItem.itemId?.trim();
    if (qrData == null || qrData.isEmpty) {
      _showError('Нельзя создать QR-код: у предмета нет артикула');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QrCodeScreen(item: targetItem)),
    );
  }

  Future<void> _createQrCode() async {
    final itemId = _item.itemId?.trim();
    if (itemId == null || itemId.isEmpty) {
      _showError('Нельзя создать QR-код: у предмета нет артикула');
      return;
    }

    final updatedItem = _item.copyWith(
      qrCodeData: itemId,
      updatedAt: DateTime.now(),
    );
    await _saveUpdatedItem(updatedItem, source: 'qr');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR-код создан')),
    );
    await _openQrCode(item: updatedItem);
  }

  /// Открывает шторку выбора фото и обновляет запись в Hive
  Future<void> _editPhoto() async {
    final itemId = _item.itemId ?? 'item_${_item.id}';

    final result = await PhotoService.pickAndSave(
      context,
      itemId: itemId,
      hasPhoto: _item.imagePath != null && _item.imagePath!.isNotEmpty,
    );

    if (result == null) return;

    final newPath = result.isEmpty ? null : result;

    final updatedItem = _item.copyWith(
      imagePath: newPath,
      clearImagePath: newPath == null,
      updatedAt: DateTime.now(),
    );
    await _saveUpdatedItem(updatedItem);
  }

  /// Показывает диалог подтверждения удаления
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить предмет?'),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            children: [
              TextSpan(
                  text: _item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (_item.itemId?.isNotEmpty == true) ...[
                const TextSpan(text: '\n'),
                TextSpan(
                  text: _item.itemId,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const TextSpan(
                text: '\n\nЭто действие нельзя отменить.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final box = Hive.box<Item>('items');
    await box.delete(_item.key);
    await ChangeLogService.logDeleted(_item);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑 Предмет удалён')),
    );
  }

  /// Открывает экран редактирования
  Future<void> _openEdit() async {
    final updated = await Navigator.push<Item>(
      context,
      MaterialPageRoute(builder: (_) => EditItemScreen(item: _item)),
    );
    if (updated != null && mounted) {
      setState(() => _item = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _item.location.floor.isNotEmpty
        ? '${_item.location.floor} / ${_item.location.room}'
        : _item.location.room;
    final hasImage = _item.imagePath != null && _item.imagePath!.isNotEmpty;
    final cat = categoryByKey(_item.category);
    final hasQrCode = _item.hasQrCode;
    final articleText = _item.itemId?.isNotEmpty == true
        ? _item.itemId!
        : (_item.inventoryNumber?.isNotEmpty == true
            ? _item.inventoryNumber!
            : '—');

    final createdAt = _item.createdAt;
    final updatedAt = _item.updatedAt;
    final showUpdated = updatedAt != null &&
        createdAt != null &&
        updatedAt.difference(createdAt).inSeconds.abs() > 1;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _kRed),
            tooltip: 'Редактировать',
            onPressed: _openEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _kRed),
            tooltip: 'Удалить',
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото
            GestureDetector(
              onTap: _editPhoto,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _kRed, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: hasImage
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(
                              File(_item.imagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите чтобы добавить фото',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[400]),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Карточка с информацией
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _kRed.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Наименование
                  _InfoRow(label: 'Название', value: _item.name),
                  _divider(),
                  // Артикул
                  _InfoRow(label: 'Артикул', value: articleText),
                  _divider(),
                  // Категория
                  _InfoRow(
                    label: 'Категория',
                    value: cat != null
                        ? '${cat.emoji}  ${cat.name}'
                        : (_item.category ?? '—'),
                  ),
                  _divider(),
                  // Положение
                  _InfoRow(label: 'Положение', value: location),
                  _divider(),
                  // Количество — крупным красным шрифтом
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Количество',
                            style: TextStyle(fontSize: 14, color: Colors.grey)),
                        Text(
                          '${_item.quantity ?? 0} шт.',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _kRed,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // История изменений
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemHistoryScreen(item: _item),
                      ),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 16, color: _kRed),
                          SizedBox(width: 8),
                          Text('История изменений',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _kRed,
                                  fontWeight: FontWeight.w500)),
                          Spacer(),
                          Icon(Icons.chevron_right, size: 16, color: _kRed),
                        ],
                      ),
                    ),
                  ),

                  // Разделитель перед датами
                  const Divider(height: 1, thickness: 1),

                  // Дата создания
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          'Создан: ${_formatDate(createdAt)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // Дата изменения (только если отличается от createdAt)
                  if (showUpdated)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar_outlined,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'Изменён: ${_formatDate(updatedAt)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: hasQrCode
                  ? OutlinedButton.icon(
                      onPressed: () => _openQrCode(),
                      icon: const Icon(Icons.qr_code_2, size: 20),
                      label: const Text('Показать QR-код'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kRed,
                        side: const BorderSide(color: _kRed, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _createQrCode,
                      icon: const Icon(Icons.qr_code_2, size: 20),
                      label: const Text('Создать QR-код'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 1, color: _kRed.withValues(alpha: 0.2));
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
