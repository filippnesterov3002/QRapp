import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

/// Экран входа. После 5 неверных попыток блокирует ввод на 60 секунд.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;

  // Защита от брутфорса
  int _failCount = 0;
  DateTime? _lockUntil;
  Timer? _lockTimer;
  int _lockSecondsLeft = 0;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  bool get _isLocked =>
      _lockUntil != null && DateTime.now().isBefore(_lockUntil!);

  void _startLockCountdown() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = _lockUntil!.difference(DateTime.now()).inSeconds;
      if (left <= 0) {
        t.cancel();
        setState(() {
          _lockUntil = null;
          _lockSecondsLeft = 0;
          _failCount = 0;
        });
      } else {
        setState(() => _lockSecondsLeft = left);
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_isLocked) return;
    final login = _loginCtrl.text.trim();
    final pass = _passCtrl.text;
    if (login.isEmpty || pass.isEmpty) return;

    setState(() => _loading = true);
    final ok = await AuthService.instance.login(login, pass);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.pushNamedAndRemoveUntil(context, '/main_screen', (r) => false);
    } else {
      _failCount++;
      if (_failCount >= 5) {
        _lockUntil = DateTime.now().add(const Duration(seconds: 60));
        _lockSecondsLeft = 60;
        _startLockCountdown();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_failCount >= 5
              ? 'Слишком много попыток. Подождите $_lockSecondsLeft секунд.'
              : 'Неверный логин или пароль'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              SvgPicture.asset('assets/QR_layout/label.svg', width: 220),
              const Spacer(flex: 1),

              // Логин
              TextField(
                controller: _loginCtrl,
                enabled: !_isLocked,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  hintText: 'Логин',
                  prefixIcon: Icon(Icons.person_outline, color: hintColor),
                ),
              ),
              const SizedBox(height: 16),

              // Пароль
              TextField(
                controller: _passCtrl,
                enabled: !_isLocked,
                obscureText: !_passVisible,
                decoration: InputDecoration(
                  hintText: 'Пароль',
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: hintColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: hintColor,
                    ),
                    onPressed: () =>
                        setState(() => _passVisible = !_passVisible),
                  ),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 8),

              // Сообщение о блокировке
              if (_isLocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Слишком много попыток. Подождите $_lockSecondsLeft с.',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 24),

              // Войти
              ElevatedButton(
                onPressed: (_loading || _isLocked) ? null : _handleLogin,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Войти'),
              ),
              const SizedBox(height: 12),

              // Забыли пароль
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/reset_password'),
                child: const Text('Забыли пароль?',
                    style: TextStyle(color: hintColor)),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
