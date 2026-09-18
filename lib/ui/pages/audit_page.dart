import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key, required this.controller});
  final SmartStockController controller;

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  String? _item;
  String? _type;
  late DateTime _from;
  late DateTime _to;

  static const _types = [
    'CREATE',
    'MANUAL_EDIT',
    'CSV_IMPORT',
    'RESTOCK',
    'DISPENSE',
    'ROLLBACK_REVERSAL',
  ];

  @override
  void initState() {
    super.initState();
    _syncFilters();
  }

  void _syncFilters() {
    _item = widget.controller.auditFilter.itemName;
    _type = widget.controller.auditFilter.changeType;
    _from = widget.controller.auditFilter.dateFrom;
    _to = widget.controller.auditFilter.dateTo;
  }

  void _error(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => from ? _from = picked : _to = picked);
    }
  }

  Future<void> _apply() async {
    try {
      await widget.controller.setAuditFilter(
        AuditFilter(
          itemName: _item,
          changeType: _type,
          dateFrom: _from,
          dateTo: _to,
        ),
      );
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _clear() async {
    await widget.controller.clearAuditFilters();
    _syncFilters();
    setState(() {});
  }

  Future<void> _rollback() async {
    final entry = widget.controller.selectedLedgerEntry;
    if (entry == null) {
      _error('Select a ledger entry first.');
      return;
    }
    final inverse = -entry.deltaQuantity;
    final ok = await showSmartConfirm(
      context,
      title: 'Rollback Ledger Entry',
      confirmLabel: 'Rollback',
      destructive: false,
      message:
          'Rollback ledger entry #${entry.ledgerId}?\n\n'
          'Item: ${entry.itemName}\n'
          'Original change: ${entry.deltaQuantity >= 0 ? '+' : ''}${entry.deltaQuantity} units\n'
          'Inverse to apply: ${inverse >= 0 ? '+' : ''}$inverse units\n\n'
          'A new ROLLBACK_REVERSAL entry will be written.',
    );
    if (!ok) return;
    try {
      await widget.controller.rollbackSelectedLedger();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final expanded = constraints.maxWidth >= 1100;
        final padding = expanded
            ? 24.0
            : compact
            ? 12.0
            : 18.0;

        if (expanded) {
          return Padding(
            padding: EdgeInsets.all(padding),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, compact: false),
                  const Divider(height: 1),
                  Expanded(child: _desktopTable(context)),
                  const Divider(height: 1),
                  _footer(context, compact: false),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, compact: compact),
                  const Divider(height: 1),
                  _mobileEntries(context),
                  const Divider(height: 1),
                  _footer(context, compact: compact),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, {required bool compact}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            Text(
              'Audit Log',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Immutable inventory history and rollback reversals.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showSchedulerDialog(context, widget.controller),
              icon: const Icon(Icons.schedule),
              label: const Text('Scheduled Exports'),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audit Log',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Immutable inventory history and rollback reversals.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      showSchedulerDialog(context, widget.controller),
                  icon: const Icon(Icons.schedule),
                  label: const Text('Scheduled Exports'),
                ),
              ],
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final oneColumn = compact || box.maxWidth < 640;
              final fieldWidth = oneColumn
                  ? box.maxWidth
                  : (box.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _item,
                      key: ValueKey(
                        'audit-item-${_item ?? 'all'}-${widget.controller.auditItemNames.length}',
                      ),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Item',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Items'),
                        ),
                        ...widget.controller.auditItemNames.map(
                          (name) => DropdownMenuItem<String?>(
                            value: name,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _item = value),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _type,
                      key: ValueKey('audit-type-${_type ?? 'all'}'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Change Type',
                        prefixIcon: Icon(Icons.swap_vert),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Types'),
                        ),
                        ..._types.map(
                          (type) => DropdownMenuItem<String?>(
                            value: type,
                            child: Text(
                              _typeLabel(type),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _DateButton(
                      label: 'From',
                      value: _from,
                      onTap: () => _pickDate(from: true),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: _DateButton(
                      label: 'To',
                      value: _to,
                      onTap: () => _pickDate(from: false),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply Filters'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear Filters'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _exportAudit,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Audit CSV'),
                ),
              ],
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.filter_alt),
                  label: const Text('Apply Filters'),
                ),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Clear'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportAudit,
                  icon: const Icon(Icons.download),
                  label: const Text('Export Audit CSV'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _exportAudit() async {
    try {
      await widget.controller.exportAuditCsv();
    } catch (e) {
      _error(e);
    }
  }

  Widget _desktopTable(BuildContext context) {
    if (widget.controller.auditPage.entries.isEmpty) {
      return const Center(
        child: Text('No ledger entries match the current filters.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('Item Name')),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Change Type')),
            DataColumn(label: Text('Δ Qty'), numeric: true),
            DataColumn(label: Text('Price'), numeric: true),
            DataColumn(label: Text('Running Balance'), numeric: true),
          ],
          rows: widget.controller.auditPage.entries.map((entry) {
            final deltaColor = _deltaColor(context, entry);
            return DataRow(
              selected:
                  widget.controller.selectedLedgerEntry?.ledgerId ==
                  entry.ledgerId,
              onSelectChanged: (_) =>
                  widget.controller.selectLedgerEntry(entry),
              cells: [
                DataCell(Text(entry.timestamp)),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      entry.itemName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(entry.sku)),
                DataCell(
                  Text(
                    '${_icon(entry.changeType)} ${_typeLabel(entry.changeType)}',
                  ),
                ),
                DataCell(
                  Text(
                    '${entry.deltaQuantity >= 0 ? '+' : ''}${entry.deltaQuantity}',
                    style: TextStyle(
                      color: deltaColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                DataCell(Text('₱${entry.priceSnapshot.toStringAsFixed(2)}')),
                DataCell(Text('${entry.runningBalance}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _mobileEntries(BuildContext context) {
    final entries = widget.controller.auditPage.entries;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 56, horizontal: 20),
        child: Center(
          child: Text(
            'No ledger entries match the current filters.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final selected =
            widget.controller.selectedLedgerEntry?.ledgerId == entry.ledgerId;
        final deltaColor = _deltaColor(context, entry);
        return Material(
          color: selected
              ? scheme.secondaryContainer.withValues(alpha: .5)
              : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () =>
                widget.controller.selectLedgerEntry(selected ? null : entry),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          _icon(entry.changeType),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.itemName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              entry.sku,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.deltaQuantity >= 0 ? '+' : ''}${entry.deltaQuantity}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: deltaColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _AuditPill(
                        icon: Icons.swap_vert,
                        text: _typeLabel(entry.changeType),
                      ),
                      _AuditPill(
                        icon: Icons.account_balance_wallet_outlined,
                        text: 'Balance ${entry.runningBalance}',
                      ),
                      _AuditPill(
                        icon: Icons.payments_outlined,
                        text: '₱${entry.priceSnapshot.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.timestamp,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _deltaColor(BuildContext context, LedgerEntry entry) {
    if (entry.changeType == 'ROLLBACK_REVERSAL')
      return Theme.of(context).colorScheme.tertiary;
    if (entry.deltaQuantity > 0) return Colors.green.shade700;
    if (entry.deltaQuantity < 0) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Widget _footer(BuildContext context, {required bool compact}) {
    final previousEnabled = widget.controller.auditPageIndex > 0;
    final nextEnabled =
        (widget.controller.auditPageIndex + 1) * 100 <
        widget.controller.auditPage.total;
    final selected = widget.controller.selectedLedgerEntry;
    final pageLabel =
        'Page ${widget.controller.auditPageIndex + 1} of ${widget.controller.auditTotalPages}';

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$pageLabel · ${widget.controller.auditPage.total} entries',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: previousEnabled
                        ? widget.controller.auditPrev
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: nextEnabled ? widget.controller.auditNext : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _rollback,
                icon: const Icon(Icons.undo),
                label: const Text('Rollback Selected Entry'),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          Text(
            'InventoryLedger · ${widget.controller.auditPage.total} rows · $pageLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: previousEnabled ? widget.controller.auditPrev : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              FilledButton.tonalIcon(
                onPressed: nextEnabled ? widget.controller.auditNext : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
              FilledButton.tonalIcon(
                onPressed: selected == null ? null : _rollback,
                icon: const Icon(Icons.undo),
                label: const Text('Rollback Selected'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'CREATE' => 'Created',
    'MANUAL_EDIT' => 'Manual edit',
    'CSV_IMPORT' => 'CSV import',
    'RESTOCK' => 'Restock',
    'DISPENSE' => 'Dispense',
    'ROLLBACK_REVERSAL' => 'Rollback reversal',
    _ => type,
  };

  String _icon(String type) => switch (type) {
    'CREATE' => '🆕',
    'MANUAL_EDIT' => '✏',
    'CSV_IMPORT' => '📥',
    'RESTOCK' => '+',
    'DISPENSE' => '−',
    'ROLLBACK_REVERSAL' => '↩',
    _ => '•',
  };
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today, size: 18),
    label: Text(
      '$label · ${DateFormat('yyyy-MM-dd').format(value)}',
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _AuditPill extends StatelessWidget {
  const _AuditPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
