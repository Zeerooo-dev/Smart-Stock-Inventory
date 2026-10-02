import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';

class InventoryPageView extends StatefulWidget {
  const InventoryPageView({super.key, required this.controller});
  final SmartStockController controller;
  @override
  State<InventoryPageView> createState() => _InventoryPageViewState();
}

class _InventoryPageViewState extends State<InventoryPageView> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<InventoryItem> _all = [];
  String _query = '', _sort = 'Name', _status = 'All stock';
  String? _category, _error;
  bool _loading = false, _detailsOpen = false, _filtersOpen = false;
  int _request = 0;
  InventoryPage? _lastPage;
  InventoryItem? _selected;
  String _externalSearch = '';
  @override
  void initState() {
    super.initState();
    _seed();
  }

  void _seed() {
    final page = widget.controller.inventoryPage;
    _lastPage = page;
    if (widget.controller.inventorySearch != _externalSearch) {
      _externalSearch = widget.controller.inventorySearch;
      _query = _externalSearch.toLowerCase();
      _search.text = _externalSearch;
    }
    if (page.total == page.items.length &&
        widget.controller.inventorySearch.isEmpty) {
      _request++;
      _all = page.items;
      _loading = false;
      _error = null;
    } else {
      unawaited(_load());
    }
    if (_selected != null) {
      _selected = page.items
          .where((item) => item.id == _selected!.id)
          .firstOrNull;
    }
  }

  @override
  void didUpdateWidget(covariant InventoryPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastPage != widget.controller.inventoryPage ||
        _externalSearch != widget.controller.inventorySearch) {
      _seed();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.controller.database.getAllInventory();
      if (mounted && request == _request) setState(() => _all = items);
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = 'Could not load inventory: $e');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([InventoryItem? item]) async {
    if (item != null) {
      try {
        item = await widget.controller.database.findItemById(item.id);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load this item: $error')),
          );
        }
        return;
      }
      if (!mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item no longer exists.')),
        );
        return;
      }
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ItemEditor(controller: widget.controller, item: item),
      ),
    );
  }

  Future<void> _details(InventoryItem item, bool wide) async {
    if (_detailsOpen) return;
    if (wide) {
      setState(() => _selected = item);
      return;
    }
    _detailsOpen = true;
    try {
      final current = await widget.controller.database.findItemById(item.id);
      if (!mounted) return;
      if (current == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This item no longer exists.')),
        );
        return;
      }
      await showItemDetailsDialog(
        context,
        current,
        controller: widget.controller,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open item: $e')));
      }
    } finally {
      _detailsOpen = false;
    }
  }

  Future<void> _actions(InventoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.titleLarge),
            for (final action in [
              'Edit',
              'View history',
              'Restock',
              'Dispense',
              'Delete',
            ])
              ListTile(
                title: Text(action),
                onTap: () => Navigator.pop(context, action),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'Edit':
        await _edit(item);
      case 'View history':
        await showItemHistoryDialog(context, widget.controller, item);
      case 'Restock':
        await adjustItemStock(context, widget.controller, item, restock: true);
      case 'Dispense':
        await adjustItemStock(context, widget.controller, item, restock: false);
      case 'Delete':
        if (!await showSmartConfirm(
          context,
          title: 'Delete item',
          confirmLabel: 'Delete item',
          message:
          "Delete '${item.name}' from inventory? The deletion is recorded in the Audit Log. Existing history is kept.",
        )) {
          return;
        }
        try {
          await widget.controller.deleteItem(item);
          if (mounted) setState(() => _selected = null);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not delete item: $e')),
            );
          }
        }
    }
  }

  List<InventoryItem> get _visible {
    final items = _all
        .where(
          (item) =>
      ('${item.name} ${item.sku} ${item.category}'
          .toLowerCase()
          .contains(_query)) &&
          (_category == null || item.category == _category) &&
          (_status == 'All stock' ||
              (_status == 'Low stock'
                  ? item.isLowStock
                  : item.quantity == 0)),
    )
        .toList();
    items.sort((a, b) {
      final result = switch (_sort) {
        'Quantity' => a.quantity.compareTo(b.quantity),
        'Value' => b.value.compareTo(a.value),
        'Urgency' =>
            (a.quantity / (a.reorderLevel > 0 ? a.reorderLevel : 1)).compareTo(
              b.quantity / (b.reorderLevel > 0 ? b.reorderLevel : 1),
            ),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return items;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide =
          box.maxWidth >= 1100 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.4;
      final items = _visible;
      final list = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('inventory-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Search inventory',
                        labelText: 'Search inventory',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _debounce?.cancel();
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 200),
                              () {
                            if (mounted) {
                              setState(
                                    () => _query = value.trim().toLowerCase(),
                              );
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (wide)
                          FilledButton.icon(
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _status = _status == 'Low stock'
                                ? 'All stock'
                                : 'Low stock';
                            _sort = 'Urgency';
                          }),
                          icon: const Icon(Icons.warning_amber_outlined),
                          label: Text(
                            'Low stock (${_all.where((i) => i.isLowStock).length})',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showScanner(context, widget.controller),
                          icon: const Icon(Icons.barcode_reader),
                          label: const Text('Scan barcode'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading
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
                      label: Text('Filter and sort · $_status'),
                    ),
                    if (_filtersOpen) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        key: ValueKey('inventory-status-$_status'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stock status',
                        ),
                        items: ['All stock', 'Low stock', 'Out of stock']
                            .map(
                              (s) =>
                              DropdownMenuItem(value: s, child: Text(s)),
                        )
                            .toList(),
                        onChanged: (s) {
                          if (s == null) return;
                          setState(() => _status = s);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All categories'),
                          ),
                          ...widget.controller.categories.map(
                                (c) => DropdownMenuItem(
                              value: c.name,
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (s) => setState(() => _category = s),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sort,
                        key: ValueKey('inventory-sort-$_sort'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                        ),
                        items: ['Name', 'Quantity', 'Value', 'Urgency']
                            .map(
                              (s) =>
                              DropdownMenuItem(value: s, child: Text(s)),
                        )
                            .toList(),
                        onChanged: (s) {
                          if (s == null) return;
                          setState(() => _sort = s);
                        },
                      ),
                    ],
                    if (_loading)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Loading inventory',
                      ),
                    if (_error != null)
                      EmptyMessage(
                        title: 'Inventory unavailable',
                        message: _error!,
                        action: TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    if (!_loading && _error == null && items.isEmpty)
                      EmptyMessage(
                        title: _all.isEmpty
                            ? 'No inventory yet'
                            : 'No matching items',
                        message: _all.isEmpty
                            ? 'Add your first item to start counting stock.'
                            : 'Try another name, SKU, category, or stock filter.',
                      ),
                    Text('${items.length} items'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InventoryRow(
                      item: item,
                      onTap: () => _details(item, wide),
                      onActions: () => _actions(item),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      );
      if (!wide) {
        return Scaffold(
          body: list,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: list),
          SizedBox(
            width: 440,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _selected == null
                  ? const EmptyMessage(
                title: 'Item details',
                message:
                'Select an item to see its stock, barcode, and history.',
              )
                  : ItemDetails(
                key: ValueKey(_selected!.id),
                item: _selected!,
                controller: widget.controller,
                embedded: true,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class InventoryRow extends StatelessWidget {
  const InventoryRow({
    super.key,
    required this.item,
    required this.onTap,
    this.onActions,
  });
  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback? onActions;
  @override
  Widget build(BuildContext context) {
    final words = item.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : (words.first.characters.first +
        (words.length > 1 ? words.last.characters.first : ''))
        .toUpperCase();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        initials,
                        key: ValueKey('inventory-avatar-${item.id}'),
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onActions != null)
                    IconButton(
                      tooltip: 'Item actions',
                      onPressed: onActions,
                      icon: const Icon(Icons.more_vert),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Qty: ${item.quantity}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              StockStatus(item: item),
              const SizedBox(height: 8),
              Text('${item.category} · ₱${item.unitPrice.toStringAsFixed(2)}'),
              Text(
                displaySku(item.sku),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.controller, this.item});
  final SmartStockController controller;
  final InventoryItem? item;
  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _quantity = TextEditingController(
    text: widget.item?.quantity.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: widget.item?.unitPrice.toStringAsFixed(2) ?? '',
  );
  late final _reorder = TextEditingController(
    text: widget.item?.reorderLevel.toString() ?? '5',
  );
  late String? _category =
      widget.item?.category ?? widget.controller.categories.firstOrNull?.name;
  bool _dirty = false, _busy = false, _leave = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _quantity, _price, _reorder]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty &&
        !await showSmartConfirm(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved item changes will be lost.',
          confirmLabel: 'Discard',
          destructive: false,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _leave = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.item == null) {
        await widget.controller.addItem(
          name: _name.text.trim(),
          category: _category!,
          quantity: int.parse(_quantity.text),
          unitPrice: double.parse(_price.text),
          reorderLevel: int.parse(_reorder.text),
        );
      } else {
        await widget.controller.updateItem(
          itemId: widget.item!.id,
          name: _name.text.trim(),
          category: _category!,
          quantity: int.parse(_quantity.text),
          unitPrice: double.parse(_price.text),
          reorderLevel: int.parse(_reorder.text),
        );
      }
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _busy = false;
        _leave = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved.')));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _whole(String? value) => (int.tryParse(value ?? '') ?? -1) < 0
      ? 'Enter zero or a positive whole number.'
      : null;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leave || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'Add New Item' : 'Edit Inventory Item',
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _form,
              onChanged: () {
                if (!_dirty) setState(() => _dirty = true);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Item Name'),
                    validator: (s) => s == null || s.trim().isEmpty
                        ? 'Enter an item name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: widget.controller.categories
                        .map(
                          (c) => DropdownMenuItem(
                        value: c.name,
                        child: Text(
                          c.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                    onChanged: _busy ? null : (s) => _category = s,
                    validator: (s) =>
                    s == null ? 'Add a category in Settings first.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'Enter quantity',
                    ),
                    validator: _whole,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _price,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (PHP)',
                    ),
                    validator: (s) {
                      final n = double.tryParse(s ?? '');
                      return n == null || !n.isFinite || n < 0
                          ? 'Enter zero or a positive price.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reorder,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Reorder Threshold',
                    ),
                    validator: _whole,
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy
                          ? 'Saving…'
                          : widget.item == null
                          ? 'Add Item'
                          : 'Save Changes',
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _close,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> showScanner(
    BuildContext context,
    SmartStockController controller,
    ) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ScannerDialog(controller: controller),
  );
}

class _ScannerDialog extends StatefulWidget {
  const _ScannerDialog({required this.controller});
  final SmartStockController controller;
  @override
  State<_ScannerDialog> createState() => _ScannerDialogState();
}

class _ScannerDialogState extends State<_ScannerDialog> {
  final field = TextEditingController();
  final focus = FocusNode();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    field.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (_busy) return;
    final sku = field.text.trim();
    if (sku.isEmpty) {
      setState(() => _error = 'Scan or enter a SKU.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await widget.controller.database.findItemBySku(sku);
      if (!mounted) return;
      if (item == null) {
        setState(() => _error = 'No inventory item matches $sku.');
      } else {
        await showItemDetailsDialog(
          context,
          item,
          controller: widget.controller,
        );
        if (mounted) {
          field.clear();
          focus.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not find item: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Scan barcode'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan into this field, or type a SKU. Press Enter or choose Find item.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: field,
              focusNode: focus,
              enabled: !_busy,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _find(),
              decoration: InputDecoration(
                labelText: 'Barcode or SKU',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _find,
          child: Text(_busy ? 'Finding…' : 'Find item'),
        ),
      ],
    ),
  );
}
