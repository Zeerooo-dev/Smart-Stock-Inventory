import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({
    super.key,
    required this.controller,
  });

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

  Future<void> _run(
      Future<void> Function() action,
      ) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _apply() async {
    if (_from.isAfter(_to)) {
      setState(() {
        _error = 'From date must be on or before To date.';
      });
      return;
    }

    if (_item.trim().isNotEmpty &&
        !widget.controller.auditItemNames.contains(
          _item.trim(),
        )) {
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

  Future<void> _date(
      bool from,
      ) async {
    final value = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 3650),
      ),
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

  Future<void> _reverse(
      LedgerEntry entry,
      ) async {
    if (_busy ||
        entry.changeType == 'DELETE' ||
        entry.deltaQuantity == 0) {
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

    if (!confirmed || !mounted) {
      return;
    }

    await _run(() async {
      widget.controller.selectLedgerEntry(entry);

      await widget.controller.rollbackSelectedLedger();

      widget.controller.selectLedgerEntry(null);
    });
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    final controller = widget.controller;
    final entries = controller.auditPage.entries;

    final matchingSelected = entries.where(
          (entry) => entry.ledgerId == _selected,
    );

    final selected =
    matchingSelected.isEmpty ? null : matchingSelected.first;

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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Audit Log',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Inventory activity and reversals',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(
                                Icons.date_range_outlined,
                              ),
                              label: Text(
                                '${formatAuditDate(filter.dateFrom)} – '
                                    '${formatAuditDate(filter.dateTo)}',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.inventory_2_outlined,
                              ),
                              label: Text(
                                filter.itemName ?? 'All items',
                              ),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.swap_vert,
                              ),
                              label: Text(
                                filter.changeType == null
                                    ? 'All changes'
                                    : changeLabel(
                                  filter.changeType!,
                                ),
                              ),
                            ),
                            const Chip(
                              avatar: Icon(
                                Icons.public,
                              ),
                              label: Text('UTC'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                    setState(() {
                      _filtersOpen = !_filtersOpen;
                    });
                  },
                  icon: Icon(
                    _filtersOpen
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: const Text(
                    'Filter history',
                  ),
                ),
                if (_filtersOpen) ...[
                  const SizedBox(height: 12),
                  Autocomplete<String>(
                    key: ValueKey(
                      'audit-autocomplete-$_filterRevision',
                    ),
                    initialValue: TextEditingValue(
                      text: _item,
                    ),
                    optionsBuilder: (value) {
                      final query =
                      value.text.trim().toLowerCase();

                      return controller.auditItemNames.where(
                            (name) {
                          if (query.isEmpty) {
                            return true;
                          }

                          return name.toLowerCase().contains(
                            query,
                          );
                        },
                      );
                    },
                    onSelected: (value) {
                      setState(() {
                        _item = value;
                      });
                    },
                    fieldViewBuilder: (
                        context,
                        textController,
                        focusNode,
                        onFieldSubmitted,
                        ) {
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText:
                          'Item name (blank for all)',
                          prefixIcon: Icon(
                            Icons.search,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _item = value;
                          });
                        },
                        onSubmitted: (_) {
                          onFieldSubmitted();
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    key: ValueKey(
                      'audit-type-$_filterRevision',
                    ),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Change type',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'All changes',
                        ),
                      ),
                      ..._types.map(
                            (type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(
                            changeLabel(type),
                          ),
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                      setState(() {
                        _type = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _date(true),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                        ),
                        label: Text(
                          'From: ${formatAuditDate(_from)}',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _date(false),
                        icon: const Icon(
                          Icons.event_outlined,
                        ),
                        label: Text(
                          'To: ${formatAuditDate(_to)}',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : _apply,
                        icon: const Icon(
                          Icons.filter_alt_outlined,
                        ),
                        label: const Text(
                          'Apply filters',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                              () async {
                            await controller
                                .clearAuditFilters();

                            if (!mounted) {
                              return;
                            }

                            setState(() {
                              _item = '';
                              _type = null;
                              _from = controller
                                  .auditFilter.dateFrom;
                              _to = controller
                                  .auditFilter.dateTo;
                              _filterRevision++;
                            });
                          },
                        ),
                        icon: const Icon(
                          Icons.restart_alt,
                        ),
                        label: const Text(
                          'Reset to last 30 days',
                        ),
                      ),
                    ],
                  ),
                ],
                if (_pending) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Filters changed. Apply them before exporting.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: !_pending && !_busy
                          ? () => showAuditExportOptions(
                        context,
                        controller,
                      )
                          : null,
                      icon: const Icon(
                        Icons.download,
                      ),
                      label: const Text(
                        'Export',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: !_pending && !_busy
                          ? () => showAuditSchedulerDialog(
                        context,
                        controller,
                      )
                          : null,
                      icon: const Icon(
                        Icons.schedule,
                      ),
                      label: const Text(
                        'Schedule',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Top pagination controls so users can move between pages
                // without scrolling to the bottom first.
                PageControls(
                  label:
                  'Page ${controller.auditPageIndex + 1} '
                      'of ${controller.auditTotalPages} · '
                      '${controller.auditPage.total} entries',
                  previous:
                  !_busy && controller.auditPageIndex > 0
                      ? () => _run(
                    controller.auditPrev,
                  )
                      : null,
                  next:
                  !_busy &&
                      controller.auditPageIndex + 1 <
                          controller.auditTotalPages
                      ? () => _run(
                    controller.auditNext,
                  )
                      : null,
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    semanticsLabel:
                    'Loading audit history',
                  ),
                ],
                if (_error != null)
                  EmptyMessage(
                    title:
                    'Could not complete request',
                    message: _error!,
                    action: TextButton(
                      onPressed: () => _run(
                        controller.refreshAudit,
                      ),
                      child: const Text(
                        'Retry refresh',
                      ),
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
                  Card(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Selected entry',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${selected.itemName} · '
                                '${changeLabel(selected.changeType)} · '
                                '${selected.changeText}',
                          ),
                          const SizedBox(height: 12),
                          if (selected.changeType ==
                              'DELETE')
                            const Text(
                              'Deleted items cannot be restored by reversing stock.',
                            )
                          else if (selected
                              .deltaQuantity ==
                              0)
                            const Text(
                              'This entry has no quantity change to reverse.',
                            )
                          else
                            FilledButton.tonalIcon(
                              onPressed: _busy
                                  ? null
                                  : () => _reverse(
                                selected,
                              ),
                              icon: const Icon(
                                Icons.undo,
                              ),
                              label: const Text(
                                'Reverse stock change',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          sliver: SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (
                context,
                index,
                ) {
              final entry = entries[index];

              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 8,
                ),
                child: LedgerCard(
                  entry: entry,
                  selected:
                  entry.ledgerId == _selected,
                  onTap: () {
                    setState(() {
                      _selected =
                      _selected ==
                          entry.ledgerId
                          ? null
                          : entry.ledgerId;
                    });
                  },
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding:
          const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: PageControls(
              label:
              'Page ${controller.auditPageIndex + 1} '
                  'of ${controller.auditTotalPages} · '
                  '${controller.auditPage.total} entries',
              previous:
              !_busy &&
                  controller.auditPageIndex >
                      0
                  ? () => _run(
                controller.auditPrev,
              )
                  : null,
              next:
              !_busy &&
                  controller.auditPageIndex +
                      1 <
                      controller
                          .auditTotalPages
                  ? () => _run(
                controller.auditNext,
              )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
