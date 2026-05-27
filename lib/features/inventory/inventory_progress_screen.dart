import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/inventory_session.dart';
import 'room_scan_screen.dart';

const _kRed = Color(0xFFA80000);

// ── Статус помещения ───────────────────────────────────────────────────────

enum _RoomStatus { pending, inProgress, done, partial, issues }

extension _RoomStatusX on _RoomStatus {
  String get icon => switch (this) {
        _RoomStatus.pending => '🟡',
        _RoomStatus.inProgress => '🔵',
        _RoomStatus.done => '✅',
        _RoomStatus.partial => '⚠️',
        _RoomStatus.issues => '🔴',
      };

  String get label => switch (this) {
        _RoomStatus.pending => 'Не начато',
        _RoomStatus.inProgress => 'В процессе',
        _RoomStatus.done => 'Завершено',
        _RoomStatus.partial => 'Частично',
        _RoomStatus.issues => 'Есть проблемы',
      };
}

// ── Экран прогресса инвентаризации ─────────────────────────────────────────

class InventoryProgressScreen extends StatefulWidget {
  final InventorySession session;

  const InventoryProgressScreen({super.key, required this.session});

  @override
  State<InventoryProgressScreen> createState() =>
      _InventoryProgressScreenState();
}

class _InventoryProgressScreenState extends State<InventoryProgressScreen> {
  _RoomStatus _roomStatus(String room) {
    final results =
        widget.session.results.where((r) => r.room == room).toList();
    if (results.isEmpty) return _RoomStatus.pending;
    final scanned = results.where((r) => r.status != 'pending').length;
    if (scanned == 0) return _RoomStatus.pending;
    final hasIssues = results
        .any((r) => r.status == 'wrong_room' || r.status == 'missing');
    if (scanned == results.length) {
      return hasIssues ? _RoomStatus.issues : _RoomStatus.done;
    }
    return hasIssues ? _RoomStatus.partial : _RoomStatus.inProgress;
  }

  int _completedRooms() => widget.session.rooms
      .where((r) {
        final s = _roomStatus(r);
        return s == _RoomStatus.done || s == _RoomStatus.issues;
      })
      .length;

  Future<void> _finish() async {
    final done = _completedRooms();
    final total = widget.session.rooms.length;

    bool confirmed = true;
    if (done < total) {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Завершить инвентаризацию?'),
              content: Text(
                'Проверено $done из $total помещений.\n'
                'Непроверенные позиции будут помечены как «Не найдено».',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Отмена',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kRed,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Завершить'),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmed || !mounted) return;

    // Помечаем все оставшиеся 'pending' как 'missing'
    for (final result in widget.session.results) {
      if (result.status == 'pending') {
        result.status = 'missing';
      }
    }
    widget.session.status = 'completed';
    await widget.session.save();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InventoryReportScreen(session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = _completedRooms();
    final total = widget.session.rooms.length;
    final progress = total > 0 ? done / total : 0.0;

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
        title: const Text(
          'Инвентаризация',
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Карточка прогресса
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Прогресс',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(
                      '$done / $total помещений',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_kRed),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Список помещений
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.session.rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final room = widget.session.rooms[i];
                final status = _roomStatus(room);
                final roomResults = widget.session.results
                    .where((r) => r.room == room)
                    .toList();
                final scanned = roomResults
                    .where((r) => r.status != 'pending')
                    .length;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoomScanScreen(
                            session: widget.session,
                            room: room,
                            onUpdated: () => setState(() {}),
                          ),
                        ),
                      );
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Text(status.icon,
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$scanned / ${roomResults.length} позиций · ${status.label}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text(
              'ЗАВЕРШИТЬ ИНВЕНТАРИЗАЦИЮ',
              style: TextStyle(
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

// ── Экран отчёта ───────────────────────────────────────────────────────────

class InventoryReportScreen extends StatelessWidget {
  final InventorySession session;

  const InventoryReportScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final total = session.results.length;
    final found =
        session.results.where((r) => r.status == 'found').length;
    final missing =
        session.results.where((r) => r.status == 'missing').length;
    final wrongRoom =
        session.results.where((r) => r.status == 'wrong_room').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Отчёт инвентаризации',
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Дата и ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.sessionId,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(session.date),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Итоговая статистика
            Row(
              children: [
                _StatCard(
                    label: 'Всего', value: total, color: Colors.grey),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'Найдено',
                    value: found,
                    color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                _StatCard(
                    label: 'Не найдено',
                    value: missing,
                    color: Colors.red),
              ],
            ),
            if (wrongRoom > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF9800), width: 1),
                ),
                child: Text(
                  '⚠️  $wrongRoom предмет(ов) найдено не в том помещении',
                  style: const TextStyle(
                      color: Color(0xFFE65100), fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // По помещениям
            const Text(
              'По помещениям',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),

            ...session.rooms.map((room) {
              final roomResults =
                  session.results.where((r) => r.room == room).toList();
              final roomFound =
                  roomResults.where((r) => r.status == 'found').length;
              final roomMissing =
                  roomResults.where((r) => r.status == 'missing').length;
              final roomWrong =
                  roomResults.where((r) => r.status == 'wrong_room').length;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(room,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Найдено: $roomFound  |  Не найдено: $roomMissing'
                    '${roomWrong > 0 ? '  |  Не то место: $roomWrong' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  children: roomResults.map((r) {
                    final icon = switch (r.status) {
                      'found' => const Icon(Icons.check_circle,
                          color: Color(0xFF2E7D32), size: 16),
                      'wrong_room' => const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFE65100),
                          size: 16),
                      'missing' => const Icon(Icons.cancel,
                          color: Colors.red, size: 16),
                      _ => const Icon(Icons.radio_button_unchecked,
                          color: Colors.grey, size: 16),
                    };
                    return ListTile(
                      dense: true,
                      leading: icon,
                      title: Text(r.itemName,
                          style: const TextStyle(fontSize: 13)),
                      trailing: Text(
                        'x${r.expectedQty}'
                        '${r.actualQty != null ? ' → x${r.actualQty}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/main_screen', (_) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text(
              'НА ГЛАВНЫЙ ЭКРАН',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}'
      '  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Карточка статистики ────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
