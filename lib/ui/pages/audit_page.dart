import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  late String _item = widget.controller.auditFilter.itemName ?? '';
  late String? _type = widget.controller.auditFilter.changeType;
  late DateTime _from = widget.controller.auditFilter.dateFrom;
  late DateTime _to = widget.controller.auditFilter.dateTo;

  bool _busy = false;
  bool _filtersOpen = false;
  String? _error;
  int _filterRevision = 0;

  static const _types = [
    'CREATE',
    'RESTOCK',
    'DISPENSE',
    'MANUAL_EDIT',
    'CSV_IMPORT',
    'DELETE',
    'ROLLBACK_REVERSAL',
  ];

  bool get _pending {
    final filter = widget.controller.auditFilter;
    return _item.trim() != (filter.itemName ?? '') ||
        _type != filter.changeType ||
        formatAuditDate(_from) != formatAuditDate(filter.dateFrom) ||
        formatAuditDate(_to) != formatAuditDate(filter.dateTo);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    if (_from.isAfter(_to)) {
      setState(() => _error = 'From date must be on or before To date.');
      return;
    }
    if (_item.trim().isNotEmpty &&
        !widget.controller.auditItemNames.contains(_item.trim())) {
      setState(() {
        _error =
            'Choose an existing item name, or clear the item field for all items.';
      });
      return;
    }
    await _run(
      () => widget.controller.setAuditFilter(
        AuditFilter(
          itemName: _item.trim().isEmpty ? null : _item.trim(),
          changeType: _type,
          dateFrom: _from,
          dateTo: _to,
        ),
      ),
    );
  }

  Future<void> _date(bool from) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null && mounted) {
      setState(() {
        if (from) {
          _from = value;
        } else {
          _to = value;
        }
      });
    }
  }

  Future<void> _reverse(LedgerEntry entry) async {
    if (_busy || entry.changeType == 'DELETE' || entry.deltaQuantity == 0) {
      return;
    }
    final confirmed = await showSmartConfirm(
      context,
      title: 'Reverse stock change',
      confirmLabel: 'Reverse change',
      destructive: false,
      message:
          'Apply ${-entry.deltaQuantity} units to ${entry.itemName}? '
          'A new stock reversal is recorded in the Audit Log. '
          'The original entry stays in history.',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      widget.controller.selectLedgerEntry(entry);
      await widget.controller.rollbackSelectedLedger();
      widget.controller.selectLedgerEntry(null);
    });
  }

  Future<void> _openDetails(LedgerEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AuditDetailsPage(
          controller: widget.controller,
          entry: entry,
          busy: _busy,
          onReverse: () => _reverse(entry),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final entries = controller.auditPage.entries;
    final filter = controller.auditFilter;

    return CustomScrollView(
      key: const PageStorageKey('audit-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AuditHeader(total: controller.auditPage.total),
                const SizedBox(height: 14),
                _FilterSummary(filter: filter),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _filtersOpen = !_filtersOpen),
                      icon: Icon(
                        _filtersOpen
                            ? Icons.tune
                            : Icons.tune_outlined,
                      ),
                      label: const Text('Filter history'),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_pending && !_busy
                          ? () => showAuditExportOptions(context, controller)
                          : null,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export'),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_pending && !_busy
                          ? () => showAuditSchedulerDialog(context, controller)
                          : null,
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('Schedule'),
                    ),
                  ],
                ),
                if (_filtersOpen) ...[
                  const SizedBox(height: 12),
                  _AuditFilterCard(
                    busy: _busy,
                    item: _item,
                    type: _type,
                    from: _from,
                    to: _to,
                    revision: _filterRevision,
                    itemNames: controller.auditItemNames,
                    types: _types,
                    onItemChanged: (value) => setState(() => _item = value),
                    onItemSelected: (value) => setState(() => _item = value),
                    onTypeChanged: (value) => setState(() => _type = value),
                    onFrom: () => _date(true),
                    onTo: () => _date(false),
                    onApply: _apply,
                    onReset: () => _run(() async {
                      await controller.clearAuditFilters();
                      if (!mounted) return;
                      setState(() {
                        _item = '';
                        _type = null;
                        _from = controller.auditFilter.dateFrom;
                        _to = controller.auditFilter.dateTo;
                        _filterRevision++;
                      });
                    }),
                  ),
                ],
                if (_pending) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Filters changed. Apply them before exporting.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading audit history',
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  EmptyMessage(
                    title: 'Could not complete request',
                    message: _error!,
                    action: TextButton(
                      onPressed: () => _run(controller.refreshAudit),
                      child: const Text('Retry refresh'),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                PageControls(
                  label:
                      'Page ${controller.auditPageIndex + 1} '
                      'of ${controller.auditTotalPages} · '
                      '${controller.auditPage.total} entries',
                  previous: !_busy && controller.auditPageIndex > 0
                      ? () => _run(controller.auditPrev)
                      : null,
                  next: !_busy &&
                          controller.auditPageIndex + 1 < controller.auditTotalPages
                      ? () => _run(controller.auditNext)
                      : null,
                ),
                if (entries.isEmpty && !_busy)
                  const EmptyMessage(
                    title: 'No matching history',
                    message:
                        'Try a wider date range or another item or change type.',
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LedgerCard(
                  entry: entry,
                  selected: false,
                  onTap: () => _openDetails(entry),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverToBoxAdapter(
            child: PageControls(
              label:
                  'Page ${controller.auditPageIndex + 1} '
                  'of ${controller.auditTotalPages} · '
                  '${controller.auditPage.total} entries',
              previous: !_busy && controller.auditPageIndex > 0
                  ? () => _run(controller.auditPrev)
                  : null,
              next: !_busy &&
                      controller.auditPageIndex + 1 < controller.auditTotalPages
                  ? () => _run(controller.auditNext)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditHeader extends StatelessWidget {
  const _AuditHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Audit Log', style: theme.textTheme.headlineSmall),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  child: Text(
                    '$total events',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.history_rounded,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.filter});

  final AuditFilter filter;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.date_range_outlined,
            label:
                '${formatAuditDate(filter.dateFrom)} – ${formatAuditDate(filter.dateTo)}',
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.inventory_2_outlined,
            label: filter.itemName ?? 'All items',
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.swap_vert,
            label: filter.changeType == null
                ? 'All changes'
                : changeLabel(filter.changeType!),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _AuditFilterCard extends StatelessWidget {
  const _AuditFilterCard({
    required this.busy,
    required this.item,
    required this.type,
    required this.from,
    required this.to,
    required this.revision,
    required this.itemNames,
    required this.types,
    required this.onItemChanged,
    required this.onItemSelected,
    required this.onTypeChanged,
    required this.onFrom,
    required this.onTo,
    required this.onApply,
    required this.onReset,
  });

  final bool busy;
  final String item;
  final String? type;
  final DateTime from;
  final DateTime to;
  final int revision;
  final List<String> itemNames;
  final List<String> types;
  final ValueChanged<String> onItemChanged;
  final ValueChanged<String> onItemSelected;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filter history',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            key: ValueKey('audit-autocomplete-$revision'),
            initialValue: TextEditingValue(text: item),
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              return itemNames.where(
                (name) => query.isEmpty || name.toLowerCase().contains(query),
              );
            },
            onSelected: onItemSelected,
            fieldViewBuilder: (
              context,
              textController,
              focusNode,
              onFieldSubmitted,
            ) => TextField(
              controller: textController,
              focusNode: focusNode,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Item name (blank for all)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onItemChanged,
              onSubmitted: (_) => onFieldSubmitted(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: type,
            key: ValueKey('audit-type-$revision'),
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Change type'),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All changes'),
              ),
              ...types.map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(changeLabel(value)),
                ),
              ),
            ],
            onChanged: busy ? null : onTypeChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onFrom,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('From: ${formatAuditDate(from)}'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onTo,
                icon: const Icon(Icons.event_outlined),
                label: Text('To: ${formatAuditDate(to)}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onApply,
                icon: const Icon(Icons.filter_alt_outlined),
                label: const Text('Apply filters'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _AuditDetailsPage extends StatelessWidget {
  const _AuditDetailsPage({
    required this.controller,
    required this.entry,
    required this.busy,
    required this.onReverse,
  });

  final SmartStockController controller;
  final LedgerEntry entry;
  final bool busy;
  final Future<void> Function() onReverse;

  bool get _canReverse =>
      entry.changeType != 'DELETE' && entry.deltaQuantity != 0;

  Future<void> _viewItem(BuildContext context) async {
    if (entry.sku.isEmpty || entry.sku == '—') return;
    await controller.setInventorySearch(entry.sku);
    controller.goTo(AppSection.inventory);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final positive = entry.deltaQuantity > 0;
    final changeColor = entry.deltaQuantity == 0
        ? scheme.onSurfaceVariant
        : positive
        ? Colors.green.shade700
        : scheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Details')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  scheme.surface,
                                  changeColor,
                                  .10,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Text(
                                  changeLabel(entry.changeType).toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: changeColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '#AUD-${entry.ledgerId}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${entry.changeText} units',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.timestamp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Affected Inventory Item',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.itemName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AuditDetailRow(
                          icon: Icons.qr_code_2,
                          label: 'SKU',
                          value: displaySku(entry.sku),
                        ),
                        _AuditDetailRow(
                          icon: Icons.payments_outlined,
                          label: 'Unit price snapshot',
                          value: '₱${entry.priceSnapshot.toStringAsFixed(2)}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 19,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Inventory Transition',
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _AuditMetric(
                                label: 'BEFORE',
                                value: entry.beforeText,
                                semantics: 'Before: ${entry.beforeText}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AuditMetric(
                                label: 'CHANGE',
                                value: entry.changeText,
                                color: changeColor,
                                semantics: 'Change: ${entry.changeText}',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _AuditMetric(
                                label: 'AFTER',
                                value: entry.afterText,
                                semantics: 'After: ${entry.afterText}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Keep these exact strings for accessibility and legacy UI tests.
                        ExcludeSemantics(
                          child: Wrap(
                            spacing: 12,
                            children: [
                              Text(
                                'Before: ${entry.beforeText}',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                'After: ${entry.afterText}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Transaction Context',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (entry.notes.trim().isEmpty)
                          Text(
                            'No note was recorded for this transaction.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Text('Note: ${entry.notes}'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        _AuditDetailRow(
                          icon: Icons.tag,
                          label: 'Reference ID',
                          value: 'AUD-${entry.ledgerId}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (entry.sku.isNotEmpty && entry.sku != '—')
                  FilledButton.icon(
                    onPressed: () => _viewItem(context),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('View Item in Inventory'),
                  ),
                if (_canReverse) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            await onReverse();
                            if (context.mounted) Navigator.pop(context);
                          },
                    icon: const Icon(Icons.undo),
                    label: const Text('Reverse stock change'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditMetric extends StatelessWidget {
  const _AuditMetric({
    required this.label,
    required this.value,
    required this.semantics,
    this.color,
  });

  final String label;
  final String value;
  final String semantics;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semantics,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditDetailRow extends StatelessWidget {
  const _AuditDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
