import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';
import '../widgets/stock_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final SmartStockController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _category = TextEditingController(), _hex = TextEditingController();
  String _categorySearch = '';
  String? _hexError;
  SmartStockTheme _light = SmartStockTheme.defaultLight,
      _dark = SmartStockTheme.dark;
  @override
  void dispose() {
    _category.dispose();
    _hex.dispose();
    super.dispose();
  }

  bool get _isDark =>
      widget.controller.theme == SmartStockTheme.dark ||
      widget.controller.theme == SmartStockTheme.blueSteel;
  void _theme(SmartStockTheme next) {
    final accent = widget.controller.customAccent;
    if (_isDark) {
      _dark = widget.controller.theme;
    } else {
      _light = widget.controller.theme;
    }
    widget.controller.applyTheme(next);
    if (accent != null) widget.controller.setAccent(accent);
  }

  void _applyHex() {
    final raw = _hex.text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) {
      setState(() => _hexError = 'Enter a six-digit color, such as #2457C5.');
      return;
    }
    setState(() => _hexError = null);
    widget.controller.setAccent(Color(int.parse('FF$raw', radix: 16)));
  }

  Future<void> _pick() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (_) => _RgbPicker(
        initial:
            widget.controller.customAccent ??
            Theme.of(context).colorScheme.primary,
      ),
    );
    if (color != null && mounted) {
      _hex.text =
          '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
      setState(() => _hexError = null);
      widget.controller.setAccent(color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final categories = controller.categories
        .where((c) => c.name.toLowerCase().contains(_categorySearch))
        .toList();
    return ListView(
      key: const PageStorageKey('settings-scroll'),
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        _Section(
          title: 'Data and backup',
          children: [
            const Text(
              'Save a backup before replacing your inventory database.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TaskButton(
                  label: 'Backup Database',
                  icon: Icons.backup_outlined,
                  savedFile: true,
                  action: controller.backupDatabase,
                ),
                TaskButton(
                  label: 'Import Legacy .db',
                  icon: Icons.move_to_inbox_outlined,
                  action: () async {
                    if (!await showSmartConfirm(
                      context,
                      title: 'Replace database?',
                      confirmLabel: 'Choose database',
                      destructive: false,
                      message:
                          'Choose a plaintext SmartStock backup. It replaces the current database, including inventory, suppliers, and audit history.',
                    )) {
                      return null;
                    }
                    if (!context.mounted) return null;
                    final imported = await controller.importLegacyDatabase();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            imported
                                ? 'Database imported.'
                                : 'Import cancelled.',
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ],
            ),
            const Text(
              'Database encryption is applied after a clean shutdown.',
            ),
          ],
        ),
        _Section(
          title: 'Appearance',
          children: [
            const Text(
              'Appearance choices last for this app session. Very light or dark accents are adjusted for readable text.',
            ),
            DropdownButtonFormField<SmartStockTheme>(
              initialValue: controller.theme,
              key: ValueKey(controller.theme),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Theme'),
              items: SmartStockTheme.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) {
                if (t != null) _theme(t);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark mode'),
              value: _isDark,
              onChanged: (dark) => _theme(dark ? _dark : _light),
            ),
            TextField(
              controller: _hex,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Accent color',
                hintText: '#2457C5',
                errorText: _hexError,
              ),
              onSubmitted: (_) => _applyHex(),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _applyHex,
                  child: const Text('Apply accent'),
                ),
                OutlinedButton(
                  onPressed: _pick,
                  child: const Text('Pick color'),
                ),
                TextButton(
                  onPressed: () {
                    _hex.clear();
                    setState(() => _hexError = null);
                    controller.setAccent(null);
                  },
                  child: const Text('Reset accent'),
                ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Categories',
          children: [
            TextField(
              controller: _category,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'New Category'),
            ),
            TaskButton(
              label: 'Add Category',
              icon: Icons.add,
              action: () async {
                if (_category.text.trim().isEmpty) {
                  throw ArgumentError('Enter a category name.');
                }
                await controller.addCategory(_category.text.trim());
                if (mounted) _category.clear();
                return null;
              },
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search categories',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _categorySearch = value.trim().toLowerCase()),
            ),
            if (categories.isEmpty) const Text('No matching categories.'),
            for (final category in categories)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(category.name),
                  TaskButton(
                    label: 'Remove ${category.name}',
                    icon: Icons.remove_circle_outline,
                    action: () async {
                      if (!await showSmartConfirm(
                        context,
                        title: 'Remove category',
                        message:
                            "Remove '${category.name}'? Categories still used by inventory cannot be removed.",
                        confirmLabel: 'Remove',
                      )) {
                        return null;
                      }
                      await controller.removeCategory(category.name);
                      return null;
                    },
                  ),
                ],
              ),
          ],
        ),
        _Section(
          title: 'Clear inventory',
          children: [
            const Text(
              'Deletes every inventory item and records each deletion in the Audit Log. Categories, suppliers, and existing audit history are kept.',
            ),
            TaskButton(
              label: 'Clear inventory',
              icon: Icons.delete_forever,
              action: () async {
                if (!await showSmartConfirm(
                  context,
                  title: 'Clear inventory?',
                  message:
                      'Delete every inventory item? Categories, suppliers, and audit history are kept. Each deletion is recorded.',
                  confirmLabel: 'Continue',
                )) {
                  return null;
                }
                if (!context.mounted) return null;
                if (!await showSmartConfirm(
                  context,
                  title: 'Delete all inventory items?',
                  message:
                      'This removes all current stock items. Make sure you have a backup you can restore.',
                  confirmLabel: 'Clear inventory',
                )) {
                  return null;
                }
                await controller.resetInventory();
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            for (final child in children) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    ),
  );
}

class _RgbPicker extends StatefulWidget {
  const _RgbPicker({required this.initial});
  final Color initial;
  @override
  State<_RgbPicker> createState() => _RgbPickerState();
}

class _RgbPickerState extends State<_RgbPicker> {
  late double _r = widget.initial.r * 255,
      _g = widget.initial.g * 255,
      _b = widget.initial.b * 255;
  Color get _color => Color.fromARGB(255, _r.round(), _g.round(), _b.round());
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Pick accent color'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Selected color preview',
            child: Container(height: 48, color: _color),
          ),
          _slider('Red', _r, (v) => setState(() => _r = v)),
          _slider('Green', _g, (v) => setState(() => _g = v)),
          _slider('Blue', _b, (v) => setState(() => _b = v)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _color),
        child: const Text('Use color'),
      ),
    ],
  );
  Widget _slider(String label, double value, ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$label: ${value.round()}'),
          Semantics(
            label: label,
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              divisions: 255,
              semanticFormatterCallback: (v) => '$label ${v.round()} of 255',
              onChanged: onChanged,
            ),
          ),
        ],
      );
}
