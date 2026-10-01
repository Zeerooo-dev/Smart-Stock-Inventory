import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key, required this.controller});
  final SmartStockController controller;
  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  String _search = '';
  bool _descending = false;
  Future<void> _edit([SupplierRecord? item]) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              _SupplierEditor(controller: widget.controller, item: item),
        ),
      );
  Future<void> _details(SupplierRecord item) async {
    final edit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(item.name),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                'Email: ${item.email.isEmpty ? 'Not provided' : item.email}',
              ),
              const SizedBox(height: 12),
              SelectableText(
                'Phone: ${item.phone.isEmpty ? 'Not provided' : item.phone}',
              ),
              const SizedBox(height: 12),
              SelectableText(
                'Notes: ${item.notes.isEmpty ? 'None' : item.notes}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Edit supplier'),
          ),
        ],
      ),
    );
    if (edit == true && mounted) await _edit(item);
  }

  @override
  Widget build(BuildContext context) {
    final items =
        widget.controller.suppliers
            .where(
              (item) => '${item.name} ${item.email} ${item.phone} ${item.notes}'
                  .toLowerCase()
                  .contains(_search),
            )
            .toList()
          ..sort(
            (a, b) =>
                (_descending ? -1 : 1) *
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return CustomScrollView(
      key: const PageStorageKey('supplier-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Suppliers',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search suppliers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Supplier'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _descending = !_descending),
                      icon: const Icon(Icons.sort_by_alpha),
                      label: Text(_descending ? 'Name Z to A' : 'Name A to Z'),
                    ),
                    TaskButton(
                      label: 'Refresh suppliers',
                      icon: Icons.refresh,
                      action: () async {
                        await widget.controller.refreshSuppliers();
                        return null;
                      },
                    ),
                  ],
                ),
                if (items.isEmpty)
                  EmptyMessage(
                    title: widget.controller.suppliers.isEmpty
                        ? 'No suppliers yet'
                        : 'No matching suppliers',
                    message: widget.controller.suppliers.isEmpty
                        ? 'Add a supplier to keep their contact details here.'
                        : 'Try another company name, email, or phone number.',
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: InkWell(
                    onTap: () => _details(item),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (item.email.isNotEmpty) Text(item.email),
                          if (item.phone.isNotEmpty) Text(item.phone),
                          if (item.notes.isNotEmpty)
                            Text(
                              item.notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const Text('View contact details'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  const _SupplierEditor({required this.controller, this.item});
  final SmartStockController controller;
  final SupplierRecord? item;
  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late final _email = TextEditingController(text: widget.item?.email ?? '');
  late final _phone = TextEditingController(text: widget.item?.phone ?? '');
  late final _notes = TextEditingController(text: widget.item?.notes ?? '');
  bool _dirty = false, _busy = false, _leave = false;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pop() {
    setState(() {
      _leave = true;
      _busy = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _close() async {
    if (_busy) return;
    if (_dirty &&
        !await showSmartConfirm(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved supplier changes will be lost.',
          confirmLabel: 'Discard',
          destructive: false,
        )) {
      return;
    }
    if (mounted) _pop();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.saveSupplier(
        id: widget.item?.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        notes: _notes.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Supplier saved.')));
        _pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || widget.item == null) return;
    if (!await showSmartConfirm(
      context,
      title: 'Delete supplier',
      confirmLabel: 'Delete supplier',
      message:
          "Delete '${widget.item!.name}' and its contact details? Inventory and audit history are kept.",
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.deleteSupplier(widget.item!);
      if (mounted) _pop();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _leave || (!_dirty && !_busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Supplier' : 'Edit supplier'),
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
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the company name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                    validator: (value) =>
                        value != null &&
                            value.trim().isNotEmpty &&
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(value.trim())
                        ? 'Enter a valid email address.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    enabled: !_busy,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notes,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
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
                    child: Text(_busy ? 'Saving…' : 'Save supplier'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _close,
                    child: const Text('Cancel'),
                  ),
                  if (widget.item != null)
                    OutlinedButton(
                      onPressed: _busy ? null : _delete,
                      child: const Text('Delete supplier'),
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
