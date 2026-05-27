import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';

const _kRed = Color(0xFFA80000);

/// Экран со списком QR-кодов для N единиц (тип учёта "по единице").
/// Показывает QR-код и артикул для каждого предмета отдельно.
class MultiQrScreen extends StatefulWidget {
  final List<Item> items;

  const MultiQrScreen({super.key, required this.items});

  @override
  State<MultiQrScreen> createState() => _MultiQrScreenState();
}

class _MultiQrScreenState extends State<MultiQrScreen> {
  // Ключи для захвата каждого QR как изображения
  late final List<GlobalKey> _qrKeys;
  // Состояние сохранения для каждой карточки
  late final List<bool> _saving;

  @override
  void initState() {
    super.initState();
    _qrKeys = List.generate(widget.items.length, (_) => GlobalKey());
    _saving = List.filled(widget.items.length, false);
  }

  /// Сохраняет QR-код по индексу в галерею
  Future<void> _saveOne(int index) async {
    setState(() => _saving[index] = true);
    try {
      final boundary = _qrKeys[index].currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      await Gal.putImageBytes(pngBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'QR ${widget.items[index].itemId ?? ''} сохранён')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving[index] = false);
    }
  }

  /// Сохраняет все QR-коды последовательно
  Future<void> _saveAll() async {
    for (int i = 0; i < widget.items.length; i++) {
      await _saveOne(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items.first;
    final category = categoryByKey(item.category);

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
        title: Text(
          'QR-коды (${widget.items.length} шт.)',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Кнопка "Сохранить все"
          TextButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.download, size: 18, color: _kRed),
            label: const Text('Все',
                style: TextStyle(color: _kRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Шапка с именем и категорией
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  if (category != null) ...[
                    Text(category.emoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          item.location.room,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Счётчик предметов
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${widget.items.length} шт.',
                      style: const TextStyle(
                          fontSize: 13,
                          color: _kRed,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Список QR-карточек
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final it = widget.items[index];
                final qrData =
                    it.itemId?.isNotEmpty == true ? it.itemId! : it.name;
                return _QrCard(
                  item: it,
                  qrData: qrData,
                  qrKey: _qrKeys[index],
                  saving: _saving[index],
                  onSave: () => _saveOne(index),
                  index: index,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Карточка одного QR-кода
class _QrCard extends StatelessWidget {
  final Item item;
  final String qrData;
  final GlobalKey qrKey;
  final bool saving;
  final VoidCallback onSave;
  final int index;

  const _QrCard({
    required this.item,
    required this.qrData,
    required this.qrKey,
    required this.saving,
    required this.onSave,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          // QR-код (обёрнут для сохранения)
          RepaintBoundary(
            key: qrKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(4),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 90,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemId ?? '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  item.location.room,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Кнопка сохранения
          IconButton(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kRed),
                  )
                : const Icon(Icons.download, color: _kRed, size: 22),
            tooltip: 'Сохранить в галерею',
          ),
        ],
      ),
    );
  }
}
