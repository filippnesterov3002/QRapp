import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

/// Экран сброса пароля через код сброса.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _passVisible = false;
  bool _pass2Visible = false;
  bool _loading = false;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final ok = await AuthService.instance.resetPassword(
      login: _loginCtrl.text.trim(),
      resetCode: _codeCtrl.text.trim(),
      newPassword: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Пароль успешно изменён'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Неверный логин или код сброса'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Сброс пароля'),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset('assets/back_button.svg',
                width: 85, height: 43),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Логин
              TextFormField(
                controller: _loginCtrl,
                decoration: const InputDecoration(
                  labelText: 'Логин',
                  prefixIcon:
                      Icon(Icons.person_outline, color: hintColor),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Обязательное поле'
                    : null,
              ),
              const SizedBox(height: 16),

              // Код сброса
              TextFormField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Код сброса',
                  prefixIcon: Icon(Icons.key_outlined, color: hintColor),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Обязательное поле'
                    : null,
              ),
              const SizedBox(height: 16),

              // Новый пароль
              _PasswordField(
                controller: _passCtrl,
                label: 'Новый пароль',
                visible: _passVisible,
                onToggle: () =>
                    setState(() => _passVisible = !_passVisible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v.length < 4) return 'Минимум 4 символа';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Повторите пароль
              _PasswordField(
                controller: _pass2Ctrl,
                label: 'Повторите пароль',
                visible: _pass2Visible,
                onToggle: () =>
                    setState(() => _pass2Visible = !_pass2Visible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v != _passCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Сбросить пароль'),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: hintColor),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
              color: hintColor),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
