import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key, required this.controller});
  final SmartStockController controller;

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _pageScroll = ScrollController();
  int? _loadedSupplier;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _sync() {
    final supplier = widget.controller.selectedSupplier;
    if (supplier?.id == _loadedSupplier) return;
    _loadedSupplier = supplier?.id;
    _name.text = supplier?.name ?? '';
    _email.text = supplier?.email ?? '';
    _phone.text = supplier?.phone ?? '';
    _notes.text = supplier?.notes ?? '';
  }

  void _clear() {
    widget.controller.selectSupplier(null);
    _loadedSupplier = null;
    _name.clear();
    _email.clear();
    _phone.clear();
    _notes.clear();
    setState(() {});
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _save() async {
    try {
      await widget.controller.saveSupplier(
        id: widget.controller.selectedSupplier?.id,
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
        notes: _notes.text,
      );
      _clear();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _delete([SupplierRecord? target]) async {
    final supplier = target ?? widget.controller.selectedSupplier;
    if (supplier == null) return;
    final ok = await showSmartConfirm(
      context,
      message: "Delete supplier '${supplier.name}'?\n\nLinked ledger entries will lose their supplier reference.",
    );
    if (!ok) return;
    try {
      await widget.controller.deleteSupplier(supplier);
      _clear();
    } catch (e) {
      _error(e);
    }
  }

  void _edit(SupplierRecord supplier) {
    widget.controller.selectSupplier(supplier);
    if (_pageScroll.hasClients) {
      _pageScroll.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final expanded = constraints.maxWidth >= 1100;
        final padding = expanded ? 24.0 : compact ? 12.0 : 18.0;
        final form = _SupplierForm(
          fillHeight: expanded,
          name: _name,
          email: _email,
          phone: _phone,
          notes: _notes,
          editing: widget.controller.selectedSupplier != null,
          onSave: _save,
          onClear: _clear,
          onDelete: () => _delete(),
        );

        if (expanded) {
          return SingleChildScrollView(
            controller: _pageScroll,
            padding: EdgeInsets.all(padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: _SupplierForm(
                    fillHeight: false,
                    name: _name,
                    email: _email,
                    phone: _phone,
                    notes: _notes,
                    editing: widget.controller.selectedSupplier != null,
                    onSave: _save,
                    onClear: _clear,
                    onDelete: () => _delete(),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _SupplierDirectory(
                    controller: widget.controller,
                    useTable: true,
                    bounded: false,
                    onEdit: _edit,
                    onDelete: _delete,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          controller: _pageScroll,
          padding: EdgeInsets.all(padding),
          children: [
            form,
            const SizedBox(height: 14),
            _SupplierDirectory(
              controller: widget.controller,
              useTable: false,
              bounded: false,
              onEdit: _edit,
              onDelete: _delete,
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _SupplierForm extends StatelessWidget {
  const _SupplierForm({
    required this.fillHeight,
    required this.name,
    required this.email,
    required this.phone,
    required this.notes,
    required this.editing,
    required this.onSave,
    required this.onClear,
    required this.onDelete,
  });

  final bool fillHeight;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController phone;
  final TextEditingController notes;
  final bool editing;
  final VoidCallback onSave;
  final VoidCallback onClear;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Company Name', prefixIcon: Icon(Icons.business_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notes,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true, prefixIcon: Icon(Icons.notes_outlined)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSave,
            icon: Icon(editing ? Icons.save_outlined : Icons.add_business),
            label: Text(editing ? 'Save Supplier' : 'Add Supplier'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh),
            label: Text(editing ? 'Cancel Editing' : 'Reset Form'),
          ),
          if (editing) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Supplier'),
            ),
          ],
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Edit Supplier' : 'Add Supplier', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Maintain supplier contact details in one place.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (fillHeight) Expanded(child: body) else body,
        ],
      ),
    );
  }
}

class _SupplierDirectory extends StatelessWidget {
  const _SupplierDirectory({
    required this.controller,
    required this.useTable,
    required this.bounded,
    required this.onEdit,
    required this.onDelete,
  });

  final SmartStockController controller;
  final bool useTable;
  final bool bounded;
  final ValueChanged<SupplierRecord> onEdit;
  final ValueChanged<SupplierRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final content = controller.suppliers.isEmpty
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(child: Text('No suppliers yet.')),
          )
        : useTable
            ? _table(context)
            : _cards(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Supplier Directory', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${controller.suppliers.length} supplier record(s)', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          if (bounded) Expanded(child: content) else content,
        ],
      ),
    );
  }

  Widget _table(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Supplier ID'), numeric: true),
                DataColumn(label: Text('Company Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('Notes')),
              ],
              rows: controller.suppliers
                  .map(
                    (supplier) => DataRow(
                      selected: controller.selectedSupplier?.id == supplier.id,
                      onSelectChanged: (_) => onEdit(supplier),
                      cells: [
                        DataCell(Text('#SUP-${supplier.id.toString().padLeft(4, '0')}')),
                        DataCell(SizedBox(width: 180, child: Text(supplier.name, overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 180, child: Text(supplier.email, overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 130, child: Text(supplier.phone, overflow: TextOverflow.ellipsis))),
                        DataCell(SizedBox(width: 220, child: Text(supplier.notes, overflow: TextOverflow.ellipsis))),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );

  Widget _cards(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(10),
      itemCount: controller.suppliers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final supplier = controller.suppliers[index];
        final selected = controller.selectedSupplier?.id == supplier.id;
        return Material(
          color: selected ? scheme.secondaryContainer.withValues(alpha: .5) : scheme.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onEdit(supplier),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.business_outlined, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (supplier.email.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(supplier.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                        if (supplier.phone.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(supplier.phone, style: Theme.of(context).textTheme.bodySmall),
                        ],
                        if (supplier.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(supplier.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Supplier actions',
                    onSelected: (value) {
                      if (value == 'edit') onEdit(supplier);
                      if (value == 'delete') onDelete(supplier);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                    ],
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
