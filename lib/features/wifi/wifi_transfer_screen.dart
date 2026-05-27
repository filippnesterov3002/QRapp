import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'wifi_server.dart';

const _kRed = Color(0xFFA80000);

class WifiTransferScreen extends StatefulWidget {
  const WifiTransferScreen({super.key});

  @override
  State<WifiTransferScreen> createState() => _WifiTransferScreenState();
}

class _WifiTransferScreenState extends State<WifiTransferScreen>
    with WidgetsBindingObserver {
  WifiServer? _server;
  bool _isStarting = false;
  String? _ip;
  int? _port;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server?.stop();
    super.dispose();
  }

  // Останавливаем сервер при сворачивании приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stopServer();
  }

  Future<void> _startServer() async {
    // На iOS при первом запуске система покажет запрос на доступ к локальной сети
    if (Platform.isIOS) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Доступ к локальной сети'),
          content: const Text(
            'При первом запуске iOS запросит разрешение на доступ '
            'к локальной сети.\n\n'
            'Нажмите «Разрешить» в системном диалоге, чтобы '
            'WiFi сервер мог принимать подключения с компьютера.',
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
              child: const Text('Продолжить'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isStarting = true);

    // Получить IP адрес WiFi интерфейса
    try {
      _ip = await NetworkInfo().getWifiIP();
    } catch (_) {
      _ip = null;
    }

    final server = WifiServer(
      onLog: (msg) {
        if (mounted) setState(() => _logs.insert(0, msg));
      },
    );

    final port = await server.start();

    if (!mounted) return;

    if (port == null) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось запустить сервер')),
      );
      return;
    }

    setState(() {
      _server = server;
      _port = port;
      _isStarting = false;
    });
  }

  Future<void> _stopServer() async {
    await _server?.stop();
    if (mounted) {
      setState(() {
        _server = null;
        _port = null;
      });
    }
  }

  String get _cleanUrl => 'http://${_ip ?? '...'}:${_port ?? 8080}';

  @override
  Widget build(BuildContext context) {
    final isRunning = _server?.isRunning ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _kRed,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('📡 WiFi передача',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/back_button.svg',
              width: 85,
              height: 43,
              colorFilter: const ColorFilter.mode(
                  Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isRunning) _buildStopped(),
            if (isRunning) _buildRunning(),
            const SizedBox(height: 16),
            if (_logs.isNotEmpty) _buildLog(),
          ],
        ),
      ),
    );
  }

  // ── Карточка когда сервер НЕ запущен ─────────────────────────────────────

  Widget _buildStopped() {
    return _Card(
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Сервер не запущен',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Убедитесь что телефон и компьютер\nподключены к одной WiFi сети',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label:
                  Text(_isStarting ? 'Запуск...' : '▶  Запустить сервер'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isStarting ? null : _startServer,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Карточка когда сервер ЗАПУЩЕН ────────────────────────────────────────

  Widget _buildRunning() {
    return _Card(
      child: Column(
        children: [
          // Статус «работает»
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Сервер работает',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),

          // Адрес сервера
          const Text('Откройте браузер и введите:',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              _cleanUrl,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _kRed,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Скопировать адрес'),
            style: TextButton.styleFrom(foregroundColor: _kRed),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _cleanUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Адрес скопирован'),
                    duration: Duration(seconds: 2)),
              );
            },
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // QR-код
          const Text('Или отсканируйте QR-код:',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: QrImageView(
              data: _cleanUrl,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 24),

          // Кнопка остановить
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.stop_rounded),
              label: const Text('⏹  Остановить сервер'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kRed,
                side: const BorderSide(color: _kRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _stopServer,
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Лог запросов ─────────────────────────────────────────────────────────

  Widget _buildLog() {
    final visible = _logs.take(10).toList();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ЖУРНАЛ ЗАПРОСОВ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(visible.length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              visible[i],
              style: TextStyle(
                fontSize: 13,
                color: i == 0 ? Colors.black87 : Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ── Вспомогательный виджет карточки ──────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
