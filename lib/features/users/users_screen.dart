import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';

/// Экран управления пользователями. Доступен только администратору.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _auth = AuthService.instance;

  // ── Диалог добавления пользователя ────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final loginCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool passVisible = false;
    bool pass2Visible = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => _FormSheet(
          title: 'Новый пользователь',
          formKey: formKey,
          onSave: () async {
            if (!formKey.currentState!.validate()) return;
            await _auth.createUser(
              name: nameCtrl.text.trim(),
              login: loginCtrl.text.trim(),
              password: passCtrl.text,
              resetCode: codeCtrl.text.trim(),
              company: '',
              isAdmin: false,
            );
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Column(
            children: [
              _FormField(controller: nameCtrl, label: 'ФИО', icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null),
              const SizedBox(height: 14),
              _FormField(controller: loginCtrl, label: 'Логин', icon: Icons.alternate_email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                    if (v.trim().length < 3) return 'Минимум 3 символа';
                    if (_auth.isLoginTaken(v.trim())) return 'Логин уже занят';
                    return null;
                  }),
              const SizedBox(height: 14),
              _PasswordFormField(
                controller: passCtrl, label: 'Пароль',
                visible: passVisible,
                onToggle: () => setLocalState(() => passVisible = !passVisible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v.length < 4) return 'Минимум 4 символа';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _PasswordFormField(
                controller: pass2Ctrl, label: 'Повторите пароль',
                visible: pass2Visible,
                onToggle: () => setLocalState(() => pass2Visible = !pass2Visible),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Обязательное поле';
                  if (v != passCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: codeCtrl, label: 'Код сброса', icon: Icons.key_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Обязательное поле';
                  if (v.trim().length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Диалог редактирования пользователя ────────────────────────────────────

  Future<void> _showEditDialog(User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final passCtrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool passVisible = false;
    bool pass2Visible = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => _FormSheet(
          title: 'Редактировать: @${user.login}',
          formKey: formKey,
          onSave: () async {
            if (!formKey.currentState!.validate()) return;
            final newPass = passCtrl.text.isNotEmpty ? passCtrl.text : null;
            final newCode = codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null;
            await _auth.updateUser(
              user,
              name: nameCtrl.text.trim(),
              newPassword: newPass,
              newResetCode: newCode,
            );
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Column(
            children: [
              _FormField(controller: nameCtrl, label: 'ФИО', icon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null),
              const SizedBox(height: 14),
              _PasswordFormField(
                controller: passCtrl,
                label: 'Новый пароль (оставьте пустым чтобы не менять)',
                visible: passVisible,
                onToggle: () => setLocalState(() => passVisible = !passVisible),
                validator: (v) {
                  if (v == null || v.isEmpty) return null; // не обязательно
                  if (v.length < 4) return 'Минимум 4 символа';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _PasswordFormField(
                controller: pass2Ctrl,
                label: 'Повторите новый пароль',
                visible: pass2Visible,
                onToggle: () => setLocalState(() => pass2Visible = !pass2Visible),
                validator: (v) {
                  if (passCtrl.text.isEmpty) return null;
                  if (v != passCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _FormField(
                controller: codeCtrl,
                label: 'Новый код сброса (оставьте пустым чтобы не менять)',
                icon: Icons.key_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (v.trim().length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Удаление пользователя ─────────────────────────────────────────────────

  Future<void> _confirmDelete(User user) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && user.userId == currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить себя')),
      );
      return;
    }
    if (user.isAdmin && _auth.adminCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить последнего администратора')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text('Удалить «${user.name}» (@${user.login})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _auth.deleteUser(user);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Пользователи'),
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(
              'assets/back_button.svg',
              width: 85, height: 43,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Добавить пользователя',
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<User>>(
        valueListenable: Hive.box<User>('users_box').listenable(),
        builder: (context, box, _) {
          final users = box.values.toList();
          if (users.isEmpty) {
            return const Center(child: Text('Нет пользователей'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) => _UserCard(
              user: users[i],
              isCurrent: users[i].userId == _auth.currentUser?.userId,
              onEdit: () => _showEditDialog(users[i]),
              onDelete: () => _confirmDelete(users[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Карточка пользователя ─────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final User user;
  final bool isCurrent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.isCurrent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final avatarPath = user.imagePath;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isCurrent
            ? Border.all(color: primaryColor, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFF0E0E0),
            backgroundImage: (avatarPath != null && avatarPath.isNotEmpty)
                ? FileImage(File(avatarPath))
                : null,
            child: (avatarPath == null || avatarPath.isEmpty)
                ? const Icon(Icons.person, color: primaryColor, size: 26)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.isNotEmpty ? user.name : '—',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Вы',
                            style: TextStyle(
                                fontSize: 11, color: primaryColor)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.login}  •  ${user.isAdmin ? 'Администратор' : 'Сотрудник'}',
                  style:
                      const TextStyle(fontSize: 12, color: hintColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: primaryColor,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: Colors.red,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Обёртка bottom sheet с формой ────────────────────────────────────────────

class _FormSheet extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final Widget child;
  final Future<void> Function() onSave;

  const _FormSheet({
    required this.title,
    required this.formKey,
    required this.child,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              child,
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onSave,
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Поле формы ───────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: hintColor),
      ),
      validator: validator,
    );
  }
}

// ── Поле пароля ──────────────────────────────────────────────────────────────

class _PasswordFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordFormField({
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
