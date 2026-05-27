import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../models/changelog.dart';
import '../../models/items.dart';
import '../../services/changelog_service.dart';

class ItemHistoryScreen extends StatelessWidget {
  final Item item;

  const ItemHistoryScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final itemId = item.itemId ?? 'item_${item.id}';
    final logs = ChangeLogService.getItemHistory(itemId);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('История изменений',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            Text(item.name,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('История пуста',
                      style:
                          TextStyle(fontSize: 15, color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LogCard(log: logs[i]),
            ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final ChangeLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _typeInfo(log.changeType);
    final dateStr =
        DateFormat('d MMM yyyy, HH:mm', 'ru').format(log.changedAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(label: label, color: color),
                    const Spacer(),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
                if (log.changedField != null) ...[
                  const SizedBox(height: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                      children: [
                        TextSpan(
                          text: '${log.changedField}: ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: log.oldValue ?? '—',
                          style: const TextStyle(
                              color: Colors.red,
                              decoration: TextDecoration.lineThrough),
                        ),
                        const TextSpan(text: ' → '),
                        TextSpan(
                          text: log.newValue ?? '—',
                          style: const TextStyle(
                              color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(log.userName,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    const Icon(Icons.source_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_sourceLabel(log.source),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color, String) _typeInfo(String type) {
    return switch (type) {
      'created' => (
          Icons.add_circle_outline,
          const Color(0xFF2E7D32),
          'Создан'
        ),
      'updated' => (
          Icons.edit_outlined,
          const Color(0xFF1565C0),
          'Изменён'
        ),
      'deleted' => (Icons.delete_outline, Colors.red, 'Удалён'),
      'imported' => (
          Icons.download_outlined,
          const Color(0xFF6A1B9A),
          'Импортирован'
        ),
      'conflict' => (
          Icons.warning_amber_outlined,
          Colors.orange,
          'Конфликт'
        ),
      _ => (Icons.circle_outlined, Colors.grey, type),
    };
  }

  static String _sourceLabel(String source) => switch (source) {
        'manual' => 'Вручную',
        'import_json' => 'JSON',
        'import_excel' => 'Excel',
        'import_axioma' => 'Аксиома',
        'import_wifi' => 'Wi-Fi',
        _ => source,
      };
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}
