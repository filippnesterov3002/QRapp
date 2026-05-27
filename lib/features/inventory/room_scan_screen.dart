import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/inventory_session.dart';
import '../../models/items.dart';

const _kRed = Color(0xFFA80000);

class RoomScanScreen extends StatefulWidget {
  final InventorySession session;
  final String room;
  final VoidCallback? onUpdated;

  const RoomScanScreen({
    super.key,
    required this.session,
    required this.room,
    this.onUpdated,
  });

  @override
  State<RoomScanScreen> createState() => _RoomScanScreenState();
}

class _RoomScanScreenState extends State<RoomScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  static const double _cameraBoxHeight = 220.0;
  static const double _scanWindowSize = 140.0;

  List<InventoryResult> get _roomResults => widget.session.results
      .where((r) => r.room == widget.room)
      .toList();

  int get _scanned =>
      _roomResults.where((r) => r.status != 'pending').length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Ищем предмет в Hive по значению QR
  Item? _findItem(String qrValue) {
    final box = Hive.box<Item>('items');
    for (final item in box.values) {
      final id = item.itemId ?? 'item_${item.id}';
      if (id == qrValue ||
          item.id.toString() == qrValue ||
          item.name == qrValue) {
        return item;
      }
    }
    return null;
  }

  // Ищем InventoryResult по itemId
  InventoryResult? _findResult(String itemId) {
    for (final r in widget.session.results) {
      if (r.itemId == itemId) return r;
    }
    return null;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null) return;

    _isProcessing = true;
    _controller.stop();

    final item = _findItem(rawValue);

    if (item == null) {
      await _showUnknownDialog(rawValue);
    } else {
      final itemId = item.itemId ?? 'item_${item.id}';
      final result = _findResult(itemId);

      if (result != null && result.status != 'pending') {
        // Уже отсканирован
        await _showAlreadyScannedDialog(result);
      } else if (item.location.room.toLowerCase() ==
          widget.room.toLowerCase()) {
        // Сценарий 1: предмет в правильном помещении
        await _showFoundSheet(item, result);
      } else {
        // Сценарий 2: предмет из другого помещения
        await _showWrongRoomSheet(item, result);
      }
    }

    _isProcessing = false;
    if (mounted) _controller.start();
  }

  /// Сценарий 1: предмет найден в правильном помещении
  Future<void> _showFoundSheet(Item item, InventoryResult? result) async {
    final expectedQty = result?.expectedQty ?? (item.quantity ?? 1);
    final qtyController =
        TextEditingController(text: expectedQty.toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF2E7D32), size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Предмет найден',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SheetInfoRow('Наименование', item.name),
            _SheetInfoRow(
                'Артикул',
                item.itemId?.isNotEmpty == true
                    ? item.itemId!
                    : '—'),
            _SheetInfoRow('Помещение', item.location.room),
            const SizedBox(height: 16),
            // Поле количества
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Фактическое количество',
                labelStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                fillColor: const Color(0xFFF5F5F5),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _kRed)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(qtyController.text.trim()) ??
                      expectedQty;
                  if (result != null) {
                    result.status = 'found';
                    result.actualQty = qty;
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('ПОДТВЕРДИТЬ',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );

    // Сохраняем сессию после закрытия шторки
    await widget.session.save();
    widget.onUpdated?.call();
    if (mounted) setState(() {});
  }

  /// Сценарий 2: предмет из другого помещения
  Future<void> _showWrongRoomSheet(
      Item item, InventoryResult? result) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE65100), size: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Не то помещение',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SheetInfoRow('Наименование', item.name),
            _SheetInfoRow('Ожидается в', item.location.room),
            _SheetInfoRow('Найден в', widget.room),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('Пропустить',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (result != null) {
                        result.status = 'wrong_room';
                        result.actualQty = result.expectedQty;
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    child: const Text('Принять сюда',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await widget.session.save();
    widget.onUpdated?.call();
    if (mounted) setState(() {});
  }

  /// Сценарий 3: QR-код не найден в базе
  Future<void> _showUnknownDialog(String rawValue) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Предмет не найден',
          style: TextStyle(
              color: _kRed, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Данный QR-код отсутствует в базе данных.',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('Код: $rawValue',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть',
                style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }

  /// Предмет уже был отсканирован
  Future<void> _showAlreadyScannedDialog(InventoryResult result) async {
    final statusLabel = result.status == 'found'
        ? 'Найден'
        : result.status == 'wrong_room'
            ? 'Не то помещение'
            : result.status;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Уже отсканирован'),
        content: Text(
            '«${result.itemName}» уже отмечен как «$statusLabel».'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Закрыть', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomResults = _roomResults;
    final scanned = _scanned;
    final total = roomResults.length;
    final progress = total > 0 ? scanned / total : 0.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final scanWindow = Rect.fromCenter(
      center: Offset(screenWidth / 2 - 24, _cameraBoxHeight / 2),
      width: _scanWindowSize,
      height: _scanWindowSize,
    );

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
          widget.room,
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Прогресс
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(_kRed),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$scanned / $total',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey),
                ),
              ],
            ),
          ),

          // Камера
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: double.infinity,
                height: _cameraBoxHeight,
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    CustomPaint(
                      size: Size(screenWidth - 32, _cameraBoxHeight),
                      painter: _ScanOverlayPainter(scanWindow),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Отсканируйте QR-код предмета',
              style: TextStyle(
                  color: _kRed, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),

          // Список ожидаемых предметов
          Expanded(
            child: total == 0
                ? const Center(
                    child: Text('Нет предметов для этого помещения',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: roomResults.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final r = roomResults[i];
                      return _ResultTile(result: r);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: Text(
              scanned == total
                  ? 'ГОТОВО'
                  : 'ЗАВЕРШИТЬ ПОМЕЩЕНИЕ ($scanned/$total)',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tile для одного результата в списке ────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final InventoryResult result;
  const _ResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final statusIcon = switch (result.status) {
      'found' => const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20),
      'wrong_room' => const Icon(Icons.warning_amber_rounded,
          color: Color(0xFFE65100), size: 20),
      'missing' => const Icon(Icons.cancel, color: Colors.red, size: 20),
      _ => const Icon(Icons.radio_button_unchecked,
          color: Colors.grey, size: 20),
    };

    final bg = switch (result.status) {
      'found' => const Color(0xFFE8F5E9),
      'wrong_room' => const Color(0xFFFFF3E0),
      'missing' => const Color(0xFFFFEBEE),
      _ => Colors.white,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          statusIcon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.itemName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            'x${result.expectedQty}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Строка информации в шторке ─────────────────────────────────────────────

class _SheetInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Оверлей камеры ─────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  _ScanOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()
        ..addRRect(RRect.fromRectAndRadius(
            scanWindow, const Radius.circular(10))),
    );
    canvas.drawPath(
      overlayPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(10)),
      Paint()
        ..color = _kRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
