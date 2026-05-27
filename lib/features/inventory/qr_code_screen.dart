import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/items.dart';

const _kRed = Color(0xFFA80000);

class QrCodeScreen extends StatefulWidget {
  final Item item;
  /// Если задано — показывает предупреждение об устаревших QR-кодах
  final String? mergeWarning;

  const QrCodeScreen({super.key, required this.item, this.mergeWarning});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen> {
  // Ключ для захвата QR-кода как изображения
  final GlobalKey _qrKey = GlobalKey();
  bool _saving = false;

  /// Сохраняет QR-код в галерею устройства
  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final RenderRepaintBoundary boundary = _qrKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR-код сохранён в галерею')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Формирует строку местоположения
  String _buildLocation() {
    final floor = widget.item.location.floor;
    final room = widget.item.location.room;
    if (floor.isNotEmpty && room.isNotEmpty) return '$floor / $room';
    if (room.isNotEmpty) return room;
    if (floor.isNotEmpty) return floor;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Данные QR-кода — артикул или название, если артикул не задан
    final qrData = item.itemId?.isNotEmpty == true ? item.itemId! : item.name;

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
          'QR-код предмета',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Предупреждение об устаревших QR-кодах (показывается после объединения)
            if (widget.mergeWarning != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.mergeWarning!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            // QR-код обёрнут в RepaintBoundary для сохранения в галерею
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Информационные строки с красной рамкой
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _kRed, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  _InfoRow(label: 'Наименование', value: item.name),
                  Container(height: 1, color: _kRed.withValues(alpha: 0.3)),
                  _InfoRow(
                    label: 'Артикул',
                    value: item.itemId?.isNotEmpty == true ? item.itemId! : '—',
                  ),
                  Container(height: 1, color: _kRed.withValues(alpha: 0.3)),
                  _InfoRow(label: 'Положение', value: _buildLocation()),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Кнопка сохранения в галерею
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToGallery,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 20),
                label: Text(
                  _saving ? 'Сохранение...' : 'Сохранить в галерею',
                  style: const TextStyle(fontSize: 16),
                ),
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
}

/// Строка с разделителем между меткой и значением
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Container(
            width: 120,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Container(width: 1.5, color: _kRed),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
