import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.controller});
  final SmartStockController controller;

  void _snack(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final expanded = constraints.maxWidth >= 1100;
        final padding = expanded ? 28.0 : compact ? 12.0 : 18.0;
        final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

        return RefreshIndicator(
          onRefresh: controller.refreshReports,
          child: ListView(
            padding: EdgeInsets.all(padding),
            children: [
              Text('Inventory Analytics', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Live stock metrics, category balances, and operational risk signals.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, box) {
                  final columns = compact ? 1 : expanded ? 3 : 2;
                  final spacing = 12.0;
                  final cardWidth = (box.maxWidth - spacing * (columns - 1)) / columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Total Items in Stock',
                          value: NumberFormat.decimalPattern().format(controller.kpis.totalQuantity),
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Low Stock Alerts',
                          value: '${controller.kpis.lowStockCount}',
                          icon: Icons.warning_amber_rounded,
                          alert: controller.kpis.lowStockCount > 0,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _KpiCard(
                          label: 'Total Inventory Value',
                          value: currency.format(controller.kpis.totalValue),
                          icon: Icons.payments_outlined,
                          money: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (expanded)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CategoryPieCard(summaries: controller.categorySummaries, compact: false)),
                    const SizedBox(width: 16),
                    Expanded(child: _LowStockChartCard(threats: controller.lowStockThreats)),
                  ],
                )
              else ...[
                _CategoryPieCard(summaries: controller.categorySummaries, compact: compact),
                const SizedBox(height: 14),
                _LowStockChartCard(threats: controller.lowStockThreats),
              ],
              const SizedBox(height: 20),
              _CategorySummaryCard(summaries: controller.categorySummaries, compact: compact),
              const SizedBox(height: 18),
              _ExportActions(controller: controller, compact: compact, onError: (error) => _snack(context, error)),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _ExportActions extends StatelessWidget {
  const _ExportActions({required this.controller, required this.compact, required this.onError});
  final SmartStockController controller;
  final bool compact;
  final ValueChanged<Object> onError;

  Future<void> _run(Future<dynamic> Function() action) async {
    try {
      await action();
    } catch (e) {
      onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      FilledButton.icon(
        onPressed: () => _run(controller.importCsv),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import Inventory CSV'),
      ),
      OutlinedButton.icon(
        onPressed: () => _run(() async => controller.exportInventoryPdf()),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Export PDF Report'),
      ),
      FilledButton.tonalIcon(
        onPressed: () => _run(() async => controller.exportInventoryCsv()),
        icon: const Icon(Icons.download),
        label: const Text('Export Report CSV'),
      ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            buttons[i],
            if (i != buttons.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: buttons);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, required this.icon, this.alert = false, this.money = false});
  final String label;
  final String value;
  final IconData icon;
  final bool alert;
  final bool money;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueColor = alert ? scheme.error : (money ? scheme.tertiary : scheme.primary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, maxLines: 2, style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Icon(icon),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: valueColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({required this.summaries, required this.compact});
  final List<CategorySummary> summaries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final valid = summaries.where((s) => s.value > 0).toList();
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Asset Value by Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: compact ? 210 : 240,
              child: valid.isEmpty
                  ? const Center(child: Text('No data'))
                  : PieChart(
                      PieChartData(
                        centerSpaceRadius: compact ? 38 : 34,
                        sectionsSpace: 2,
                        sections: [
                          for (var i = 0; i < valid.length; i++)
                            PieChartSectionData(
                              value: valid[i].value,
                              title: compact ? '' : _short(valid[i].category, 12),
                              radius: compact ? 62 : 72,
                              color: colors[i % colors.length],
                              titleStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ThemeData.estimateBrightnessForColor(colors[i % colors.length]) == Brightness.dark ? Colors.white : Colors.black,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (compact && valid.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < valid.length; i++)
                    _LegendDot(color: colors[i % colors.length], label: valid[i].category),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _short(String value, int max) => value.length <= max ? value : '${value.substring(0, max)}…';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)),
          ],
        ),
      );
}

class _LowStockChartCard extends StatelessWidget {
  const _LowStockChartCard({required this.threats});
  final List<LowStockThreat> threats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Low Stock Threats (Top 5)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.error)),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: threats.isEmpty
                  ? const Center(child: Text('No low-stock items'))
                  : BarChart(
                      BarChartData(
                        rotationQuarterTurns: 1,
                        maxY: threats.map((e) => e.ratio).fold<double>(1, (a, b) => b > a ? b : a) * 1.2,
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 78,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= threats.length) return const SizedBox.shrink();
                                final name = threats[index].name;
                                final label = name.length > 14 ? '${name.substring(0, 14)}…' : name;
                                return SideTitleWidget(meta: meta, child: Text(label, style: const TextStyle(fontSize: 9)));
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < threats.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(toY: threats[i].ratio, color: scheme.error, width: 18, borderRadius: BorderRadius.circular(3)),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            Text('Ratio = quantity ÷ reorder threshold', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.summaries, required this.compact});
  final List<CategorySummary> summaries;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Category Balance Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (summaries.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No inventory data.')))
            else if (compact)
              ...summaries.map(
                (summary) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(summary.category, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('${NumberFormat.decimalPattern().format(summary.quantity)} units', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            currency.format(summary.value),
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Total Quantity'), numeric: true),
                    DataColumn(label: Text('Inventory Value'), numeric: true),
                  ],
                  rows: summaries
                      .map(
                        (summary) => DataRow(
                          cells: [
                            DataCell(Text(summary.category)),
                            DataCell(Text(NumberFormat.decimalPattern().format(summary.quantity))),
                            DataCell(Text(currency.format(summary.value))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
