import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

/// Экран смены пароля (доступен из профиля для авторизованного пользователя).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _new2Ctrl = TextEditingController();

  bool _currentVisible = false;
  bool _newVisible = false;
  bool _new2Visible = false;
  bool _loading = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _new2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final ok = await AuthService.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
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
          content: Text('Неверный текущий пароль'),
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
        title: const Text('Смена пароля'),
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
              // Текущий пароль
              _PasswordField(
                controller: _currentCtrl,
                label: 'Текущий пароль',
                visible: _currentVisible,
                onToggle: () =>
                    setState(() => _currentVisible = !_currentVisible),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Обязательное поле'
                    : null,
              ),
              const SizedBox(height: 16),

              // Новый пароль
              _PasswordField(
                controller: _newCtrl,
                label: 'Новый пароль',
                visible: _newVisible,
                onToggle: () =>
                    setState(() => _newVisible = !_newVisible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v.length < 4) return 'Минимум 4 символа';
                  if (v == _currentCtrl.text) {
                    return 'Новый пароль должен отличаться от текущего';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Повторите новый пароль
              _PasswordField(
                controller: _new2Ctrl,
                label: 'Повторите новый пароль',
                visible: _new2Visible,
                onToggle: () =>
                    setState(() => _new2Visible = !_new2Visible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v != _newCtrl.text) return 'Пароли не совпадают';
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
                    : const Text('Сохранить'),
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
