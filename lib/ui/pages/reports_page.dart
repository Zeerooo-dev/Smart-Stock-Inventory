import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';
import 'inventory_page.dart';
import 'import_export_pages.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final decimal = NumberFormat.decimalPattern();
    final totalValue = controller.categorySummaries.fold<double>(
      0,
      (value, category) => value + category.value,
    );
    final lowStock = [...controller.lowStockThreats]
      ..sort((a, b) => a.ratio.compareTo(b.ratio));

    return ListView(
      key: const PageStorageKey('reports-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _ReportsHeader(
          onExport: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExportInventoryPage(controller: controller),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ReportMetricGrid(
          totalUnits: decimal.format(controller.kpis.totalQuantity),
          inventoryValue: money.format(controller.kpis.totalValue),
          lowStockCount: controller.kpis.lowStockCount,
          categoryCount: controller.categorySummaries.length,
        ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Inventory Distribution',
          subtitle: 'Current stock value by category',
        ),
        const SizedBox(height: 10),
        _CategoryDistributionCard(
          categories: controller.categorySummaries,
          totalValue: totalValue,
          money: money,
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          title: 'Needs Attention',
          subtitle: controller.kpis.lowStockCount == 0
              ? 'No items are currently below their reorder threshold'
              : '${controller.kpis.lowStockCount} item(s) below reorder threshold',
          actionLabel: controller.kpis.lowStockCount == 0 ? null : 'View all',
          onAction: controller.kpis.lowStockCount == 0
              ? null
              : () => showLowStockItems(context, controller),
        ),
        const SizedBox(height: 10),
        if (lowStock.isEmpty)
          const _ReportEmptyCard(
            icon: Icons.check_circle_outline,
            title: 'Stock levels look healthy',
            message: 'No tracked item currently needs a low-stock review.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < lowStock.take(4).length; i++) ...[
                    _LowStockReportRow(threat: lowStock[i]),
                    if (i != lowStock.take(4).length - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const _SectionTitle(
          title: 'Import & Export',
          subtitle: 'Refresh totals, import inventory, or export the current data',
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TaskButton(
                  label: 'Refresh report',
                  icon: Icons.refresh,
                  action: () async {
                    await controller.refreshReports();
                    return null;
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImportInventoryPage(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExportInventoryPage(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showSchedulerDialog(context, controller),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Schedule reports'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reports', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                'Inventory performance & value',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export'),
        ),
      ],
    );
  }
}

class _ReportMetricGrid extends StatelessWidget {
  const _ReportMetricGrid({
    required this.totalUnits,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.categoryCount,
  });

  final String totalUnits;
  final String inventoryValue;
  final int lowStockCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 720 ? 4 : 2;
      final itemWidth = (width - ((columns - 1) * 10)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: itemWidth,
            child: _MetricCard(
              label: 'Total Units',
              value: totalUnits,
              icon: Icons.inventory_2_outlined,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _MetricCard(
              label: 'Inventory Value',
              value: inventoryValue,
              icon: Icons.payments_outlined,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _MetricCard(
              label: 'Low Stock Alerts',
              value: '$lowStockCount',
              icon: Icons.warning_amber_rounded,
              warning: lowStockCount > 0,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _MetricCard(
              label: 'Categories',
              value: '$categoryCount',
              icon: Icons.category_outlined,
            ),
          ),
        ],
      );
    },
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = warning
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(icon, size: 18, color: accent),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: warning ? accent : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _CategoryDistributionCard extends StatelessWidget {
  const _CategoryDistributionCard({
    required this.categories,
    required this.totalValue,
    required this.money,
  });

  final List<CategorySummary> categories;
  final double totalValue;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _ReportEmptyCard(
        icon: Icons.bar_chart_outlined,
        title: 'No inventory data',
        message: 'Add inventory items to see category values and stock distribution.',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var index = 0; index < categories.length; index++) ...[
              _CategoryDistributionRow(
                category: categories[index],
                totalValue: totalValue,
                money: money,
              ),
              if (index != categories.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryDistributionRow extends StatelessWidget {
  const _CategoryDistributionRow({
    required this.category,
    required this.totalValue,
    required this.money,
  });

  final CategorySummary category;
  final double totalValue;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = totalValue <= 0
        ? 0.0
        : (category.value / totalValue).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                category.category,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              money.format(category.value),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${category.quantity} units',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            semanticsLabel: '${category.category} share of inventory value',
          ),
        ),
      ],
    );
  }
}

class _LowStockReportRow extends StatelessWidget {
  const _LowStockReportRow({required this.threat});

  final LowStockThreat threat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depleted = threat.quantity <= 0;
    final color = depleted ? theme.colorScheme.error : const Color(0xFFD97706);
    final progress = threat.reorderLevel <= 0
        ? 0.0
        : (threat.quantity / threat.reorderLevel).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Color.lerp(theme.colorScheme.surface, color, .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                depleted ? Icons.error_outline : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  threat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${threat.quantity} remaining · Min ${threat.reorderLevel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            depleted ? 'OUT' : 'LOW',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportEmptyCard extends StatelessWidget {
  const _ReportEmptyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showLowStockItems(
  BuildContext context,
  SmartStockController controller,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => _LowStockPage(controller: controller)),
);

class _LowStockPage extends StatefulWidget {
  const _LowStockPage({required this.controller});

  final SmartStockController controller;

  @override
  State<_LowStockPage> createState() => _LowStockPageState();
}

class _LowStockPageState extends State<_LowStockPage> {
  late Future<List<InventoryItem>> _future = _load();

  Future<List<InventoryItem>> _load() async {
    final items = (await widget.controller.database.getAllInventory())
        .where((item) => item.isLowStock)
        .toList();
    items.sort(
      (a, b) =>
          (a.quantity / a.reorderLevel).compareTo(b.quantity / b.reorderLevel),
    );
    return items;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Low stock')),
    body: SafeArea(
      child: FutureBuilder<List<InventoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EmptyMessage(
                  title: 'Could not load low stock',
                  message: '${snapshot.error}',
                  action: TextButton(
                    onPressed: () => setState(() => _future = _load()),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                EmptyMessage(
                  title: 'No low-stock items',
                  message: 'Every item is at or above its reorder threshold.',
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InventoryRow(
                      item: item,
                      onTap: () => showItemDetailsDialog(
                        context,
                        item,
                        controller: widget.controller,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        await adjustItemStock(
                          context,
                          widget.controller,
                          item,
                          restock: true,
                        );
                        if (mounted) setState(() => _future = _load());
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Restock ${item.name}'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}
