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

  Future<void> _edit([SupplierRecord? item]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _SupplierEditor(controller: widget.controller, item: item),
    ),
  );

  Future<void> _details(SupplierRecord item) async {
    final theme = Theme.of(context);
    final edit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Row(
          children: [
            _SupplierAvatar(name: item.name),
            const SizedBox(width: 12),
            Expanded(child: Text(item.name)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: item.email.isEmpty ? 'Not provided' : item.email,
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: item.phone.isEmpty ? 'Not provided' : item.phone,
              ),
              _DetailRow(
                icon: Icons.notes_outlined,
                label: 'Notes',
                value: item.notes.isEmpty ? 'None' : item.notes,
              ),
              const SizedBox(height: 4),
              Text(
                'Supplier records are contact references only and do not change inventory quantities.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Suppliers', style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.controller.suppliers.length} contact ${widget.controller.suppliers.length == 1 ? 'record' : 'records'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _edit(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Supplier'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search supplier, email, phone…',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) => setState(
                          () => _search = value.trim().toLowerCase(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _descending ? 'Sort A to Z' : 'Sort Z to A',
                      onPressed: () =>
                          setState(() => _descending = !_descending),
                      icon: const Icon(Icons.sort_by_alpha),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Refresh suppliers',
                      onPressed: () => widget.controller.refreshSuppliers(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (items.isEmpty) ...[
                  const SizedBox(height: 12),
                  EmptyMessage(
                    title: widget.controller.suppliers.isEmpty
                        ? 'No suppliers yet'
                        : 'No matching suppliers',
                    message: widget.controller.suppliers.isEmpty
                        ? 'Add a supplier to keep their contact details here.'
                        : 'Try another company name, email, or phone number.',
                  ),
                ],
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
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _details(item),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SupplierAvatar(name: item.name),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 5),
                                if (item.email.isNotEmpty)
                                  _CompactMeta(
                                    icon: Icons.email_outlined,
                                    text: item.email,
                                  ),
                                if (item.phone.isNotEmpty)
                                  _CompactMeta(
                                    icon: Icons.phone_outlined,
                                    text: item.phone,
                                  ),
                                if (item.notes.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.notes,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'View contact details',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
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
  bool _dirty = false;
  bool _busy = false;
  bool _leave = false;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier saved.')),
        );
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _SupplierAvatar(
                              name: _name.text.trim().isEmpty
                                  ? 'Supplier'
                                  : _name.text,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.item == null
                                        ? 'New supplier contact'
                                        : 'Supplier contact',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Store contact details without changing inventory quantities.',
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
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Contact information', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Company Name',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter the company name.'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _email,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email (optional)',
                                prefixIcon: Icon(Icons.email_outlined),
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phone,
                              enabled: !_busy,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone (optional)',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notes,
                              enabled: !_busy,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                labelText: 'Notes (optional)',
                                alignLabelWithHint: true,
                                prefixIcon: Icon(Icons.notes_outlined),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_busy ? 'Saving…' : 'Save supplier'),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _busy ? null : _close,
                      child: const Text('Cancel'),
                    ),
                    if (widget.item != null) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _delete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        label: Text(
                          'Delete supplier',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupplierAvatar extends StatelessWidget {
  const _SupplierAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _CompactMeta extends StatelessWidget {
  const _CompactMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
