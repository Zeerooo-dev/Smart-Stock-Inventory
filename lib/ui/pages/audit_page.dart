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
  String? _error;
  int? _selected;
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
      _selected = null;
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
      setState(
        () => _error =
            'Choose an existing item name, or clear the item field for all items.',
      );
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
    if (!await showSmartConfirm(
      context,
      title: 'Reverse stock change',
      confirmLabel: 'Reverse change',
      destructive: false,
      message:
          'Apply ${-entry.deltaQuantity} units to ${entry.itemName}? A new stock reversal is recorded in the Audit Log. The original entry stays in history.',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      widget.controller.selectLedgerEntry(entry);
      await widget.controller.rollbackSelectedLedger();
      widget.controller.selectLedgerEntry(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final entries = controller.auditPage.entries;
    final selected = entries.where((e) => e.ledgerId == _selected).firstOrNull;
    final filter = controller.auditFilter;
    return CustomScrollView(
      key: const PageStorageKey('audit-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Audit Log',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Text(
                  'Inventory changes, including deleted items. Timestamps are UTC.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Showing ${formatAuditDate(filter.dateFrom)} to ${formatAuditDate(filter.dateTo)} · ${filter.itemName ?? 'All items'} · ${filter.changeType == null ? 'All changes' : changeLabel(filter.changeType!)}',
                ),
                ExpansionTile(
                  key: const PageStorageKey('audit-filter-panel'),
                  title: const Text('Filter history'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    Autocomplete<String>(
                      key: ValueKey(_filterRevision),
                      initialValue: TextEditingValue(text: _item),
                      optionsBuilder: (value) =>
                          controller.auditItemNames.where(
                            (name) => name.toLowerCase().contains(
                              value.text.toLowerCase(),
                            ),
                          ),
                      onSelected: (value) => setState(() => _item = value),
                      fieldViewBuilder: (context, text, focus, submit) =>
                          TextField(
                            key: const PageStorageKey('audit-item-query'),
                            controller: text,
                            focusNode: focus,
                            decoration: const InputDecoration(
                              labelText: 'Item name (blank for all)',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) => setState(() => _item = value),
                          ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      key: ValueKey('type-$_filterRevision'),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Change type',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('All changes'),
                        ),
                        ..._types.map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(changeLabel(type)),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _date(true),
                          child: Text('From: ${formatAuditDate(_from)}'),
                        ),
                        OutlinedButton(
                          onPressed: () => _date(false),
                          child: Text('To: ${formatAuditDate(_to)}'),
                        ),
                        FilledButton(
                          onPressed: _busy ? null : _apply,
                          child: const Text('Apply filters'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await controller.clearAuditFilters();
                                  if (mounted) {
                                    setState(() {
                                      _item = '';
                                      _type = null;
                                      _from = controller.auditFilter.dateFrom;
                                      _to = controller.auditFilter.dateTo;
                                      _filterRevision++;
                                    });
                                  }
                                }),
                          child: const Text('Reset to last 30 days'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_pending)
                  const Text('Filters changed. Apply them before exporting.'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TaskButton(
                      label: 'Export Audit XLSX',
                      icon: Icons.download,
                      action: controller.exportAuditXlsx,
                      savedFile: true,
                      enabled: !_pending && !_busy,
                    ),
                    TaskButton(
                      label: 'Export Audit PDF',
                      icon: Icons.picture_as_pdf_outlined,
                      action: controller.exportAuditPdf,
                      savedFile: true,
                      enabled: !_pending && !_busy,
                    ),
                  ],
                ),
                if (_busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Loading audit history',
                  ),
                if (_error != null)
                  EmptyMessage(
                    title: 'Could not complete request',
                    message: _error!,
                    action: TextButton(
                      onPressed: () => _run(controller.refreshAudit),
                      child: const Text('Retry refresh'),
                    ),
                  ),
                if (entries.isEmpty && !_busy)
                  const EmptyMessage(
                    title: 'No matching history',
                    message:
                        'Try a wider date range or another item or change type.',
                  ),
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Selected: ${selected.itemName} · ${changeLabel(selected.changeType)} · ${selected.changeText}',
                  ),
                  if (selected.changeType == 'DELETE')
                    const Text(
                      'Deleted items cannot be restored by reversing stock.',
                    )
                  else if (selected.deltaQuantity == 0)
                    const Text('This entry has no quantity change to reverse.')
                  else
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : () => _reverse(selected),
                      icon: const Icon(Icons.undo),
                      label: const Text('Reverse stock change'),
                    ),
                ],
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
                padding: const EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  entry: entry,
                  selected: entry.ledgerId == _selected,
                  onTap: () => setState(
                    () => _selected = _selected == entry.ledgerId
                        ? null
                        : entry.ledgerId,
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: PageControls(
              label:
                  'Page ${controller.auditPageIndex + 1} of ${controller.auditTotalPages} · ${controller.auditPage.total} entries',
              previous: !_busy && controller.auditPageIndex > 0
                  ? () => _run(controller.auditPrev)
                  : null,
              next:
                  !_busy &&
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
