import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';
import 'inventory_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, required this.controller});
  final SmartStockController controller;
  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final totalValue = controller.categorySummaries.fold<double>(
      0,
      (value, category) => value + category.value,
    );
    return ListView(
      key: const PageStorageKey('reports-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Inventory report',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final columns =
                (box.maxWidth /
                        (320 * MediaQuery.textScalerOf(context).scale(1)))
                    .floor()
                    .clamp(1, 3);
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final pair in [
                  (
                    'Units in stock',
                    NumberFormat.decimalPattern().format(
                      controller.kpis.totalQuantity,
                    ),
                  ),
                  ('Low-stock items', '${controller.kpis.lowStockCount}'),
                  ('Inventory value', money.format(controller.kpis.totalValue)),
                ])
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(pair.$1),
                            Text(
                              pair.$2,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => showLowStockItems(context, controller),
          icon: const Icon(Icons.warning_amber_outlined),
          label: const Text('Review low stock'),
        ),
        const SizedBox(height: 24),
        Text(
          'Value by category',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (controller.categorySummaries.isEmpty)
          const EmptyMessage(
            title: 'No inventory data',
            message:
                'Add inventory items to see stock totals and category values.',
          ),
        for (final category in controller.categorySummaries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  category.category,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Text('${category.quantity} units'),
                    Text(money.format(category.value)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalValue > 0
                      ? (category.value / totalValue).clamp(0, 1)
                      : 0,
                  minHeight: 8,
                  semanticsLabel:
                      '${category.category} share of inventory value',
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Import and export',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Choose a folder or provider when saving. Scheduled exports contain inventory reports.',
        ),
        const SizedBox(height: 12),
        Wrap(
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
            TaskButton(
              label: 'Import Inventory CSV/XLSX',
              icon: Icons.upload_file,
              action: () async {
                await controller.importInventory();
                return null;
              },
            ),
            TaskButton(
              label: 'Export PDF Report',
              icon: Icons.picture_as_pdf_outlined,
              savedFile: true,
              action: controller.exportInventoryPdf,
            ),
            TaskButton(
              label: 'Export Report XLSX',
              icon: Icons.download,
              savedFile: true,
              action: controller.exportInventoryXlsx,
            ),
            OutlinedButton.icon(
              onPressed: () => showSchedulerDialog(context, controller),
              icon: const Icon(Icons.schedule),
              label: const Text('Schedule inventory reports'),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
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
