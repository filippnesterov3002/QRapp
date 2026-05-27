import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../models/inventory_session.dart';
import '../../models/items.dart';
import 'inventory_progress_screen.dart';

const _kRed = Color(0xFFA80000);

class NewInventoryScreen extends StatefulWidget {
  const NewInventoryScreen({super.key});

  @override
  State<NewInventoryScreen> createState() => _NewInventoryScreenState();
}

class _NewInventoryScreenState extends State<NewInventoryScreen> {
  String _search = '';
  final Set<String> _selectedRooms = {};
  late final List<_RoomInfo> _allRooms;

  @override
  void initState() {
    super.initState();
    _allRooms = _buildRoomList();
    // По умолчанию выбираем все помещения
    _selectedRooms.addAll(_allRooms.map((r) => r.room));
  }

  List<_RoomInfo> _buildRoomList() {
    final box = Hive.box<Item>('items');
    final map = <String, int>{};
    for (final item in box.values) {
      final room = item.location.room;
      if (room.isNotEmpty) {
        map[room] = (map[room] ?? 0) + 1;
      }
    }
    return map.entries
        .map((e) => _RoomInfo(room: e.key, itemCount: e.value))
        .toList()
      ..sort((a, b) => a.room.compareTo(b.room));
  }

  List<_RoomInfo> get _filtered {
    if (_search.isEmpty) return _allRooms;
    return _allRooms
        .where(
            (r) => r.room.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  Future<void> _start() async {
    if (_selectedRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одно помещение')),
      );
      return;
    }

    final itemsBox = Hive.box<Item>('items');
    final sessionsBox = Hive.box<InventorySession>('sessions');

    // Создаём результаты для всех предметов в выбранных помещениях
    final results = <InventoryResult>[];
    for (final item in itemsBox.values) {
      if (_selectedRooms.contains(item.location.room)) {
        results.add(InventoryResult(
          itemId: item.itemId ?? 'item_${item.id}',
          itemName: item.name,
          room: item.location.room,
          expectedQty: item.quantity ?? 1,
          status: 'pending',
        ));
      }
    }

    final session = InventorySession(
      sessionId: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      rooms: _selectedRooms.toList(),
      results: results,
      status: 'in_progress',
    );

    await sessionsBox.add(session);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => InventoryProgressScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final allSelected = _allRooms.isNotEmpty &&
        _selectedRooms.length == _allRooms.length;

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
          'Новая инвентаризация',
          style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (allSelected) {
                  _selectedRooms.clear();
                } else {
                  _selectedRooms.addAll(_allRooms.map((r) => r.room));
                }
              });
            },
            child: Text(
              allSelected ? 'Сбросить' : 'Все',
              style: const TextStyle(color: _kRed),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Поиск помещения...',
                prefixIcon:
                    const Icon(Icons.search, color: Colors.grey),
                fillColor: Colors.white,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_allRooms.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Нет предметов в базе',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final room = filtered[i];
                  final selected = _selectedRooms.contains(room.room);
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedRooms.remove(room.room);
                          } else {
                            _selectedRooms.add(room.room);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _kRed.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.meeting_room_outlined,
                                  color: _kRed, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.room,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${room.itemCount} позиций',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedRooms.add(room.room);
                                  } else {
                                    _selectedRooms.remove(room.room);
                                  }
                                });
                              },
                              activeColor: _kRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
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
            onPressed: _selectedRooms.isEmpty ? null : _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: Text(
              _selectedRooms.isEmpty
                  ? 'НАЧАТЬ'
                  : 'НАЧАТЬ (${_selectedRooms.length} помещений)',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomInfo {
  final String room;
  final int itemCount;
  const _RoomInfo({required this.room, required this.itemCount});
}
