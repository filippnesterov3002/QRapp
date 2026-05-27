import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/inventory_session.dart';

const _kRed = Color(0xFFA80000);

// ── Форматирование дат ─────────────────────────────────────────────────────

/// "15 апреля 2026"
String _formatDateRu(DateTime d) {
  const months = [
    '',
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  return '${d.day} ${months[d.month]} ${d.year}';
}

// ── Экран детального отчёта ────────────────────────────────────────────────

class ReportDetailScreen extends StatefulWidget {
  final InventorySession session;

  const ReportDetailScreen({super.key, required this.session});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _exporting = false;

  // ── Агрегаты по всей сессии ──────────────────────────────────────────────

  int get _total => widget.session.results.length;
  int get _found =>
      widget.session.results.where((r) => r.status == 'found').length;
  int get _wrongRoom =>
      widget.session.results.where((r) => r.status == 'wrong_room').length;
  int get _missing =>
      widget.session.results.where((r) => r.status == 'missing').length;

  List<InventoryResult> _resultsFor(String room) =>
      widget.session.results.where((r) => r.room == room).toList();

  // ── Генерация и показ PDF ────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      // Загружаем шрифты с поддержкой кириллицы (кешируются после первой загрузки)
      final font = await PdfGoogleFonts.notoSansRegular();
      final fontBold = await PdfGoogleFonts.notoSansBold();

      final timeFmt = DateFormat('HH:mm');
      final doc = pw.Document();

      final dateStr = _formatDateRu(widget.session.date);
      final timeStr = timeFmt.format(widget.session.date);
      final roomsStr = widget.session.rooms.join(', ');

      // Вспомогательные функции для статуса
      String statusLabel(String s) => switch (s) {
            'found' => 'Найдено',
            'wrong_room' => 'Расхождение',
            'missing' => 'Не найдено',
            _ => 'Ожидание',
          };

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          margin: const pw.EdgeInsets.symmetric(
              horizontal: 36, vertical: 32),

          // Колонтитул верхний — повторяется на каждой странице
          header: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Text(
              'Отчёт инвентаризации · $dateStr $timeStr',
              style: pw.TextStyle(
                  font: font, fontSize: 8, color: PdfColors.grey600),
            ),
          ),

          // Колонтитул нижний
          footer: (ctx) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  top: pw.BorderSide(
                      color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Отчёт сформирован автоматически приложением'
                    ' для инвентаризации Интерпроком',
                    style: pw.TextStyle(
                        font: font,
                        fontSize: 7,
                        color: PdfColors.grey500),
                  ),
                ),
                pw.Text(
                  'Стр. ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: font,
                      fontSize: 7,
                      color: PdfColors.grey500),
                ),
              ],
            ),
          ),

          build: (ctx) {
            final widgets = <pw.Widget>[];

            // ── Шапка документа ──────────────────────────────────────
            widgets.add(pw.Text(
              'ОТЧЁТ ИНВЕНТАРИЗАЦИИ',
              style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 20,
                  color: const PdfColor(0.545, 0.0, 0.0)),
            ));
            widgets.add(pw.SizedBox(height: 8));
            widgets.add(pw.Text('Дата: $dateStr',
                style: pw.TextStyle(font: font, fontSize: 12)));
            widgets.add(pw.Text('Время: $timeStr',
                style: pw.TextStyle(font: font, fontSize: 12)));
            widgets.add(pw.Text('Помещения: $roomsStr',
                style: pw.TextStyle(font: font, fontSize: 12)));
            widgets.add(pw.SizedBox(height: 16));

            // ── Общая статистика ──────────────────────────────────────
            widgets.add(pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius:
                    pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Общая статистика',
                      style: pw.TextStyle(
                          font: fontBold, fontSize: 13)),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      _pdfStat('Всего', _total, font, fontBold,
                          PdfColors.grey700),
                      pw.SizedBox(width: 20),
                      _pdfStat('Совпадает', _found, font, fontBold,
                          const PdfColor(0.18, 0.49, 0.2)),
                      pw.SizedBox(width: 20),
                      _pdfStat('Расхождение', _wrongRoom, font,
                          fontBold, const PdfColor(0.9, 0.4, 0.0)),
                      pw.SizedBox(width: 20),
                      _pdfStat('Не найдено', _missing, font, fontBold,
                          const PdfColor(0.8, 0.0, 0.0)),
                    ],
                  ),
                ],
              ),
            ));
            widgets.add(pw.SizedBox(height: 22));

            // ── Таблицы по помещениям ─────────────────────────────────
            for (final room in widget.session.rooms) {
              final results = _resultsFor(room);
              if (results.isEmpty) continue;

              // Заголовок помещения
              widgets.add(pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 7),
                decoration: const pw.BoxDecoration(
                  color: PdfColor(0.545, 0.0, 0.0),
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                  room,
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.white),
                ),
              ));
              widgets.add(pw.SizedBox(height: 6));

              // Таблица предметов помещения
              widgets.add(pw.TableHelper.fromTextArray(
                headers: [
                  'Артикул',
                  'Наименование',
                  'Ожидалось',
                  'Найдено',
                  'Статус',
                ],
                data: results
                    .map((r) => [
                          r.itemId,
                          r.itemName,
                          '${r.expectedQty}',
                          r.actualQty != null
                              ? '${r.actualQty}'
                              : '—',
                          statusLabel(r.status),
                        ])
                    .toList(),
                headerStyle: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey700),
                cellStyle:
                    pw.TextStyle(font: font, fontSize: 9),
                oddRowDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey50),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FixedColumnWidth(68),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(52),
                  3: const pw.FixedColumnWidth(52),
                  4: const pw.FixedColumnWidth(72),
                },
              ));

              // Итоговая строка под таблицей помещения
              final rFound =
                  results.where((r) => r.status == 'found').length;
              final rWrong =
                  results.where((r) => r.status == 'wrong_room').length;
              final rMissing =
                  results.where((r) => r.status == 'missing').length;
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(pw.Text(
                'Итого: Совпадает $rFound  |  '
                'Расхождение $rWrong  |  Не найдено $rMissing',
                style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: PdfColors.grey600),
              ));
              widgets.add(pw.SizedBox(height: 18));
            }

            return widgets;
          },
        ),
      );

      // Открываем встроенный просмотрщик PDF
      await Printing.layoutPdf(
          onLayout: (_) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка генерации PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Виджет статистики в блоке PDF ─────────────────────────────────────
  pw.Widget _pdfStat(String label, int value, pw.Font font,
      pw.Font fontBold, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$value',
          style: pw.TextStyle(
              font: fontBold, fontSize: 18, color: color),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
              font: font, fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // ── Билд ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('HH:mm');

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
          'Отчёт инвентаризации',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Дата и время сессии
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${_formatDateRu(widget.session.date)}  '
              '${timeFmt.format(widget.session.date)}',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),

          // ── Общая статистика ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Итоговая статистика',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StatCard('Всего', _total, Colors.grey),
                    const SizedBox(width: 8),
                    _StatCard('✅ Найдено', _found,
                        const Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    _StatCard('⚠️ Расхождение', _wrongRoom,
                        const Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    _StatCard('❌ Не найдено', _missing, Colors.red),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Список по помещениям ──────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.session.rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final room = widget.session.rooms[i];
                final results = _resultsFor(room);
                final rFound =
                    results.where((r) => r.status == 'found').length;
                final rWrong =
                    results.where((r) => r.status == 'wrong_room').length;
                final rMissing =
                    results.where((r) => r.status == 'missing').length;

                final wrongItems =
                    results.where((r) => r.status == 'wrong_room').toList();
                final missingItems =
                    results.where((r) => r.status == 'missing').toList();

                // Иконка статуса помещения
                final roomIcon = rMissing > 0
                    ? (rFound == 0 ? '🔴' : '⚠️')
                    : rWrong > 0
                        ? '⚠️'
                        : '✅';

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: Row(
                      children: [
                        Text(roomIcon,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            room,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '✅ $rFound  ⚠️ $rWrong  ❌ $rMissing',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    children: [
                      // Раздел расхождений
                      if (wrongItems.isNotEmpty) ...[
                        const _SectionHeader('⚠️  Расхождения'),
                        ...wrongItems.map((r) => _WrongRoomTile(result: r)),
                      ],
                      // Раздел не найденных
                      if (missingItems.isNotEmpty) ...[
                        const _SectionHeader('❌  Не найдено'),
                        ...missingItems.map((r) => _MissingTile(result: r)),
                      ],
                      // Если всё в порядке
                      if (wrongItems.isEmpty && missingItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Text(
                            'Все предметы найдены ✅',
                            style: TextStyle(
                                color: Color(0xFF2E7D32), fontSize: 13),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),

      // ── Кнопка экспорта закреплена внизу ──────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf, size: 20),
            label: Text(
              _exporting ? 'Генерация PDF...' : 'ЭКСПОРТ В PDF',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Вспомогательные виджеты ────────────────────────────────────────────────

/// Карточка числа в блоке общей статистики
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Заголовок раздела внутри ExpansionTile
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFF5F5F5),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// Строка предмета с расхождением (wrong_room)
class _WrongRoomTile extends StatelessWidget {
  final InventoryResult result;

  const _WrongRoomTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final actual = result.actualQty ?? result.expectedQty;
    final diff = actual - result.expectedQty;
    final diffStr = diff > 0 ? '+$diff' : '$diff';
    final diffColor = diff > 0 ? const Color(0xFF2E7D32) : Colors.red;

    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(result.itemName,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        'Ожидалось: ${result.expectedQty} / Найдено: ${result.actualQty ?? '—'}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: diff != 0
          ? Text(
              diffStr,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: diffColor),
            )
          : null,
    );
  }
}

/// Строка не найденного предмета
class _MissingTile extends StatelessWidget {
  final InventoryResult result;

  const _MissingTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      title: Text(result.itemName,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: Text(
        result.itemId,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
