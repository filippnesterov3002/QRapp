import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../models/changelog.dart';
import '../../services/changelog_service.dart';

const _kRed = Color(0xFFA80000);

class GlobalHistoryScreen extends StatefulWidget {
  const GlobalHistoryScreen({super.key});

  @override
  State<GlobalHistoryScreen> createState() => _GlobalHistoryScreenState();
}

class _GlobalHistoryScreenState extends State<GlobalHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _typeFilter;
  String? _sourceFilter;

  static const _typeOptions = <(String?, String)>[
    (null, 'Все'),
    ('created', 'Создан'),
    ('updated', 'Изменён'),
    ('deleted', 'Удалён'),
    ('imported', 'Импортирован'),
    ('conflict', 'Конфликт'),
  ];

  static const _sourceOptions = <(String?, String)>[
    (null, 'Все'),
    ('manual', 'Вручную'),
    ('import_json', 'JSON'),
    ('import_excel', 'Excel'),
    ('import_axioma', 'Аксиома'),
    ('import_wifi', 'Wi-Fi'),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ChangeLog> _filtered(List<ChangeLog> all) {
    return all.where((log) {
      if (_typeFilter != null && log.changeType != _typeFilter) return false;
      if (_sourceFilter != null && log.source != _sourceFilter) return false;
      if (_search.isEmpty) return true;
      return log.itemName.toLowerCase().contains(_search) ||
          log.userName.toLowerCase().contains(_search) ||
          (log.changedField?.toLowerCase().contains(_search) ?? false) ||
          (log.oldValue?.toLowerCase().contains(_search) ?? false) ||
          (log.newValue?.toLowerCase().contains(_search) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filtered(ChangeLogService.getAllHistory());

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
        title: const Text('Журнал изменений',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Поиск по предмету или пользователю',
                hintStyle:
                    const TextStyle(fontSize: 14, color: Colors.grey),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: Colors.grey),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.grey),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                fillColor: Colors.white,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          _FilterRow(
            options: _typeOptions,
            selected: _typeFilter,
            onSelected: (v) => setState(() => _typeFilter = v),
          ),
          _FilterRow(
            options: _sourceOptions,
            selected: _sourceFilter,
            onSelected: (v) => setState(() => _sourceFilter = v),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Нет записей',
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _LogCard(log: logs[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip row ────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<(String?, String)> options;
  final String? selected;
  final void Function(String?) onSelected;

  const _FilterRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final (value, label) = options[i];
          final isSelected = selected == value;
          return FilterChip(
            label: Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                )),
            selected: isSelected,
            onSelected: (_) => onSelected(value),
            selectedColor: _kRed,
            backgroundColor: Colors.white,
            checkmarkColor: Colors.white,
            showCheckmark: false,
            side: BorderSide(
                color: isSelected ? _kRed : Colors.grey.shade300),
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

// ── Log card ───────────────────────────────────────────────────────────────

class _LogCard extends StatelessWidget {
  final ChangeLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final (icon, color, typeLabel) = _typeInfo(log.changeType);
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
                // Top row: item name + date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.itemName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 4),
                // Type badge + source badge
                Row(
                  children: [
                    _Badge(label: typeLabel, color: color),
                    const SizedBox(width: 6),
                    _Badge(
                      label: _sourceLabel(log.source),
                      color: Colors.grey,
                    ),
                  ],
                ),
                // Field change
                if (log.changedField != null) ...[
                  const SizedBox(height: 5),
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
                              decoration:
                                  TextDecoration.lineThrough),
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
                // User
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(log.userName,
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

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
