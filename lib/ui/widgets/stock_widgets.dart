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
    final scheme = Theme.of(context).colorScheme;
    final background = Color.lerp(scheme.surface, color, .09)!;
    final border = Color.lerp(scheme.surface, color, .24)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          stockLabel(item).toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: .35,
          ),
        ),
      ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final healthy = StockColors.of(context).healthy;
    final warning = StockColors.of(context).warning;
    final actionColor = switch (entry.changeType) {
      'RESTOCK' => healthy,
      'DISPENSE' => scheme.primary,
      'DELETE' => scheme.error,
      'CREATE' => const Color(0xFF2563EB),
      'MANUAL_EDIT' => const Color(0xFF64748B),
      'CSV_IMPORT' => healthy,
      'ROLLBACK_REVERSAL' => warning,
      _ => scheme.primary,
    };
    final actionIcon = switch (entry.changeType) {
      'RESTOCK' => Icons.add_circle_outline,
      'DISPENSE' => Icons.remove_circle_outline,
      'DELETE' => Icons.warning_amber_rounded,
      'CREATE' => Icons.note_add_outlined,
      'MANUAL_EDIT' => Icons.edit_note_outlined,
      'CSV_IMPORT' => Icons.upload_file_outlined,
      'ROLLBACK_REVERSAL' => Icons.undo,
      _ => Icons.history,
    };
    final deltaColor = entry.deltaQuantity < 0
        ? scheme.error
        : entry.deltaQuantity > 0
        ? healthy
        : scheme.onSurface;

    return Card(
      color: selected ? scheme.primaryContainer : scheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(scheme.surface, actionColor, .10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(actionIcon, size: 18, color: actionColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showIdentity) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                entry.itemName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _LedgerActionPill(
                                label: changeLabel(entry.changeType),
                                color: actionColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displaySku(entry.sku),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ] else
                          _LedgerActionPill(
                            label: changeLabel(entry.changeType),
                            color: actionColor,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 14),
              _LedgerQuantityStrip(entry: entry, deltaColor: deltaColor),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    'Unit price: ₱${entry.priceSnapshot.toStringAsFixed(2)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${entry.timestamp} UTC',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: SelectableText('Note: ${entry.notes}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerActionPill extends StatelessWidget {
  const _LedgerActionPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(scheme.surface, color, .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: .25,
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


class _LedgerQuantityStrip extends StatelessWidget {
  const _LedgerQuantityStrip({required this.entry, required this.deltaColor});

  final LedgerEntry entry;
  final Color deltaColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(child: _value(context, 'BEFORE', entry.beforeText)),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: _value(
                context,
                'CHANGE',
                entry.changeText,
                valueColor: deltaColor,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(child: _value(context, 'AFTER', entry.afterText)),
          ],
        ),
      ),
    );
  }

  Widget _value(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final title = label[0] + label.substring(1).toLowerCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: .45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$title: $value',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
