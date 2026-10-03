import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/app_theme.dart';
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
              (_status == 'In stock'
                  ? !item.isLowStock
                  : _status == 'Low stock'
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
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final wide = box.maxWidth >= 1100 && textScale < 1.4;
      final compactHeader = box.maxWidth < 380 || textScale >= 1.4;
      final items = _visible;
      final lowCount = _all.where((item) => item.isLowStock).length;
      final outCount = _all.where((item) => item.quantity == 0).length;
      final inCount = _all.where((item) => !item.isLowStock).length;

      Widget filterChip(String value, String label) => ChoiceChip(
        label: Text(label),
        selected: _status == value,
        onSelected: (_) => setState(() => _status = value),
        showCheckmark: false,
        selectedColor: scheme.primary,
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          color: _status == value
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        side: BorderSide(color: scheme.outlineVariant),
      );

      final list = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('inventory-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Inventory',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              if (!compactHeader) ...[
                                const SizedBox(width: 8),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '${_all.length}',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Scan barcode',
                          onPressed: () => showScanner(context, widget.controller),
                          icon: const Icon(Icons.qr_code_2),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Filter and sort',
                          onPressed: _loading
                              ? null
                              : () => setState(() => _filtersOpen = !_filtersOpen),
                          icon: Icon(
                            _filtersOpen
                                ? Icons.tune
                                : Icons.tune_outlined,
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _edit(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        hintText: 'Search items, SKU, category…',
                        labelText: 'Search inventory',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
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
                        setState(() {});
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          filterChip('All stock', 'All ${_all.length}'),
                          const SizedBox(width: 8),
                          filterChip('In stock', 'In stock $inCount'),
                          const SizedBox(width: 8),
                          // Keep this exact wording for existing UI automation.
                          filterChip('Low stock', 'Low stock ($lowCount)'),
                          const SizedBox(width: 8),
                          filterChip('Out of stock', 'Out of stock $outCount'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Showing ${items.length} items',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _sort,
                            borderRadius: BorderRadius.circular(16),
                            items: ['Name', 'Quantity', 'Value', 'Urgency']
                                .map(
                                  (sort) => DropdownMenuItem(
                                    value: sort,
                                    child: Text('Sort: $sort'),
                                  ),
                                )
                                .toList(),
                            onChanged: (sort) {
                              if (sort != null) setState(() => _sort = sort);
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_filtersOpen) ...[
                      const SizedBox(height: 10),
                      Card(
                        color: scheme.surfaceContainerLowest,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Filter inventory',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 10),
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
                                    (category) => DropdownMenuItem(
                                      value: category.name,
                                      child: Text(
                                        category.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (category) =>
                                    setState(() => _category = category),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(
                        semanticsLabel: 'Loading inventory',
                      ),
                    ],
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
                    padding: const EdgeInsets.only(bottom: 10),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stockColors = StockColors.of(context);
    final words = item.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : (words.first.characters.first +
                  (words.length > 1 ? words.last.characters.first : ''))
              .toUpperCase();
    final statusColor = item.quantity == 0
        ? scheme.error
        : item.isLowStock
        ? stockColors.warning
        : stockColors.healthy;
    final target = item.reorderLevel <= 0 ? 1 : item.reorderLevel;
    final progress = (item.quantity / (target * 2)).clamp(0.0, 1.0).toDouble();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Text(
                        initials,
                        key: ValueKey('inventory-avatar-${item.id}'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StockStatus(item: item),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${displaySku(item.sku)}  •  ${item.category}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(statusColor),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(
                          'Qty: ${item.quantity}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'units',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '(Min: ${item.reorderLevel})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Unit: ₱${item.unitPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _EditorIntro(isNew: widget.item == null),
                  const SizedBox(height: 14),
                  _EditorSection(
                    icon: Icons.inventory_2_outlined,
                    title: 'General Information',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Item Name',
                            hintText: 'e.g. N95 Respirator Masks',
                          ),
                          validator: (s) => s == null || s.trim().isEmpty
                              ? 'Enter an item name.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
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
                          validator: (s) => s == null
                              ? 'Add a category in Settings first.'
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorSection(
                    icon: Icons.calculate_outlined,
                    title: 'Inventory & Valuation',
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, box) {
                            final wide = box.maxWidth >= 520;
                            final quantity = TextFormField(
                              controller: _quantity,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                hintText: 'Enter quantity',
                              ),
                              validator: _whole,
                            );
                            final price = TextFormField(
                              controller: _price,
                              enabled: !_busy,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Unit Price (PHP)',
                                hintText: 'Enter unit price',
                              ),
                              validator: (s) {
                                final n = double.tryParse(s ?? '');
                                return n == null || !n.isFinite || n < 0
                                    ? 'Enter zero or a positive price.'
                                    : null;
                              },
                            );
                            if (!wide) {
                              return Column(
                                children: [
                                  quantity,
                                  const SizedBox(height: 14),
                                  price,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: quantity),
                                const SizedBox(width: 12),
                                Expanded(child: price),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _reorder,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Reorder Threshold',
                            hintText: 'Alert threshold (e.g. 10)',
                            helperText:
                                'SmartStock flags this item when stock drops below this level.',
                          ),
                          validator: _whole,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: Icon(
                      widget.item == null
                          ? Icons.add_box_outlined
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      _busy
                          ? 'Saving…'
                          : widget.item == null
                          ? 'Add Item'
                          : 'Save Changes',
                    ),
                  ),
                  const SizedBox(height: 4),
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

class _EditorIntro extends StatelessWidget {
  const _EditorIntro({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  isNew ? Icons.add_box_outlined : Icons.edit_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'New Inventory Item' : 'Update Item Details',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isNew
                        ? 'Add the core catalog and stock information.'
                        : 'Edit item metadata without changing transaction history.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> showScanner(
  BuildContext context,
  SmartStockController controller,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ScannerPage(controller: controller),
    ),
  );
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.controller});

  final SmartStockController controller;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final field = TextEditingController();
  final focus = FocusNode();
  final List<InventoryItem> _session = [];
  MobileScannerController? _cameraController;
  bool _busy = false;
  String? _error;

  bool get _runningWidgetTest => WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  bool get _cameraSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !_runningWidgetTest;

  @override
  void initState() {
    super.initState();
    if (_cameraSupported) {
      _cameraController = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.noDuplicates,
        autoZoom: true,
      );
    }
  }

  @override
  void dispose() {
    final camera = _cameraController;
    _cameraController = null;
    if (camera != null) {
      unawaited(camera.dispose());
    }
    field.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _find({bool requestFocusAfter = true}) async {
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
        setState(() {
          _session.removeWhere((entry) => entry.id == item.id);
          _session.insert(0, item);
          // Stop the lookup spinner before opening the details dialog so the
          // scanner route can settle while the modal is visible.
          _busy = false;
        });
        await showItemDetailsDialog(
          context,
          item,
          controller: widget.controller,
        );
        if (mounted) {
          field.clear();
          if (requestFocusAfter) focus.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not find item: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCameraDetection(BarcodeCapture capture) async {
    if (_busy) return;
    String? value;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        value = raw;
        break;
      }
    }
    if (value == null) return;

    field.text = value;
    final camera = _cameraController;
    try {
      await camera?.stop();
      await _find(requestFocusAfter: false);
    } finally {
      if (mounted && camera != null) {
        try {
          await camera.start();
        } on MobileScannerException catch (e) {
          if (mounted) {
            setState(() {
              _error = e.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Camera permission was denied. You can still use a USB scanner or enter the barcode manually.'
                  : 'Could not restart the camera scanner.';
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final camera = _cameraController;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Barcode Scanner'),
          leading: IconButton(
            tooltip: 'Cancel',
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_cameraSupported && camera != null)
                    _CameraScannerTarget(
                      controller: camera,
                      busy: _busy,
                      onDetect: _handleCameraDetection,
                    )
                  else
                    _ScannerTarget(busy: _busy),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Having trouble scanning?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cameraSupported
                                ? 'Point your phone camera at a barcode, use a connected scanner, or enter the barcode / SKU manually.'
                                : 'Use a connected barcode scanner, or enter the barcode / SKU manually.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: field,
                            focusNode: focus,
                            enabled: !_busy,
                            autofocus: !_cameraSupported,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _find(),
                            decoration: InputDecoration(
                              labelText: 'Barcode or SKU',
                              hintText: 'Enter barcode number manually…',
                              prefixIcon: const Icon(Icons.qr_code_2),
                              errorText: _error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _busy ? null : _find,
                            icon: const Icon(Icons.search),
                            label: Text(_busy ? 'Finding…' : 'Find item'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_session.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Recent Scans',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => setState(_session.clear),
                                  child: const Text('Clear'),
                                ),
                              ],
                            ),
                            for (final item in _session.take(5))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.qr_code_2),
                                title: Text(item.name),
                                subtitle: Text(displaySku(item.sku)),
                                trailing: StockStatus(item: item),
                                onTap: () => showItemDetailsDialog(
                                  context,
                                  item,
                                  controller: widget.controller,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
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
}

class _CameraScannerTarget extends StatelessWidget {
  const _CameraScannerTarget({
    required this.controller,
    required this.busy,
    required this.onDetect,
  });

  final MobileScannerController controller;
  final bool busy;
  final ValueChanged<BarcodeCapture> onDetect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Camera barcode scanner. Align a barcode within the frame.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: controller,
                fit: BoxFit.cover,
                tapToFocus: true,
                onDetect: busy ? null : onDetect,
                errorBuilder: (context, error) => _CameraScannerError(
                  error: error,
                  onRetry: () => unawaited(controller.start()),
                ),
                placeholderBuilder: (context) => ColoredBox(
                  color: theme.colorScheme.primary,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: .20),
                        Colors.transparent,
                        Colors.black.withValues(alpha: .28),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 220,
                  height: 132,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: ValueListenableBuilder<MobileScannerState>(
                  valueListenable: controller,
                  builder: (context, state, _) {
                    if (state.torchState == TorchState.unavailable) {
                      return const SizedBox.shrink();
                    }
                    return IconButton.filled(
                      tooltip: state.torchState == TorchState.on
                          ? 'Turn flash off'
                          : 'Turn flash on',
                      onPressed: busy
                          ? null
                          : () => unawaited(controller.toggleTorch()),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: .45),
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .48),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.qr_code_scanner,
                            size: 18,
                            color: Colors.white,
                          ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            busy
                                ? 'Looking up scanned item…'
                                : 'Align a barcode inside the frame',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraScannerError extends StatelessWidget {
  const _CameraScannerError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            Text(
              denied
                  ? 'Camera permission is off'
                  : unsupported
                      ? 'Camera scanning is unavailable'
                      : 'Camera scanner could not start',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Allow Camera permission for SmartStock, or use the manual / hardware scanner field below.'
                  : 'You can still use a connected barcode scanner or enter the barcode manually.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .85),
                  ),
            ),
            if (!unsupported) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry camera'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScannerTarget extends StatelessWidget {
  const _ScannerTarget({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navy = theme.colorScheme.primary;
    return Semantics(
      label: 'Scanner target. Align a barcode within the frame.',
      child: Container(
        height: 270,
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerGridPainter(
                  color: theme.colorScheme.onPrimary.withValues(alpha: .08),
                ),
              ),
            ),
            Container(
              width: 210,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.onPrimary,
                  width: 3,
                ),
              ),
              child: Center(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.qr_code_scanner,
                          size: 18,
                          color: theme.colorScheme.onPrimary,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          busy
                              ? 'Looking up scanned item…'
                              : 'Scan with connected hardware or enter a code below',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerGridPainter extends CustomPainter {
  const _ScannerGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const gap = 28.0;
    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

