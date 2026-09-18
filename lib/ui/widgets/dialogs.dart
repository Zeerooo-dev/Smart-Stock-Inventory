import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/smartstock_controller.dart';

Future<bool> showSmartConfirm(
  BuildContext context, {
  required String message,
  String title = 'Confirm Action',
  String confirmLabel = 'OK',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
      title: Row(
        children: [
          Icon(
            destructive ? Icons.warning_amber_rounded : Icons.help_outline,
            color: destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close), tooltip: 'Close'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: destructive ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(destructive ? Icons.delete_outline : Icons.info_outline, size: 30),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            destructive ? 'This action cannot be undone.' : 'Please confirm to continue.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<int?> showStockAmountDialog(BuildContext context, {required bool restock}) async {
  final controller = TextEditingController(text: '1');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(restock ? 'Restock Item' : 'Dispense Item'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: restock ? 'Restock quantity' : 'Dispense quantity'),
        onSubmitted: (_) {
          final value = int.tryParse(controller.text);
          if (value != null && value > 0) Navigator.pop(context, value);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) Navigator.pop(context, value);
          },
          child: const Text('Apply'),
        ),
      ],
    ),
  );
}

Future<void> showItemHistoryDialog(
  BuildContext context,
  SmartStockController controller,
  InventoryItem item,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _ItemHistoryDialog(controller: controller, item: item),
  );
}

class _ItemHistoryDialog extends StatefulWidget {
  const _ItemHistoryDialog({required this.controller, required this.item});
  final SmartStockController controller;
  final InventoryItem item;

  @override
  State<_ItemHistoryDialog> createState() => _ItemHistoryDialogState();
}

class _ItemHistoryDialogState extends State<_ItemHistoryDialog> {
  int page = 0;
  late Future<ItemHistorySnapshot> future = _load();

  Future<ItemHistorySnapshot> _load() => widget.controller.database.getItemHistory(widget.item.id, page: page);

  void _changePage(int delta) {
    setState(() {
      page += delta;
      future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final dialogHeight = compact ? size.height - 24 : (size.height < 730 ? size.height - 36 : 680.0);

    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: compact ? size.width : 900,
        height: dialogHeight,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 20),
          child: FutureBuilder<ItemHistorySnapshot>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) return Center(child: Text('Could not load history: ${snapshot.error}'));
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!;
              final pages = (data.totalEntries / DatabaseService.historyPageSize).ceil();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(widget.item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                            Text(widget.item.sku, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, box) {
                      final columns = compact ? 2 : 4;
                      final spacing = 8.0;
                      final width = (box.maxWidth - spacing * (columns - 1)) / columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          SizedBox(width: width, child: _MiniMetric(label: 'Current stock', value: '${data.currentQuantity}')),
                          SizedBox(width: width, child: _MiniMetric(label: 'Total added', value: '+${data.totalAdded}')),
                          SizedBox(width: width, child: _MiniMetric(label: 'Total removed', value: '-${data.totalRemoved}')),
                          SizedBox(width: width, child: _MiniMetric(label: 'Entries', value: '${data.totalEntries}')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: data.entries.isEmpty
                        ? const Center(child: Text('No history entries.'))
                        : compact
                            ? _HistoryCards(entries: data.entries)
                            : _HistoryTable(entries: data.entries),
                  ),
                  const SizedBox(height: 10),
                  if (compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Page ${page + 1} of ${pages < 1 ? 1 : pages} · ${data.totalEntries} entries', textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: _exportHistory, icon: const Icon(Icons.download), label: const Text('Export CSV')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: page > 0 ? () => _changePage(-1) : null,
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('Previous'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: (page + 1) * DatabaseService.historyPageSize < data.totalEntries ? () => _changePage(1) : null,
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('Next'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text('Page ${page + 1} of ${pages < 1 ? 1 : pages} (${data.totalEntries} entries)'),
                        const Spacer(),
                        OutlinedButton.icon(onPressed: _exportHistory, icon: const Icon(Icons.download), label: const Text('Export CSV')),
                        const SizedBox(width: 8),
                        IconButton(onPressed: page > 0 ? () => _changePage(-1) : null, icon: const Icon(Icons.chevron_left)),
                        IconButton(
                          onPressed: (page + 1) * DatabaseService.historyPageSize < data.totalEntries ? () => _changePage(1) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _exportHistory() async {
    try {
      await widget.controller.exportItemHistory(widget.item);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Timestamp')),
              DataColumn(label: Text('Change Type')),
              DataColumn(label: Text('Δ Qty'), numeric: true),
              DataColumn(label: Text('Price'), numeric: true),
              DataColumn(label: Text('Running Balance'), numeric: true),
            ],
            rows: entries
                .map(
                  (entry) => DataRow(
                    cells: [
                      DataCell(Text(entry.timestamp)),
                      DataCell(Text(_friendlyType(entry.changeType))),
                      DataCell(Text('${entry.deltaQuantity >= 0 ? '+' : ''}${entry.deltaQuantity}')),
                      DataCell(Text('₱${entry.priceSnapshot.toStringAsFixed(2)}')),
                      DataCell(Text('${entry.runningBalance}')),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      );
}

class _HistoryCards extends StatelessWidget {
  const _HistoryCards({required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) => ListView.separated(
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_friendlyType(entry.changeType), style: const TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Text('${entry.deltaQuantity >= 0 ? '+' : ''}${entry.deltaQuantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(entry.timestamp, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text('Price ₱${entry.priceSnapshot.toStringAsFixed(2)}'),
                    Text('Balance ${entry.runningBalance}'),
                  ],
                ),
              ],
            ),
          );
        },
      );
}

String _friendlyType(String type) => switch (type) {
      'CREATE' => 'Created',
      'MANUAL_EDIT' => 'Manual edit',
      'CSV_IMPORT' => 'CSV import',
      'RESTOCK' => 'Restock',
      'DISPENSE' => 'Dispense',
      'ROLLBACK_REVERSAL' => 'Rollback reversal',
      _ => type,
    };

Future<void> showSchedulerDialog(BuildContext context, SmartStockController controller) async {
  var minutes = controller.schedulerIntervalMinutes;
  var format = controller.schedulerFormat;
  var directory = controller.schedulerOutputDirectory;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Scheduled Report Export'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: '$minutes',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Interval (minutes)', prefixIcon: Icon(Icons.timer_outlined)),
                  onChanged: (value) => minutes = int.tryParse(value) ?? minutes,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ScheduledFormat>(
                  initialValue: format,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Report format', prefixIcon: Icon(Icons.description_outlined)),
                  items: ScheduledFormat.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(value.label, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => format = value ?? format),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: directory,
                  key: ValueKey(directory),
                  onChanged: (value) => directory = value,
                  decoration: InputDecoration(
                    labelText: 'Output folder',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        try {
                          final picked = await controller.chooseSchedulerDirectory();
                          if (picked != null) setState(() => directory = picked);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Folder selection unavailable: $e')));
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.schedulerRunning
                        ? 'Running every ${controller.schedulerIntervalMinutes} minutes'
                        : 'Scheduler is stopped',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (controller.schedulerRunning)
            OutlinedButton(
              onPressed: () {
                controller.stopScheduler();
                Navigator.pop(context);
              },
              child: const Text('Stop'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton(
            onPressed: controller.schedulerRunning
                ? null
                : () {
                    try {
                      controller.startScheduler(minutes: minutes, format: format, directory: directory);
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
            child: const Text('Start'),
          ),
        ],
      ),
    ),
  );
}

String formatAuditDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
