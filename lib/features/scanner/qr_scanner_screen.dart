import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/item_category.dart';
import '../../models/items.dart';

const _kRed = Color(0xFFA80000);

// Размер прицела (квадратное окно сканирования)
const double _kScanWindowSize = 250.0;

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  // Пока true — новые QR-коды игнорируются (BottomSheet открыт)
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Обработка отсканированного кода ─────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    _controller.stop();

    // Ищем предмет по itemId, числовому id или по названию
    final allItems = Hive.box<Item>('items').values.toList();
    final found = allItems.where((e) =>
        e.itemId == rawValue ||
        e.id.toString() == rawValue ||
        e.name == rawValue).firstOrNull;

    if (found != null) {
      _showItemSheet(found);
    } else {
      _showNotFoundSheet(rawValue);
    }
  }

  // ── BottomSheet: предмет найден ──────────────────────────────────────────

  void _showItemSheet(Item item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ItemFoundSheet(item: item),
    ).whenComplete(_resumeScanning);
  }

  // ── BottomSheet: предмет не найден ───────────────────────────────────────

  void _showNotFoundSheet(String rawValue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ItemNotFoundSheet(),
    ).whenComplete(_resumeScanning);
  }

  // ── Возобновить сканирование после закрытия BottomSheet ──────────────────

  void _resumeScanning() {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    _controller.start();
  }

  // ── Открыть настройки приложения (для разрешения камеры) ─────────────────

  Future<void> _openSettings() async {
    final uri = Uri.parse(
      Platform.isIOS ? 'app-settings:' : 'package:${_packageName()}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _packageName() => 'com.example.qr_layout'; // fallback

  // ── Сборка прицела (позиция для scanWindow) ──────────────────────────────

  Rect _buildScanRect(Size screenSize) {
    final center = screenSize.center(Offset.zero);
    return Rect.fromCenter(
      center: center,
      width: _kScanWindowSize,
      height: _kScanWindowSize,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanRect = _buildScanRect(size);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Кнопка «назад» поверх камеры
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
          'Сканирование QR-кода',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Камера на весь экран
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Подсвечиваем только окно прицела для повышения точности
            scanWindow: scanRect,
            errorBuilder: (context, error, _) {
              // Разрешение камеры отклонено
              if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                return _PermissionDeniedView(onOpenSettings: _openSettings);
              }
              // Другая ошибка инициализации
              return _CameraErrorView(message: error.errorDetails?.message);
            },
          ),

          // Полупрозрачный оверлей с вырезом для прицела
          CustomPaint(
            size: size,
            painter: _ScanOverlayPainter(scanRect),
          ),

          // Подсказка под прицелом
          Positioned(
            left: 0,
            right: 0,
            top: scanRect.bottom + 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Наведите камеру на QR-код',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Оверлей сканера: затемнение + прицел ──────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final Rect scanRect;

  const _ScanOverlayPainter(this.scanRect);

  @override
  void paint(Canvas canvas, Size size) {
    // Затемнение всего экрана кроме прицела
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final windowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
          scanRect, const Radius.circular(12)));

    canvas.drawPath(
      Path.combine(PathOperation.difference, fullPath, windowPath),
      shadow,
    );

    // Красная рамка прицела
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(12)),
      Paint()
        ..color = _kRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Угловые маркеры прицела (Г-образные штрихи)
    const markerLen = 24.0;
    const markerWidth = 4.0;
    final mp = Paint()
      ..color = _kRed
      ..strokeWidth = markerWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final l = scanRect.left;
    final t = scanRect.top;
    final r = scanRect.right;
    final b = scanRect.bottom;

    // Верхний-левый
    canvas.drawLine(Offset(l, t + markerLen), Offset(l, t), mp);
    canvas.drawLine(Offset(l, t), Offset(l + markerLen, t), mp);
    // Верхний-правый
    canvas.drawLine(Offset(r - markerLen, t), Offset(r, t), mp);
    canvas.drawLine(Offset(r, t), Offset(r, t + markerLen), mp);
    // Нижний-левый
    canvas.drawLine(Offset(l, b - markerLen), Offset(l, b), mp);
    canvas.drawLine(Offset(l, b), Offset(l + markerLen, b), mp);
    // Нижний-правый
    canvas.drawLine(Offset(r - markerLen, b), Offset(r, b), mp);
    canvas.drawLine(Offset(r, b), Offset(r, b - markerLen), mp);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── BottomSheet: предмет найден ───────────────────────────────────────────

class _ItemFoundSheet extends StatelessWidget {
  final Item item;

  const _ItemFoundSheet({required this.item});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('d MMMM yyyy, HH:mm', 'ru').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final cat = categoryByKey(item.category);
    final location = item.location.floor.isNotEmpty
        ? '${item.location.floor} / ${item.location.room}'
        : item.location.room;
    final article = item.itemId?.isNotEmpty == true ? item.itemId! : '—';
    final hasPhoto =
        item.imagePath != null && item.imagePath!.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка шторки
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Фото предмета
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasPhoto
                  ? Image.file(
                      File(item.imagePath!),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),
            ),

            const SizedBox(height: 16),

            // Наименование
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // Поля предмета
            _SheetRow(icon: Icons.qr_code,
                label: 'Артикул', value: article),
            if (cat != null)
              _SheetRow(
                icon: Icons.category_outlined,
                label: 'Категория',
                value: '${cat.emoji}  ${cat.name}',
              ),
            _SheetRow(icon: Icons.room_outlined,
                label: 'Помещение', value: location),
            _SheetRow(
              icon: Icons.inventory_2_outlined,
              label: 'Количество',
              value: '${item.quantity ?? 0} шт.',
              valueColor: _kRed,
              valueBold: true,
            ),

            const Divider(height: 24),

            // Дата создания
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Добавлен: ${_formatDate(item.createdAt)}',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Кнопка закрытия
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 48, color: Colors.grey),
          SizedBox(height: 6),
          Text('Фото не добавлено',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Строка поля в BottomSheet ─────────────────────────────────────────────

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    valueBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── BottomSheet: предмет не найден ────────────────────────────────────────

class _ItemNotFoundSheet extends StatelessWidget {
  const _ItemNotFoundSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка шторки
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Иконка ошибки
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner,
                  size: 32, color: _kRed),
            ),

            const SizedBox(height: 16),

            const Text(
              '❌ Предмет не найден',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'QR-код не существует в базе данных',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Возможные причины
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F0F0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _kRed.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Возможные причины:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kRed),
                  ),
                  SizedBox(height: 6),
                  _BulletText('QR-код повреждён'),
                  _BulletText('Предмет был удалён'),
                  _BulletText('Это чужой QR-код'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text(
                  'Закрыть',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Пункт-маркер списка ───────────────────────────────────────────────────

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Text('•  ',
              style: TextStyle(color: _kRed, fontSize: 13)),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

// ── Экран: нет разрешения на камеру ──────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionDeniedView({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera_outlined,
                    size: 40, color: _kRed),
              ),
              const SizedBox(height: 20),
              const Text(
                'Нет доступа к камере',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Разрешите доступ к камере\nв настройках телефона',
                style: TextStyle(fontSize: 15, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Открыть настройки'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Экран: другая ошибка камеры ───────────────────────────────────────────

class _CameraErrorView extends StatelessWidget {
  final String? message;

  const _CameraErrorView({this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Не удалось запустить камеру',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
