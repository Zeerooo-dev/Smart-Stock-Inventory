import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _search = TextEditingController();
  final _notes = TextEditingController();
  Timer? _searchDebounce;
  final _currency = NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _search.text = widget.controller.saleSearch;
    if (widget.controller.saleSearchResults.isEmpty) {
      unawaited(widget.controller.refreshSales());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 180),
      () => unawaited(widget.controller.setSaleSearch(value)),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
    );
  }

  Future<void> _addItem(InventoryItem item) async {
    try {
      await widget.controller.addSaleItem(item);
    } catch (e) {
      _showError(e);
    }
  }

  void _setQuantity(SaleCartLine line, int quantity) {
    try {
      widget.controller.setSaleCartQuantity(line.item.id, quantity);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _completeSale() async {
    if (widget.controller.saleCart.isEmpty) {
      _showError('Add at least one product to the cart.');
      return;
    }

    final ok = await showSmartConfirm(
      context,
      title: 'Complete Sale',
      destructive: false,
      confirmLabel: 'Complete Sale',
      message:
          'Complete this sale for ${widget.controller.saleCartUnits} unit(s) totaling ${_currency.format(widget.controller.saleCartTotal)}?\n\nInventory will be deducted automatically and an immutable SALE audit entry will be written for each product.',
    );
    if (!ok) return;

    try {
      final sale = await widget.controller.completeSale(notes: _notes.text);
      _notes.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sale.saleNumber} completed successfully.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showSale(SaleRecord sale) async {
    try {
      final detail = await widget.controller.getSaleDetail(sale.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _SaleDetailDialog(
          detail: detail,
          currency: _currency,
          onVoid: detail.sale.isVoided ? null : () => _voidSale(detail.sale),
        ),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _voidSale(SaleRecord sale) async {
    Navigator.of(context).pop();
    final ok = await showSmartConfirm(
      context,
      title: 'Void Sale',
      confirmLabel: 'Void Sale',
      message:
          'Void ${sale.saleNumber}?\n\nEvery product quantity from this sale will be restored atomically. The sale will remain in history as VOIDED and rollback-reversal audit entries will be recorded.',
    );
    if (!ok) return;
    try {
      await widget.controller.voidSale(sale);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final desktop = constraints.maxWidth >= 1100;
        final padding = desktop ? 24.0 : compact ? 12.0 : 18.0;

        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            _pageHeader(context, compact: compact),
            const SizedBox(height: 16),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _productBrowser(context)),
                  const SizedBox(width: 18),
                  SizedBox(width: 430, child: _cartCard(context)),
                ],
              )
            else ...[
              _productBrowser(context),
              const SizedBox(height: 14),
              _cartCard(context),
            ],
            const SizedBox(height: 18),
            _recentSales(context),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _pageHeader(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleBlock(context),
                  const SizedBox(height: 12),
                  _scannerHint(context),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _titleBlock(context)),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _scannerHint(context),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _titleBlock(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales · Quick Checkout',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Search or scan products, build a cart, and complete the sale. Stock is deducted automatically through the Stock Movement Service.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );

  Widget _scannerHint(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner_rounded, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Hardware barcode scanners add directly to this cart',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _productBrowser(BuildContext context) {
    final results = widget.controller.saleSearchResults;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'Search by item name, category, or SKU.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _search,
              onChanged: (value) {
                setState(() {});
                _onSearchChanged(value);
              },
              onSubmitted: (value) async {
                try {
                  final added = await widget.controller.tryAddSaleSearch(value);
                  if (added) {
                    _search.clear();
                    if (mounted) setState(() {});
                  }
                } catch (e) {
                  _showError(e);
                }
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search products',
                hintText: 'Name, category, or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? const Icon(Icons.qr_code_2)
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    const Text('No products match this search.'),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 900 ? 3 : box.maxWidth >= 540 ? 2 : 1;
                  final gap = 10.0;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final item in results)
                        SizedBox(
                          width: width,
                          child: _ProductTile(
                            item: item,
                            currency: _currency,
                            onAdd: item.quantity > 0 ? () => _addItem(item) : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _cartCard(BuildContext context) {
    final cart = widget.controller.saleCart;
    final busy = widget.controller.saleBusy;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Current Sale', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: busy ? null : widget.controller.clearSaleCart,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            Text(
              '${widget.controller.saleCartUnits} unit(s)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (cart.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 34),
                    SizedBox(height: 8),
                    Text('Your sale cart is empty.', textAlign: TextAlign.center),
                    SizedBox(height: 4),
                    Text('Add a product or scan its barcode to begin.', textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...cart.map((line) => _CartLine(
                    line: line,
                    currency: _currency,
                    onDecrease: busy ? null : () => _setQuantity(line, line.quantity - 1),
                    onIncrease: busy || line.quantity >= line.item.quantity
                        ? null
                        : () => _setQuantity(line, line.quantity + 1),
                    onRemove: busy ? null : () => widget.controller.removeSaleCartItem(line.item.id),
                  )),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 3,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Sale note (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800))),
                  Text(
                    _currency.format(widget.controller.saleCartTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: cart.isEmpty || busy ? null : _completeSale,
              icon: busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.point_of_sale),
              label: Text(busy ? 'Completing…' : 'Complete Sale'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentSales(BuildContext context) {
    final sales = widget.controller.recentSales;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Sales', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        'Completed and voided checkout transactions stay here for traceability.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh sales',
                  onPressed: widget.controller.saleBusy ? null : () => widget.controller.refreshSales(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (sales.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No sales recorded yet.', textAlign: TextAlign.center),
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 950 ? 3 : box.maxWidth >= 620 ? 2 : 1;
                  final gap = 10.0;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final sale in sales)
                        SizedBox(
                          width: width,
                          child: _SaleSummaryTile(
                            sale: sale,
                            currency: _currency,
                            onTap: () => _showSale(sale),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.item,
    required this.currency,
    required this.onAdd,
  });

  final InventoryItem item;
  final NumberFormat currency;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outOfStock = item.quantity <= 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(item.sku, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _SmallBadge(text: item.category),
                _SmallBadge(text: outOfStock ? 'Out of stock' : '${item.quantity} in stock', error: outOfStock),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(currency.format(item.unitPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.line,
    required this.currency,
    this.onDecrease,
    this.onIncrease,
    this.onRemove,
  });

  final SaleCartLine line;
  final NumberFormat currency;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${currency.format(line.item.unitPrice)} each · ${line.item.quantity} available', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(tooltip: 'Remove', onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton.filledTonal(onPressed: onDecrease, icon: const Icon(Icons.remove)),
              SizedBox(
                width: 44,
                child: Text('${line.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
              IconButton.filledTonal(onPressed: onIncrease, icon: const Icon(Icons.add)),
              const Spacer(),
              Text(currency.format(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaleSummaryTile extends StatelessWidget {
  const _SaleSummaryTile({required this.sale, required this.currency, required this.onTap});

  final SaleRecord sale;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(sale.saleNumber, style: const TextStyle(fontWeight: FontWeight.w900))),
                _SmallBadge(text: sale.isVoided ? 'VOIDED' : 'COMPLETED', error: sale.isVoided),
              ],
            ),
            const SizedBox(height: 8),
            Text('${sale.totalItems} unit(s)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 3),
            Text(sale.timestamp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(
              currency.format(sale.totalAmount),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    decoration: sale.isVoided ? TextDecoration.lineThrough : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDetailDialog extends StatelessWidget {
  const _SaleDetailDialog({
    required this.detail,
    required this.currency,
    required this.onVoid,
  });

  final SaleDetail detail;
  final NumberFormat currency;
  final VoidCallback? onVoid;

  @override
  Widget build(BuildContext context) {
    final sale = detail.sale;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      title: Row(
        children: [
          Expanded(child: Text(sale.saleNumber)),
          _SmallBadge(text: sale.isVoided ? 'VOIDED' : 'COMPLETED', error: sale.isVoided),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(sale.timestamp, style: Theme.of(context).textTheme.bodySmall),
              if (sale.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Note: ${sale.notes}'),
              ],
              const SizedBox(height: 14),
              ...detail.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.itemName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${line.sku} · ${line.quantity} × ${currency.format(line.unitPrice)}', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(currency.format(line.subtotal), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(child: Text('${sale.totalItems} unit(s)')),
                  Text(currency.format(sale.totalAmount), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
              if (sale.isVoided && sale.voidedAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Voided: ${sale.voidedAt}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (onVoid != null)
          FilledButton.tonalIcon(
            onPressed: onVoid,
            icon: const Icon(Icons.undo),
            label: const Text('Void Sale'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: error ? scheme.onErrorContainer : scheme.onSecondaryContainer,
            ),
      ),
    );
  }
}
