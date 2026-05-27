import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/inventory_session.dart';
import 'report_detail_screen.dart';

const _kRed = Color(0xFFA80000);

/// Экран истории инвентаризаций с календарём
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late List<InventorySession> _sessions;

  // Форматтер времени HH:mm (не требует инициализации локали)
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
    _loadSessions();
  }

  /// Загружает все сессии из Hive
  void _loadSessions() {
    final box = Hive.box<InventorySession>('sessions');
    _sessions = box.values.toList();
  }

  /// Возвращает сессии за конкретный день
  List<InventorySession> _sessionsForDay(DateTime day) => _sessions
      .where((s) =>
          s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day)
      .toList();

  /// Русское короткое название дня: "15 апреля"
  String _dayLabel(DateTime d) {
    const months = [
      '',
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
    ];
    return '${d.day} ${months[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedSessions = _sessionsForDay(_selectedDay);

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
          'История отчётов',
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // ── Календарь ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TableCalendar<InventorySession>(
              firstDay: DateTime(2020),
              lastDay: DateTime(2035),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() => _focusedDay = focused);
              },
              // eventLoader позволяет table_calendar знать, какие дни имеют события
              eventLoader: _sessionsForDay,
              calendarFormat: CalendarFormat.month,
              // Отключаем кнопку переключения формата (только месяц)
              availableCalendarFormats: const {CalendarFormat.month: 'Месяц'},
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: _kRed, size: 22),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: _kRed, size: 22),
                titleTextStyle: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
                headerPadding:
                    EdgeInsets.symmetric(vertical: 8),
              ),
              calendarStyle: CalendarStyle(
                // Выбранный день — красный круг
                selectedDecoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.white),
                // Сегодняшний день — прозрачный красный
                todayDecoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                    color: _kRed, fontWeight: FontWeight.w600),
                // Синяя точка под днями с событиями
                markerDecoration: const BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                markerSize: 5.5,
                markerMargin:
                    const EdgeInsets.symmetric(horizontal: 1.5),
                markersMaxCount: 1,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle:
                    TextStyle(color: Colors.grey, fontSize: 12),
                weekendStyle:
                    TextStyle(color: _kRed, fontSize: 12),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Заголовок списка ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  _dayLabel(_selectedDay),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                if (selectedSessions.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedSessions.length}',
                      style: const TextStyle(
                          color: _kRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Список сессий или заглушка ──────────────────────────────────
          Expanded(
            child: selectedSessions.isEmpty
                ? const Center(
                    child: Text(
                      '📋 В этот день инвентаризаций не было',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: selectedSessions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) => _SessionCard(
                      session: selectedSessions[i],
                      timeFmt: _timeFmt,
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportDetailScreen(
                                session: selectedSessions[i]),
                          ),
                        ).then((_) => setState(_loadSessions));
                      },
                    ),
                  ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Карточка одной сессии ──────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final InventorySession session;
  final DateFormat timeFmt;
  final VoidCallback onOpen;

  const _SessionCard({
    required this.session,
    required this.timeFmt,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final time = timeFmt.format(session.date);
    final found =
        session.results.where((r) => r.status == 'found').length;
    final wrongRoom =
        session.results.where((r) => r.status == 'wrong_room').length;
    final missing =
        session.results.where((r) => r.status == 'missing').length;

    // Помещения через запятую, не более 2 строк
    final roomsLabel = session.rooms.isEmpty
        ? '—'
        : session.rooms.join(', ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Время + статус бейдж
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                time,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: session.status == 'completed'
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status == 'completed'
                      ? 'Завершена'
                      : 'В процессе',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: session.status == 'completed'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Помещения
          Text(
            roomsLabel,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 10),

          // Статистика + кнопка
          Row(
            children: [
              _StatBadge('✅', found, const Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              _StatBadge('⚠️', wrongRoom, const Color(0xFFE65100)),
              const SizedBox(width: 10),
              _StatBadge('❌', missing, Colors.red),
              const Spacer(),
              TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  backgroundColor: _kRed.withValues(alpha: 0.08),
                  foregroundColor: _kRed,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Открыть отчёт',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Бейдж статистики ───────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String icon;
  final int count;
  final Color color;

  const _StatBadge(this.icon, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
