import 'package:hive/hive.dart';
import '../models/changelog.dart';
import '../models/items.dart';
import 'auth_service.dart';

class ChangeLogService {
  static const _maxLogsPerItem = 50;

  static Box<ChangeLog> get _box => Hive.box<ChangeLog>('changelog_box');

  static String get _userId => AuthService.instance.currentUser?.userId ?? '';

  static String get _userName {
    final u = AuthService.instance.currentUser;
    if (u == null) return 'Неизвестный';
    return u.name.isNotEmpty ? u.name : u.login;
  }

  static String _genId() => 'log_${DateTime.now().microsecondsSinceEpoch}';

  static String _id(Item item) => item.itemId ?? 'item_${item.id}';

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> logCreated(Item item, {String source = 'manual'}) async {
    await _box.add(ChangeLog(
      logId: _genId(),
      itemId: _id(item),
      itemName: item.name,
      userId: _userId,
      userName: _userName,
      changeType: 'created',
      source: source,
      changedAt: DateTime.now(),
    ));
    await _trim(_id(item));
  }

  static Future<void> logUpdated(
    Item oldItem,
    Item newItem, {
    String source = 'manual',
  }) async {
    final id = _id(newItem);
    final now = DateTime.now();
    final changes = _diff(oldItem, newItem);
    if (changes.isEmpty) return;
    for (final c in changes) {
      await _box.add(ChangeLog(
        logId: _genId(),
        itemId: id,
        itemName: newItem.name,
        userId: _userId,
        userName: _userName,
        changeType: 'updated',
        changedField: c.field,
        oldValue: c.oldVal,
        newValue: c.newVal,
        source: source,
        changedAt: now,
      ));
    }
    await _trim(id);
  }

  static Future<void> logDeleted(Item item, {String source = 'manual'}) async {
    await _box.add(ChangeLog(
      logId: _genId(),
      itemId: _id(item),
      itemName: item.name,
      userId: _userId,
      userName: _userName,
      changeType: 'deleted',
      source: source,
      changedAt: DateTime.now(),
    ));
  }

  static Future<void> logImported(Item item, {required String source}) async {
    await _box.add(ChangeLog(
      logId: _genId(),
      itemId: _id(item),
      itemName: item.name,
      userId: _userId,
      userName: _userName,
      changeType: 'imported',
      source: source,
      changedAt: DateTime.now(),
    ));
    await _trim(_id(item));
  }

  static Future<void> logConflict(
    Item oldItem,
    Item newItem, {
    required String source,
  }) async {
    final id = _id(newItem);
    final now = DateTime.now();
    final changes = _diff(oldItem, newItem);
    if (changes.isEmpty) {
      await _box.add(ChangeLog(
        logId: _genId(),
        itemId: id,
        itemName: newItem.name,
        userId: _userId,
        userName: _userName,
        changeType: 'conflict',
        source: source,
        changedAt: now,
      ));
    } else {
      for (final c in changes) {
        await _box.add(ChangeLog(
          logId: _genId(),
          itemId: id,
          itemName: newItem.name,
          userId: _userId,
          userName: _userName,
          changeType: 'conflict',
          changedField: c.field,
          oldValue: c.oldVal,
          newValue: c.newVal,
          source: source,
          changedAt: now,
        ));
      }
    }
    await _trim(id);
  }

  static List<ChangeLog> getItemHistory(String itemId) =>
      _box.values.where((log) => log.itemId == itemId).toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));

  static List<ChangeLog> getAllHistory() =>
      _box.values.toList()..sort((a, b) => b.changedAt.compareTo(a.changedAt));

  // ── Private helpers ────────────────────────────────────────────────────────

  static List<_Diff> _diff(Item a, Item b) {
    return [
      if (a.name != b.name) _Diff('Наименование', a.name, b.name),
      if (a.location.room != b.location.room)
        _Diff('Помещение', a.location.room, b.location.room),
      if ((a.quantity ?? 0) != (b.quantity ?? 0))
        _Diff('Количество', '${a.quantity ?? 0}', '${b.quantity ?? 0}'),
      if (a.description != b.description)
        _Diff('Описание', a.description, b.description),
      if ((a.responsiblePerson ?? '') != (b.responsiblePerson ?? ''))
        _Diff('Ответственный', a.responsiblePerson ?? '—',
            b.responsiblePerson ?? '—'),
      if ((a.inventoryNumber ?? '') != (b.inventoryNumber ?? ''))
        _Diff('Инв. номер', a.inventoryNumber ?? '—', b.inventoryNumber ?? '—'),
      if ((a.imagePath ?? '') != (b.imagePath ?? ''))
        _Diff(
          'Фото',
          (a.imagePath?.isNotEmpty == true) ? 'есть' : 'нет',
          (b.imagePath?.isNotEmpty == true) ? 'есть' : 'нет',
        ),
      if ((a.qrCodeData ?? '') != (b.qrCodeData ?? ''))
        _Diff(
          'QR-код',
          (a.qrCodeData?.isNotEmpty == true) ? 'создан' : 'нет',
          (b.qrCodeData?.isNotEmpty == true) ? 'создан' : 'нет',
        ),
    ];
  }

  static Future<void> _trim(String itemId) async {
    final logs = _box.values.where((l) => l.itemId == itemId).toList()
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    if (logs.length > _maxLogsPerItem) {
      for (final log in logs.sublist(_maxLogsPerItem)) {
        await log.delete();
      }
    }
  }
}

class _Diff {
  final String field;
  final String oldVal;
  final String newVal;
  const _Diff(this.field, this.oldVal, this.newVal);
}
