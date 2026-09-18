import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';

class InventoryPageView extends StatefulWidget {
  const InventoryPageView({super.key, required this.controller});
  final SmartStockController controller;

  @override
  State<InventoryPageView> createState() => _InventoryPageViewState();
}

class _InventoryPageViewState extends State<InventoryPageView> {
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0.00');
  final _reorder = TextEditingController(text: '5');
  final _search = TextEditingController();
  final _pageScroll = ScrollController();
  String? _category;
  int? _loadedItemId;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    _reorder.dispose();
    _search.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _syncFromController() {
    final item = widget.controller.selectedItem;
    if (item?.id != _loadedItemId) {
      _loadedItemId = item?.id;
      if (item == null) {
        _name.clear();
        _quantity.text = '0';
        _price.text = '0.00';
        _reorder.text = '5';
        _category = widget.controller.categories.isEmpty ? null : widget.controller.categories.first.name;
      } else {
        _name.text = item.name;
        _quantity.text = '${item.quantity}';
        _price.text = item.unitPrice.toStringAsFixed(2);
        _reorder.text = '${item.reorderLevel}';
        _category = item.category;
      }
    }
    if (_search.text != widget.controller.inventorySearch) {
      _search.value = TextEditingValue(
        text: widget.controller.inventorySearch,
        selection: TextSelection.collapsed(offset: widget.controller.inventorySearch.length),
      );
    }
  }

  void _clearForm() {
    widget.controller.selectItem(null);
    _loadedItemId = null;
    _name.clear();
    _quantity.text = '0';
    _price.text = '0.00';
    _reorder.text = '5';
    _category = widget.controller.categories.isEmpty ? null : widget.controller.categories.first.name;
    setState(() {});
  }

  Future<void> _save({required bool update}) async {
    final name = _name.text.trim();
    final qty = int.tryParse(_quantity.text.trim());
    final price = double.tryParse(_price.text.trim());
    final reorder = int.tryParse(_reorder.text.trim());
    if (name.isEmpty || qty == null || price == null || reorder == null || _category == null) {
      _error('Enter a valid name, category, quantity, unit price, and reorder threshold.');
      return;
    }

    try {
      if (update) {
        final selected = widget.controller.selectedItem;
        if (selected == null) {
          _error('Select an inventory item first.');
          return;
        }
        await widget.controller.updateItem(
          itemId: selected.id,
          name: name,
          category: _category!,
          quantity: qty,
          unitPrice: price,
          reorderLevel: reorder,
        );
      } else {
        await widget.controller.addItem(
          name: name,
          category: _category!,
          quantity: qty,
          unitPrice: price,
          reorderLevel: reorder,
        );
      }
      _clearForm();
    } catch (e) {
      _error(e.toString());
    }
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final ok = await showSmartConfirm(
      context,
      message: "Permanently delete '${item.name}' from inventory?\n\nIts existing audit history will remain in the ledger.",
    );
    if (!ok) return;
    try {
      await widget.controller.deleteItem(item);
      _clearForm();
    } catch (e) {
      _error('$e');
    }
  }


  Future<void> _showItemActions(InventoryItem item) async {
    widget.controller.selectItem(item);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.name, style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${item.sku} · ${item.category}', style: Theme.of(sheetContext).textTheme.bodySmall),
            const SizedBox(height: 16),
            _SheetAction(
              icon: Icons.edit_outlined,
              label: 'Edit item',
              onTap: () {
                Navigator.pop(sheetContext);
                if (_pageScroll.hasClients) {
                  _pageScroll.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                }
              },
            ),
            _SheetAction(
              icon: Icons.point_of_sale_outlined,
              label: 'Sell item',
              onTap: () {
                Navigator.pop(sheetContext);
                widget.controller.beginSaleWithItem(item);
              },
            ),
            _SheetAction(
              icon: Icons.history,
              label: 'View history',
              onTap: () {
                Navigator.pop(sheetContext);
                showItemHistoryDialog(context, widget.controller, item);
              },
            ),
            _SheetAction(
              icon: Icons.delete_outline,
              label: 'Delete',
              destructive: true,
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncFromController();
    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 1100;
        final compact = constraints.maxWidth < 600;
        final padding = expanded ? 24.0 : compact ? 12.0 : 18.0;

        if (expanded) {
          return SingleChildScrollView(
            controller: _pageScroll,
            padding: EdgeInsets.all(padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 360, child: _buildForm(context, fillHeight: false, compact: false)),
                const SizedBox(width: 20),
                Expanded(child: _buildInventory(context, bounded: false, useTable: true, compact: false)),
              ],
            ),
          );
        }

        return ListView(
          controller: _pageScroll,
          padding: EdgeInsets.all(padding),
          children: [
            _buildForm(context, fillHeight: false, compact: compact),
            const SizedBox(height: 14),
            _buildInventory(context, bounded: false, useTable: false, compact: compact),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildForm(BuildContext context, {required bool fillHeight, required bool compact}) {
    final selected = widget.controller.selectedItem;
    final fields = LayoutBuilder(
      builder: (context, box) {
        final twoColumns = !compact && box.maxWidth >= 520;
        final fieldWidth = twoColumns ? (box.maxWidth - 12) / 2 : box.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Item Name', prefixIcon: Icon(Icons.inventory_2_outlined)),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: DropdownButtonFormField<String>(
                initialValue: widget.controller.categories.any((c) => c.name == _category) ? _category : null,
                key: ValueKey('category-${_category ?? ''}-${widget.controller.categories.length}'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                items: widget.controller.categories
                    .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)),
              ),
            ),
            SizedBox(
              width: fieldWidth,
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Unit Price (PHP)', prefixIcon: Icon(Icons.payments_outlined)),
              ),
            ),
            SizedBox(
              width: box.maxWidth,
              child: TextField(
                controller: _reorder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reorder Threshold', prefixIcon: Icon(Icons.notification_important_outlined)),
              ),
            ),
          ],
        );
      },
    );

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fields,
          const SizedBox(height: 16),
          Container(
            height: 96,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: selected?.sku.isNotEmpty == true
                ? BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: selected!.sku,
                    drawText: true,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                : Center(
                    child: Text(
                      'Select an item to preview its barcode.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: selected == null ? () => _save(update: false) : () => _save(update: true),
            icon: Icon(selected == null ? Icons.add : Icons.save_outlined),
            label: Text(selected == null ? 'Add Item' : 'Save Changes'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _clearForm,
            icon: const Icon(Icons.refresh),
            label: Text(selected == null ? 'Reset Form' : 'Cancel Editing'),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected == null ? 'Add New Item' : 'Edit Inventory Item',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  selected == null
                      ? 'Add stock using a simple mobile-friendly form.'
                      : 'Editing ${selected.name}. Save changes or cancel to start a new item.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (fillHeight) Expanded(child: body) else body,
        ],
      ),
    );
  }

  Widget _buildInventory(
    BuildContext context, {
    required bool bounded,
    required bool useTable,
    required bool compact,
  }) {
    final content = widget.controller.inventoryPage.items.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(child: Text('No inventory items found.')),
          )
        : useTable
            ? _desktopTable(context)
            : _mobileList(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _inventoryTitle(context),
                    const SizedBox(height: 12),
                    _searchField(),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _inventoryTitle(context)),
                    if (widget.controller.selectedItem != null) ...[
                      OutlinedButton.icon(
                        onPressed: () => widget.controller.beginSaleWithItem(widget.controller.selectedItem!),
                        icon: const Icon(Icons.point_of_sale_outlined),
                        label: const Text('Sell selected'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    SizedBox(width: 320, child: _searchField()),
                  ],
                ),
        ),
        const Divider(height: 1),
        if (bounded) Expanded(child: content) else content,
        const Divider(height: 1),
        _pagination(context, compact: compact),
      ],
    );

    return Card(clipBehavior: Clip.antiAlias, child: body);
  }

  Widget _inventoryTitle(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inventory', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${widget.controller.inventoryPage.total} item(s) matched', style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  Widget _searchField() => TextField(
        controller: _search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search inventory',
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _search.clear();
                    widget.controller.setInventorySearch('');
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
        onChanged: (value) {
          widget.controller.setInventorySearch(value);
          setState(() {});
        },
      );

  Widget _pagination(BuildContext context, {required bool compact}) {
    final previousEnabled = widget.controller.inventoryPageIndex > 0;
    final nextEnabled = (widget.controller.inventoryPageIndex + 1) * 50 < widget.controller.inventoryPage.total;
    final label = 'Page ${widget.controller.inventoryPageIndex + 1} of ${widget.controller.inventoryTotalPages}';

    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: previousEnabled ? widget.controller.inventoryPrev : null,
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: nextEnabled ? widget.controller.inventoryNext : null,
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text('$label · ${widget.controller.inventoryPage.total} total', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: previousEnabled ? widget.controller.inventoryPrev : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: nextEnabled ? widget.controller.inventoryNext : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _desktopTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Item ID'), numeric: true),
            DataColumn(label: Text('SKU')),
            DataColumn(label: Text('Product')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Quantity'), numeric: true),
            DataColumn(label: Text('Unit Price'), numeric: true),
          ],
          rows: widget.controller.inventoryPage.items.map((item) {
            final lowStyle = item.isLowStock
                ? TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)
                : null;
            return DataRow(
              selected: widget.controller.selectedItem?.id == item.id,
              onSelectChanged: (_) => widget.controller.selectItem(item),
              cells: [
                DataCell(Text('#INV-${item.id.toString().padLeft(5, '0')}')),
                DataCell(Text(item.sku)),
                DataCell(SizedBox(width: 200, child: Text(item.name, overflow: TextOverflow.ellipsis))),
                DataCell(Text(item.category)),
                DataCell(Text('${item.quantity}', style: lowStyle)),
                DataCell(Text('₱ ${item.unitPrice.toStringAsFixed(2)}')),
              ],
            );
          }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _mobileList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: widget.controller.inventoryPage.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = widget.controller.inventoryPage.items[index];
        final selected = widget.controller.selectedItem?.id == item.id;
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: selected ? scheme.secondaryContainer.withValues(alpha: .5) : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.controller.selectItem(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.isLowStock ? scheme.errorContainer : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: item.isLowStock ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(item.sku, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _InfoPill(icon: Icons.category_outlined, text: item.category),
                            _InfoPill(icon: Icons.payments_outlined, text: '₱${item.unitPrice.toStringAsFixed(2)}'),
                            if (item.isLowStock) _InfoPill(icon: Icons.warning_amber_rounded, text: 'Low stock', alert: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showItemActions(item),
                    tooltip: 'Item actions',
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      minTileHeight: 52,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, this.alert = false});
  final IconData icon;
  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: alert ? scheme.errorContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: alert ? scheme.error : scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: alert ? scheme.error : scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
