import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

/// Экран первого запуска — создание аккаунта администратора.
/// Показывается только если в базе нет ни одного пользователя.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _passVisible = false;
  bool _pass2Visible = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await AuthService.instance.createUser(
      login: _loginCtrl.text.trim(),
      password: _passCtrl.text,
      resetCode: _codeCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      isAdmin: true,
    );

    // Сразу входим под созданным администратором
    await AuthService.instance.login(_loginCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/main_screen', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                SvgPicture.asset('assets/QR_layout/label.svg', width: 220),
                const SizedBox(height: 16),
                const Text('Добро пожаловать!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Создайте аккаунт администратора',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: hintColor)),
                const SizedBox(height: 32),

                // Имя
                _buildField(
                  controller: _nameCtrl,
                  label: 'ФИО',
                  hint: 'Иванов Иван Иванович',
                  icon: Icons.person_outline,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 16),

                // Компания
                _buildField(
                  controller: _companyCtrl,
                  label: 'Компания',
                  hint: 'ООО «Компания»',
                  icon: Icons.business_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
                ),
                const SizedBox(height: 16),

                // Логин
                _buildField(
                  controller: _loginCtrl,
                  label: 'Логин',
                  hint: 'admin',
                  icon: Icons.alternate_email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                    if (v.trim().length < 3) return 'Минимум 3 символа';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Пароль
                _buildPasswordField(
                  controller: _passCtrl,
                  label: 'Пароль',
                  visible: _passVisible,
                  onToggle: () => setState(() => _passVisible = !_passVisible),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Обязательное поле';
                    if (v.length < 4) return 'Минимум 4 символа';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Повторите пароль
                _buildPasswordField(
                  controller: _pass2Ctrl,
                  label: 'Повторите пароль',
                  visible: _pass2Visible,
                  onToggle: () => setState(() => _pass2Visible = !_pass2Visible),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Обязательное поле';
                    if (v != _passCtrl.text) return 'Пароли не совпадают';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Код сброса
                _buildField(
                  controller: _codeCtrl,
                  label: 'Код сброса',
                  hint: 'Секретное слово (мин. 6 символов)',
                  icon: Icons.key_outlined,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                    if (v.trim().length < 6) return 'Минимум 6 символов';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Сохраните код сброса надёжно — он нужен для восстановления пароля',
                        style: TextStyle(fontSize: 12, color: hintColor),
                      ),
                    ),
                  ],

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
                      : const Text('Создать'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: hintColor),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
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
