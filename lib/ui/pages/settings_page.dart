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
  final _category = TextEditingController();
  final _hex = TextEditingController();
  String _categorySearch = '';
  String? _hexError;
  SmartStockTheme _light = SmartStockTheme.defaultLight;
  SmartStockTheme _dark = SmartStockTheme.dark;

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
    final theme = Theme.of(context);
    final categories = controller.categories
        .where((c) => c.name.toLowerCase().contains(_categorySearch))
        .toList();

    return ListView(
      key: const PageStorageKey('settings-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Settings', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Backup, appearance, categories, and inventory controls.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        const _SectionLabel('DATA & BACKUP'),
        _SettingsCard(
          children: [
            _SettingsIntro(
              icon: Icons.shield_outlined,
              title: 'Database protection',
              message:
                  'Save a backup before replacing your inventory database. Encryption is applied after a clean shutdown.',
            ),
            const Divider(height: 24),
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
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('APPEARANCE'),
        _SettingsCard(
          children: [
            DropdownButtonFormField<SmartStockTheme>(
              initialValue: controller.theme,
              key: ValueKey(controller.theme),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Theme',
                prefixIcon: Icon(Icons.palette_outlined),
              ),
              items: SmartStockTheme.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (t) {
                if (t != null) _theme(t);
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const _LeadingIcon(Icons.dark_mode_outlined),
              title: const Text('Dark mode'),
              subtitle: const Text('Switch between the paired light and dark themes.'),
              value: _isDark,
              onChanged: (dark) => _theme(dark ? _dark : _light),
            ),
            const Divider(height: 24),
            Text(
              'Accent color',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Very light or dark accents are adjusted automatically to keep text readable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hex,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Accent color',
                hintText: '#2457C5',
                prefixIcon: const Icon(Icons.colorize_outlined),
                errorText: _hexError,
              ),
              onSubmitted: (_) => _applyHex(),
            ),
            const SizedBox(height: 10),
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
        const SizedBox(height: 18),
        const _SectionLabel('CATEGORIES'),
        _SettingsCard(
          children: [
            TextField(
              controller: _category,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'New Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TaskButton(
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
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search categories',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _categorySearch = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No matching categories.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final category in categories)
              _CategoryRow(
                name: category.name,
                onRemove: () async {
                  if (!await showSmartConfirm(
                    context,
                    title: 'Remove category',
                    message:
                        "Remove '${category.name}'? Categories still used by inventory cannot be removed.",
                    confirmLabel: 'Remove',
                  )) {
                    return;
                  }
                  await controller.removeCategory(category.name);
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('DANGER ZONE'),
        _SettingsCard(
          children: [
            _SettingsIntro(
              icon: Icons.delete_forever_outlined,
              iconColor: theme.colorScheme.error,
              title: 'Clear inventory',
              message:
                  'Deletes every inventory item and records each deletion in the Audit Log. Categories, suppliers, and existing audit history are kept.',
            ),
            const SizedBox(height: 12),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: .8,
      ),
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LeadingIcon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground, size: 20),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.name, required this.onRemove});

  final String name;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.sell_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
          IconButton(
            tooltip: 'Remove $name',
            onPressed: onRemove,
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.error,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _RgbPicker extends StatefulWidget {
  const _RgbPicker({required this.initial});

  final Color initial;

  @override
  State<_RgbPicker> createState() => _RgbPickerState();
}

class _RgbPickerState extends State<_RgbPicker> {
  late double _r = widget.initial.r * 255;
  late double _g = widget.initial.g * 255;
  late double _b = widget.initial.b * 255;

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
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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
