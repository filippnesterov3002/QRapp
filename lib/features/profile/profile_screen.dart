import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService.instance;
  final _picker = ImagePicker();

  Future<void> _pickPhoto() async {
    final user = _auth.currentUser;
    final hasPhoto = user?.imagePath != null && user!.imagePath!.isNotEmpty;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Color(0xFFA80000)),
              title: const Text('Сделать фото'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFA80000)),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Удалить фото'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'delete') {
      await _auth.updateProfile(clearImage: true);
      if (mounted) setState(() {});
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    await _auth.updateProfile(imagePath: picked.path);
    if (mounted) setState(() {});
  }

  Future<void> _editField({
    required String title,
    required String current,
    required String hint,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: current);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await onSave(controller.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    const kRed = Color(0xFFA80000);
    const kDark = Color(0xFF8B0000);

    final user = _auth.currentUser;
    final avatarPath = user?.imagePath ?? '';
    final name = user?.name ?? '';
    final position = user?.position ?? '';
    final company = user?.company ?? '';
    final login = user?.login ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset('assets/back_button.svg',
                width: 85, height: 43),
          ),
        ),
        title: const Text('Профиль',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Аватар
            CircleAvatar(
              radius: 54,
              backgroundColor: Colors.white,
              backgroundImage: avatarPath.isNotEmpty
                  ? FileImage(File(avatarPath))
                  : null,
              child: avatarPath.isEmpty
                  ? SvgPicture.asset(
                      'assets/icons/profile/avatar.svg',
                      height: 72, width: 72)
                  : null,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.photo_camera, size: 16, color: kRed),
              label: const Text('Изменить фото',
                  style: TextStyle(color: kRed, fontSize: 13)),
            ),

            const SizedBox(height: 20),

            // Карточка редактируемых полей
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _EditRow(
                    label: 'ФИО',
                    value: name,
                    placeholder: 'Не указано',
                    topRadius: true,
                    onTap: () => _editField(
                      title: 'ФИО',
                      current: name,
                      hint: 'Иванов Иван Иванович',
                      onSave: (v) => _auth.updateProfile(name: v),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _EditRow(
                    label: 'Должность',
                    value: position,
                    placeholder: 'Не указана',
                    onTap: () => _editField(
                      title: 'Должность',
                      current: position,
                      hint: 'Инженер, бухгалтер...',
                      onSave: (v) => _auth.updateProfile(position: v),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _EditRow(
                    label: 'Организация',
                    value: company,
                    placeholder: 'Не указана',
                    onTap: () => _editField(
                      title: 'Организация',
                      current: company,
                      hint: 'ООО «Компания»',
                      onSave: (v) => _auth.updateProfile(company: v),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _ReadRow(
                    label: 'Логин',
                    value: '@$login',
                    bottomRadius: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Переключение темы
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ValueListenableBuilder(
                valueListenable:
                    Hive.box('settings').listenable(keys: ['isDarkMode']),
                builder: (context, box, _) {
                  final isDark =
                      box.get('isDarkMode', defaultValue: false) as bool;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                        color: kRed),
                    title: Text(isDark ? 'Тёмная тема' : 'Светлая тема',
                        style: const TextStyle(fontSize: 16)),
                    trailing: Switch(
                      value: isDark,
                      activeColor: kRed,
                      onChanged: (v) async {
                        await Hive.box('settings').put('isDarkMode', v);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Сменить пароль
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: const Icon(Icons.lock_outline, color: kRed),
                title: const Text('Сменить пароль',
                    style: TextStyle(fontSize: 16)),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () => Navigator.pushNamed(context, '/change_password'),
              ),
            ),

            const SizedBox(height: 32),

            // Кнопка выхода
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('ВЫЙТИ',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  final String label;
  final String value;
  final String placeholder;
  final bool topRadius;
  final VoidCallback onTap;

  const _EditRow({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.topRadius = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: topRadius
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 16, color: Colors.grey)),
            ),
            Expanded(
              child: Text(
                value.isNotEmpty ? value : placeholder,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: value.isNotEmpty
                      ? Colors.black
                      : Colors.grey.shade400,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bottomRadius;

  const _ReadRow({
    required this.label,
    required this.value,
    this.bottomRadius = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
