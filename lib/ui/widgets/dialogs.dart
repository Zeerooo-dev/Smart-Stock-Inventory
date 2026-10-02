import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import 'stock_widgets.dart';

Future<bool> showSmartConfirm(
    BuildContext context, {
      required String message,
      String title = 'Confirm deletion',
      String confirmLabel = 'Delete',
      bool destructive = true,
    }) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(
          '$message${destructive ? '\n\nThis cannot be undone.' : ''}',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
        false;

Future<void> showItemDetailsDialog(
    BuildContext context,
    InventoryItem item, {
      required SmartStockController controller,
    }) => showDialog<void>(
  context: context,
  builder: (_) => ItemDetails(item: item, controller: controller),
);

class ItemDetails extends StatefulWidget {
  const ItemDetails({
    super.key,
    required this.item,
    required this.controller,
    this.embedded = false,
  });
  final InventoryItem item;
  final SmartStockController controller;
  final bool embedded;
  @override
  State<ItemDetails> createState() => _ItemDetailsState();
}

class _ItemDetailsState extends State<ItemDetails> {
  late InventoryItem _item = widget.item;
  bool _busy = false;
  String? _error;
  @override
  void didUpdateWidget(covariant ItemDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) _item = widget.item;
  }

  Future<void> _adjust(bool restock) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await adjustItemStock(
        context,
        widget.controller,
        _item,
        restock: restock,
      );
      final current = await widget.controller.database.findItemById(_item.id);
      if (!mounted) return;
      setState(() {
        if (current != null) {
          _item = current;
        } else {
          _error = 'This item no longer exists.';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _item.name,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          'Current Quantity: ${_item.quantity}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Stock Status: ${stockLabel(_item)}'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : () => _adjust(true),
              icon: const Icon(Icons.add),
              label: const Text('Restock'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _adjust(false),
              icon: const Icon(Icons.remove),
              label: const Text('Dispense'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => showItemHistoryDialog(
                context,
                widget.controller,
                _item,
              ),
              icon: const Icon(Icons.history),
              label: const Text('View history'),
            ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        for (final field in <String, String>{
          'SKU': displaySku(_item.sku),
          'Category': _item.category,
          'Unit Price': '₱${_item.unitPrice.toStringAsFixed(2)}',
          'Inventory Value': '₱${_item.value.toStringAsFixed(2)}',
          'Reorder Threshold': '${_item.reorderLevel}',
          'Item ID': '${_item.id}',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText('${field.key}: ${field.value}'),
          ),
        if (_item.sku.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Barcode(sku: _item.sku),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Barcode'),
                content: SizedBox(
                  width: 700,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: _Barcode(sku: _item.sku),
                      ),
                      SelectableText(_item.sku),
                      const Text('Pinch to enlarge.'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.zoom_in),
            label: const Text('Enlarge barcode'),
          ),
        ],
      ],
    );
    if (widget.embedded) {
      return Card(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: content,
        ),
      );
    }
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Item Details'),
        content: SizedBox(width: 480, child: content),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Barcode extends StatelessWidget {
  const _Barcode({required this.sku});
  final String sku;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Barcode for $sku',
    image: true,
    child: Container(
      height: 110,
      width: double.infinity,
      color: StockColors.barcodeBackground,
      padding: const EdgeInsets.all(12),
      child: BarcodeWidget(
        barcode: Barcode.code128(),
        data: sku,
        drawText: false,
        color: StockColors.barcodeInk,
        errorBuilder: (_, _) => const Text(
          'Barcode unavailable.',
          style: TextStyle(color: StockColors.barcodeInk),
        ),
      ),
    ),
  );
}

Future<void> adjustItemStock(
    BuildContext context,
    SmartStockController controller,
    InventoryItem item, {
      required bool restock,
    }) async {
  InventoryItem? current;
  try {
    current = await controller.database.findItemById(item.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load this item: $error')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  if (current == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This item no longer exists.')),
    );
    return;
  }
  final latest = current;
  await showStockAmountDialog(
    context,
    restock: restock,
    item: latest,
    onSubmit: (amount, notes) async {
      await controller.adjustStock(
        latest,
        amount,
        restock: restock,
        notes: notes,
      );
    },
  );
}

Future<({int amount, String notes})?> showStockAmountDialog(
    BuildContext context, {
      required bool restock,
      InventoryItem? item,
      Future<void> Function(int, String)? onSubmit,
    }) => showModalBottomSheet<({int amount, String notes})>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (_) =>
      _StockAmountDialog(restock: restock, item: item, onSubmit: onSubmit),
);

class _StockAmountDialog extends StatefulWidget {
  const _StockAmountDialog({required this.restock, this.item, this.onSubmit});
  final bool restock;
  final InventoryItem? item;
  final Future<void> Function(int, String)? onSubmit;
  @override
  State<_StockAmountDialog> createState() => _StockAmountDialogState();
}

class _StockAmountDialogState extends State<_StockAmountDialog> {
  final amount = TextEditingController(text: '1');
  final notes = TextEditingController();
  final form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  bool _confirming = false;
  bool get _dirty => amount.text != '1' || notes.text.isNotEmpty;
  Future<void> _back() async {
    if (_busy || _confirming) return;
    _confirming = true;
    final discard =
        !_dirty ||
            await showSmartConfirm(
              context,
              title: 'Discard stock adjustment?',
              message: 'The quantity and note have not been saved.',
              confirmLabel: 'Discard',
              destructive: false,
            );
    _confirming = false;
    if (discard && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final count = int.parse(amount.text);
      await widget.onSubmit?.call(count, notes.text.trim());
      if (!mounted) return;
      Navigator.pop(context, (amount: count, notes: notes.text.trim()));
      if (widget.onSubmit != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.restock ? 'Restocked' : 'Dispensed'} $count units.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
    child: PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: form,
            onChanged: () => setState(() {}),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.restock ? 'Restock Item' : 'Dispense Item',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.item != null) ...[
                  Text(widget.item!.name),
                  Text('Available: ${widget.item!.quantity} units'),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    if (count == null || count < 1) {
                      return 'Enter at least 1 whole unit.';
                    }
                    if (!widget.restock &&
                        widget.item != null &&
                        count > widget.item!.quantity) {
                      return 'Not enough stock. Available: ${widget.item!.quantity} units.';
                    }
                    return null;
                  },
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    IconButton.outlined(
                      tooltip: 'Decrease quantity',
                      onPressed: _busy
                          ? null
                          : () {
                        final count = int.tryParse(amount.text) ?? 1;
                        amount.text = '${count > 1 ? count - 1 : 1}';
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton.outlined(
                      tooltip: 'Increase quantity',
                      onPressed: _busy
                          ? null
                          : () {
                        amount.text =
                        '${(int.tryParse(amount.text) ?? 0) + 1}';
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: notes,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? 'Saving…'
                        : widget.restock
                        ? 'Confirm restock'
                        : 'Confirm dispense',
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showItemHistoryDialog(
    BuildContext context,
    SmartStockController controller,
    InventoryItem item,
    ) => showDialog<void>(
  context: context,
  builder: (_) => _ItemHistoryDialog(controller: controller, item: item),
);

class _ItemHistoryDialog extends StatefulWidget {
  const _ItemHistoryDialog({required this.controller, required this.item});
  final SmartStockController controller;
  final InventoryItem item;
  @override
  State<_ItemHistoryDialog> createState() => _ItemHistoryDialogState();
}

class _ItemHistoryDialogState extends State<_ItemHistoryDialog> {
  int _page = 0;
  late Future<ItemHistorySnapshot> _future = _load();
  Future<ItemHistorySnapshot> _load() =>
      widget.controller.database.getItemHistory(widget.item.id, page: _page);
  void _change(int delta) => setState(() {
    _page += delta;
    _future = _load();
  });
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .9,
      child: FutureBuilder<ItemHistorySnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (snapshot.hasError) ...[
                    Text('Could not load history: ${snapshot.error}'),
                    TextButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Retry'),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          final pages = (data.totalEntries / DatabaseService.historyPageSize)
              .ceil()
              .clamp(1, 1000000000);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Item History',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close history',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(widget.item.name),
                      Text(displaySku(widget.item.sku)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          Text('Current stock: ${data.currentQuantity}'),
                          Text('Total added: +${data.totalAdded}'),
                          Text('Total removed: -${data.totalRemoved}'),
                        ],
                      ),
                      TaskButton(
                        label: 'Export history XLSX',
                        icon: Icons.download,
                        savedFile: true,
                        action: () =>
                            widget.controller.exportItemHistoryXlsx(widget.item),
                      ),
                      if (data.entries.isEmpty)
                        const EmptyMessage(
                          title: 'No history yet',
                          message: 'Stock changes will appear here.',
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: data.entries.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LedgerCard(
                      entry: data.entries[index],
                      showIdentity: false,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: PageControls(
                    label:
                    'Page ${_page + 1} of $pages · ${data.totalEntries} entries',
                    previous: _page > 0 ? () => _change(-1) : null,
                    next: _page + 1 < pages ? () => _change(1) : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> _showActionError(
    BuildContext context, {
      required String title,
      required Object error,
    }) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: SelectableText('$error'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> _showSavedExportResult(
    BuildContext context,
    Uri? uri,
    ) async {
  if (!context.mounted) return;
  if (uri == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Save cancelled.')));
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('File saved'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Find this file in the folder or provider you chose.'),
          const SizedBox(height: 12),
          SelectableText(uri.toString()),
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
}

Future<void> showInventoryImportOptions(
    BuildContext context,
    SmartStockController controller,
    ) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import inventory'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('CSV file'),
              subtitle: const Text('Import inventory from a .csv file'),
              onTap: () => Navigator.pop(context, 'csv'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('XLSX workbook'),
              subtitle: const Text('Import inventory from a .xlsx workbook'),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    if (choice == 'csv') {
      await controller.importInventoryCsv();
    } else {
      await controller.importInventoryXlsx();
    }
  } catch (e) {
    if (!context.mounted) return;
    await _showActionError(
      context,
      title: 'Could not import inventory',
      error: e,
    );
  }
}

Future<void> showInventoryExportOptions(
    BuildContext context,
    SmartStockController controller,
    ) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export inventory report'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF report'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('XLSX workbook'),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    final uri = choice == 'pdf'
        ? await controller.exportInventoryPdf()
        : await controller.exportInventoryXlsx();
    if (!context.mounted) return;
    await _showSavedExportResult(context, uri);
  } catch (e) {
    if (!context.mounted) return;
    await _showActionError(
      context,
      title: 'Could not export inventory report',
      error: e,
    );
  }
}

Future<void> showAuditExportOptions(
    BuildContext context,
    SmartStockController controller,
    ) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Audit Log'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF report'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('XLSX workbook'),
              onTap: () => Navigator.pop(context, 'xlsx'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  try {
    final uri = choice == 'pdf'
        ? await controller.exportAuditPdf()
        : await controller.exportAuditXlsx();
    if (!context.mounted) return;
    await _showSavedExportResult(context, uri);
  } catch (e) {
    if (!context.mounted) return;
    await _showActionError(
      context,
      title: 'Could not export Audit Log',
      error: e,
    );
  }
}

Future<void> showAuditSchedulerDialog(
    BuildContext context,
    SmartStockController controller,
    ) async {
  var days = '${controller.auditSchedulerIntervalDays}';
  var format = controller.auditSchedulerFormat;
  var directory = controller.auditSchedulerOutputDirectory;
  final form = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Schedule Audit Log exports'),
        content: Form(
          key: form,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Exports the active Audit Log filter while SmartStock is running. Keep the app open; background timing is not guaranteed.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Interval (days)',
                  ),
                  onChanged: (value) => days = value,
                  validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                      ? 'Enter at least 1 day.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ScheduledFormat>(
                  initialValue: format,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Report format'),
                  items: ScheduledFormat.values
                      .map(
                        (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                      .toList(),
                  onChanged: (value) => format = value ?? format,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(directory),
                  initialValue: directory,
                  decoration: const InputDecoration(
                    labelText: 'Writable output folder',
                  ),
                  onChanged: (value) => directory = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Choose an output folder.'
                      : null,
                ),
                TaskButton(
                  label: 'Choose folder',
                  icon: Icons.folder_open,
                  action: () async {
                    final picked = await controller
                        .chooseAuditSchedulerDirectory();
                    if (picked != null && context.mounted) {
                      setState(() => directory = picked);
                    }
                    return null;
                  },
                ),
                Text(
                  controller.auditSchedulerRunning
                      ? 'Running every ${controller.auditSchedulerIntervalDays} day(s)'
                      : 'Schedule stopped',
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (controller.auditSchedulerRunning)
            TextButton(
              onPressed: () {
                controller.stopAuditScheduler();
                Navigator.pop(context);
              },
              child: const Text('Stop schedule'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!controller.auditSchedulerRunning)
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                controller.startAuditScheduler(
                  days: int.parse(days),
                  format: format,
                  directory: directory,
                );
                Navigator.pop(context);
              },
              child: const Text('Start schedule'),
            ),
        ],
      ),
    ),
  );
}

Future<void> showSchedulerDialog(
    BuildContext context,
    SmartStockController controller,
    ) async {
  var days = '${controller.schedulerIntervalDays}';
  var format = controller.schedulerFormat;
  var directory = controller.schedulerOutputDirectory;
  final form = GlobalKey<FormState>();
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Schedule inventory reports'),
        content: Form(
          key: form,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Exports inventory reports while SmartStock is running. These are not Audit Log exports. Keep the app open; background timing is not guaranteed.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Interval (days)',
                  ),
                  onChanged: (value) => days = value,
                  validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                      ? 'Enter at least 1 day.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ScheduledFormat>(
                  initialValue: format,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Report format'),
                  items: ScheduledFormat.values
                      .map(
                        (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                      .toList(),
                  onChanged: (value) => format = value ?? format,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(directory),
                  initialValue: directory,
                  decoration: const InputDecoration(
                    labelText: 'Writable output folder',
                  ),
                  onChanged: (value) => directory = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Choose an output folder.'
                      : null,
                ),
                TaskButton(
                  label: 'Choose folder',
                  icon: Icons.folder_open,
                  action: () async {
                    final picked = await controller.chooseSchedulerDirectory();
                    if (picked != null && context.mounted) {
                      setState(() => directory = picked);
                    }
                    return null;
                  },
                ),
                Text(
                  controller.schedulerRunning
                      ? 'Running every ${controller.schedulerIntervalDays} day(s)'
                      : 'Schedule stopped',
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (controller.schedulerRunning)
            TextButton(
              onPressed: () {
                controller.stopScheduler();
                Navigator.pop(context);
              },
              child: const Text('Stop schedule'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!controller.schedulerRunning)
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                controller.startScheduler(
                  days: int.parse(days),
                  format: format,
                  directory: directory,
                );
                Navigator.pop(context);
              },
              child: const Text('Start schedule'),
            ),
        ],
      ),
    ),
  );
}

String formatAuditDate(DateTime value) =>
    DateFormat('yyyy-MM-dd').format(value);
