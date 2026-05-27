import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Сервис для выбора и сохранения фотографии предмета.
class PhotoService {
  PhotoService._();

  static final _picker = ImagePicker();

  /// Показывает BottomSheet с выбором источника фото.
  /// Возвращает путь к сохранённому файлу, или null если пользователь отменил.
  ///
  /// [itemId] — используется как имя файла ({itemId}.jpg).
  /// [hasPhoto] — если true, в шторке появляется пункт «Удалить фото».
  static Future<String?> pickAndSave(
    BuildContext context, {
    required String itemId,
    bool hasPhoto = false,
  }) async {
    // Показываем выбор источника
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PhotoBottomSheet(hasPhoto: hasPhoto),
    );

    if (action == null || action == _PhotoAction.cancel) return null;
    if (action == _PhotoAction.delete) return ''; // Пустая строка = удалить

    // Источник камера или галерея
    final source = action == _PhotoAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return null;

    // Сохраняем в папку приложения с именем {itemId}.jpg
    final dir = await getApplicationDocumentsDirectory();
    final fileName = '${itemId.replaceAll(RegExp(r'[^\w]'), '_')}.jpg';
    final dest = File(p.join(dir.path, fileName));

    // Копируем файл из временного хранилища
    await File(picked.path).copy(dest.path);
    return dest.path;
  }
}

enum _PhotoAction { camera, gallery, delete, cancel }

/// Нижняя шторка для выбора действия с фото
class _PhotoBottomSheet extends StatelessWidget {
  final bool hasPhoto;

  const _PhotoBottomSheet({required this.hasPhoto});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: Color(0xFFA80000)),
            title: const Text('Сделать фото'),
            onTap: () => Navigator.pop(context, _PhotoAction.camera),
          ),
          ListTile(
            leading:
                const Icon(Icons.photo_library, color: Color(0xFFA80000)),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(context, _PhotoAction.gallery),
          ),
          // Удаление фото — только если оно уже есть
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить фото',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, _PhotoAction.delete),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.close, color: Colors.grey),
            title: const Text('Пропустить'),
            onTap: () => Navigator.pop(context, _PhotoAction.cancel),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
