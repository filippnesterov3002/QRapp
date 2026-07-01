import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'list_property.dart';
import '../../models/inventory_session.dart';
import '../../models/items.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../ai/chat_ui.dart';
import '../ai/inventory_agent.dart';
import '../history/global_history_screen.dart';
import '../inventory/new_inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../export/data_exchange_screen.dart';
import '../users/users_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  late final InventoryAgent _inventoryAgent;
  String _searchQuery = '';

  // Ящик Hive — открыт в main.dart, просто берём ссылку
  final Box<Item> _box = Hive.box<Item>('items');

  @override
  void initState() {
    super.initState();
    _inventoryAgent = InventoryAgent.createDefault();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inventoryAgent.dispose();
    super.dispose();
  }

  List<Item> _filtered(List<Item> all) {
    if (_searchQuery.isEmpty) return all;
    return all
        .where((item) =>
            item.name.toLowerCase().contains(_searchQuery) ||
            (item.inventoryNumber?.toLowerCase().contains(_searchQuery) ??
                false) ||
            item.location.room.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // Сохранение нового предмета в Hive
  void _onItemAdded(Item item) {
    _box.add(item);
    // ValueListenableBuilder перестроит UI автоматически
  }

  void _openAgentChat() {
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showInventoryAgentChat(context, _inventoryAgent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Builder(
              builder: (context) => IconButton(
                icon: SvgPicture.asset('assets/icons/home_p/sidebar2.svg'),
                iconSize: 60,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintStyle: const TextStyle(fontSize: 16),
                    hintText: 'Поиск',
                    prefixIcon: SvgPicture.asset(
                      'assets/icons/home_p/search.svg',
                      height: 15,
                      width: 15,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(35.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            IconButton(
              icon: SvgPicture.asset(
                'assets/icons/home_p/profile.svg',
                width: 40,
                height: 40,
              ),
              iconSize: 40,
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Шапка Drawer — обновляется при изменении профиля пользователя
            ValueListenableBuilder<Box<User>>(
              valueListenable: Hive.box<User>('users_box').listenable(),
              builder: (context, _, __) {
                final user = AuthService.instance.currentUser;
                final avatarPath = user?.imagePath ?? '';
                final name = user?.name ?? '';
                final login = user?.login ?? '';
                final isAdmin = user?.isAdmin ?? false;

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                    decoration: const BoxDecoration(color: Color(0xFF8B0000)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white24,
                          backgroundImage: avatarPath.isNotEmpty
                              ? FileImage(File(avatarPath))
                              : null,
                          child: avatarPath.isEmpty
                              ? SvgPicture.asset(
                                  'assets/icons/profile/avatar.svg',
                                  height: 36,
                                  width: 36,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white70, BlendMode.srcIn),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name.isNotEmpty ? name : 'Не указано',
                                style: TextStyle(
                                  color: name.isNotEmpty
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@$login  •  ${isAdmin ? 'Администратор' : 'Сотрудник'}',
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Пункты меню — скроллируются если нужно
            Expanded(
              child: ValueListenableBuilder<Box<User>>(
                valueListenable: Hive.box<User>('users_box').listenable(),
                builder: (context, _, __) {
                  final isAdmin =
                      AuthService.instance.currentUser?.isAdmin ?? false;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    children: [
                      _DrawerItem(
                        title: 'ИИ-агент',
                        onTap: _openAgentChat,
                      ),
                      const SizedBox(height: 12),
                      _DrawerItem(
                        title: 'Инвентаризация',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NewInventoryScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _DrawerItem(
                        title: 'История отчётов',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportsScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _DrawerItem(
                        title: 'Обмен данными',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const DataExchangeScreen()),
                          );
                        },
                      ),
                      // Управление пользователями — только для администратора
                      if (isAdmin) ...[
                        const SizedBox(height: 12),
                        _DrawerItem(
                          title: 'Пользователи',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const UsersScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _DrawerItem(
                          title: 'Журнал изменений',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const GlobalHistoryScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Блок статистики — всегда внизу Drawer
            const _DrawerStats(),
          ],
        ),
      ),
      // ValueListenableBuilder слушает изменения ящика Hive
      // и автоматически перестраивает список при добавлении/удалении
      body: ValueListenableBuilder<Box<Item>>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          final items = _filtered(box.values.toList());
          return InventoryScreen(
            items: items,
            onItemAdded: _onItemAdded,
            searchQuery: _searchQuery,
          );
        },
      ),
    );
  }
}

// ── Пункт бокового меню ───────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(title,
            style: const TextStyle(fontSize: 20, color: Colors.black)),
        onTap: onTap,
      ),
    );
  }
}

// ── Блок статистики в нижней части Drawer ────────────────────────────────

class _DrawerStats extends StatelessWidget {
  const _DrawerStats();

  @override
  Widget build(BuildContext context) {
    // Читаем данные из Hive каждый раз при построении виджета
    final itemsBox = Hive.box<Item>('items');
    final sessionsBox = Hive.box<InventorySession>('sessions');

    // Количество предметов
    final itemCount = itemsBox.length;

    // Количество уникальных помещений
    final roomCount =
        itemsBox.values.map((e) => e.location.room.trim()).toSet().length;

    // Завершённые инвентаризации
    final completedSessions =
        sessionsBox.values.where((s) => s.status == 'completed').toList();
    final sessionCount = completedSessions.length;

    // Дата последней завершённой сессии
    DateTime? lastDate;
    if (completedSessions.isNotEmpty) {
      lastDate = completedSessions
          .map((s) => s.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final lastDateStr = lastDate != null
        ? DateFormat('d MMM yyyy', 'ru').format(lastDate)
        : '—';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок раздела
              const Text(
                'Статистика',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              // Строки статистики
              _StatRow(emoji: '📦', label: 'Предметов', value: '$itemCount'),
              _StatRow(emoji: '🚪', label: 'Помещений', value: '$roomCount'),
              _StatRow(
                  emoji: '📋', label: 'Инвентаризаций', value: '$sessionCount'),
              _StatRow(emoji: '📅', label: 'Последняя', value: lastDateStr),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Строка статистики ─────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatRow({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF333333),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA80000),
            ),
          ),
        ],
      ),
    );
  }
}
