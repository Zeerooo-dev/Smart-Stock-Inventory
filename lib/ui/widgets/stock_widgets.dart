import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/models.dart';

String stockLabel(InventoryItem item) => item.quantity == 0
    ? 'Out of stock'
    : item.isLowStock
    ? 'Low stock'
    : 'In stock';
String changeLabel(String type) => switch (type) {
  'DELETE' => 'Deleted',
  'CREATE' => 'Created',
  'MANUAL_EDIT' => 'Item edited',
  'CSV_IMPORT' => 'Inventory import',
  'RESTOCK' => 'Restock',
  'DISPENSE' => 'Dispense',
  'ROLLBACK_REVERSAL' => 'Stock reversal',
  _ => type,
};
String displaySku(String sku) =>
    sku == '—' || sku.isEmpty ? 'SKU unavailable' : sku;

class StockStatus extends StatelessWidget {
  const StockStatus({super.key, required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) {
    final color = item.quantity == 0
        ? Theme.of(context).colorScheme.error
        : item.isLowStock
        ? StockColors.of(context).warning
        : StockColors.of(context).healthy;
    return Text(
      stockLabel(item),
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class TaskButton extends StatefulWidget {
  const TaskButton({
    super.key,
    required this.label,
    required this.action,
    this.icon = Icons.check,
    this.primary = false,
    this.enabled = true,
    this.savedFile = false,
  });
  final String label;
  final Future<Object?> Function() action;
  final IconData icon;
  final bool primary, enabled, savedFile;
  @override
  State<TaskButton> createState() => _TaskButtonState();
}

class _TaskButtonState extends State<TaskButton> {
  bool _busy = false;
  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.action();
      if (!mounted) return;
      setState(() => _busy = false);
      if (widget.savedFile) {
        if (result is Uri) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('File saved'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find this file in the folder or provider you chose.',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(result.toString()),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Save cancelled.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text('Could not ${widget.label.toLowerCase()}'),
            content: SelectableText('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon);
    final text = Text(_busy ? '${widget.label}…' : widget.label);
    return widget.primary
        ? FilledButton.icon(
            onPressed: widget.enabled && !_busy ? _run : null,
            icon: icon,
            label: text,
          )
        : OutlinedButton.icon(
            onPressed: widget.enabled && !_busy ? _run : null,
            icon: icon,
            label: text,
          );
  }
}

class PageControls extends StatelessWidget {
  const PageControls({
    super.key,
    required this.label,
    this.previous,
    this.next,
  });
  final String label;
  final VoidCallback? previous, next;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(label),
        IconButton.outlined(
          tooltip: 'Previous page',
          onPressed: previous,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton.outlined(
          tooltip: 'Next page',
          onPressed: next,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.entry,
    this.onTap,
    this.selected = false,
    this.showIdentity = true,
  });
  final LedgerEntry entry;
  final VoidCallback? onTap;
  final bool selected, showIdentity;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deltaColor = entry.deltaQuantity < 0
        ? scheme.error
        : entry.deltaQuantity > 0
        ? StockColors.of(context).healthy
        : scheme.onSurface;
    return Card(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLowest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showIdentity) ...[
                Text(
                  entry.itemName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(displaySku(entry.sku)),
                const SizedBox(height: 12),
              ],
              Text(
                changeLabel(entry.changeType),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('Before: ${entry.beforeText}'),
                  Text(
                    'Change: ${entry.changeText}',
                    style: TextStyle(
                      color: deltaColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('After: ${entry.afterText}'),
                ],
              ),
              const SizedBox(height: 8),
              Text('Unit price: ₱${entry.priceSnapshot.toStringAsFixed(2)}'),
              if (entry.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText('Note: ${entry.notes}'),
                ),
              const SizedBox(height: 8),
              Text(
                '${entry.timestamp} UTC',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  const EmptyMessage({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
