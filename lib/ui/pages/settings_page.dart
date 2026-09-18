import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../state/smartstock_controller.dart';
import '../widgets/dialogs.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final SmartStockController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _category = TextEditingController();
  final _hex = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _category.dispose();
    _hex.dispose();
    super.dispose();
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Color? _parseHex(String raw) {
    final value = raw.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(value)) return null;
    return Color(int.parse('FF$value', radix: 16));
  }

  String _toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _pickAccent() async {
    final initial =
        widget.controller.customAccent ?? Theme.of(context).colorScheme.primary;
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _RgbPicker(initial: initial),
    );
    if (picked != null) {
      _hex.text = _toHex(picked);
      widget.controller.setAccent(picked);
      setState(() {});
    }
  }

  Future<void> _resetInventory() async {
    final first = await showSmartConfirm(
      context,
      title: 'Reset All Inventory',
      message:
          'WARNING\n\nThis will permanently delete every inventory item.\nCategories will be kept.',
      confirmLabel: 'Continue',
    );
    if (!first || !mounted) return;
    final second = await showSmartConfirm(
      context,
      title: 'Final Confirmation',
      message:
          'This is the final confirmation. Delete all inventory items now?',
      confirmLabel: 'Reset All Data',
    );
    if (!second) return;
    try {
      await widget.controller.resetInventory();
    } catch (e) {
      _error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final expanded = constraints.maxWidth >= 1100;
        final padding = expanded
            ? 28.0
            : compact
            ? 12.0
            : 18.0;

        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            Text(
              'System Settings',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage data, appearance, categories, and local storage.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Data & Backup',
              subtitle:
                  'Local SQLite storage, backups, and migration from the PyQt edition.',
              child: _DataActions(
                controller: widget.controller,
                compact: compact,
                onError: _error,
              ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Appearance',
              subtitle: 'Material 3 themes and optional custom accent color.',
              child: _appearance(context, compact: compact),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Category Management',
              subtitle:
                  'Add warehouse categories or remove categories that are no longer used.',
              child: _categories(context, compact: compact),
            ),
            const SizedBox(height: 18),
            _dangerZone(context, compact: compact),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _appearance(BuildContext context, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, box) {
        final oneColumn = compact || box.maxWidth < 620;
        final fieldWidth = oneColumn ? box.maxWidth : (box.maxWidth - 12) / 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: fieldWidth,
                  child: DropdownButtonFormField<SmartStockTheme>(
                    initialValue: widget.controller.theme,
                    key: ValueKey(widget.controller.theme),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      prefixIcon: Icon(Icons.style_outlined),
                    ),
                    items: SmartStockTheme.values
                        .map(
                          (theme) => DropdownMenuItem(
                            value: theme,
                            child: Text(
                              theme.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        widget.controller.applyTheme(value);
                        _hex.clear();
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: fieldWidth,
                  child: SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use the dark SmartStock palette'),
                    value: widget.controller.theme == SmartStockTheme.dark,
                    onChanged: (enabled) {
                      widget.controller.applyTheme(
                        enabled
                            ? SmartStockTheme.dark
                            : SmartStockTheme.defaultLight,
                      );
                      _hex.clear();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: oneColumn ? box.maxWidth : 220,
                  child: TextField(
                    controller: _hex,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Accent Hex',
                      hintText: '#2563EB',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    onSubmitted: (value) {
                      final color = _parseHex(value);
                      if (color == null) {
                        _error('Enter a six-digit hex color such as #2563EB.');
                      } else {
                        widget.controller.setAccent(color);
                      }
                    },
                  ),
                ),
                if (oneColumn)
                  SizedBox(
                    width: box.maxWidth,
                    child: FilledButton.tonalIcon(
                      onPressed: _pickAccent,
                      icon: const Icon(Icons.palette_outlined),
                      label: const Text('Pick Accent Color'),
                    ),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: _pickAccent,
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Pick Accent Color'),
                  ),
                if (oneColumn)
                  SizedBox(
                    width: box.maxWidth,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _hex.clear();
                        widget.controller.setAccent(null);
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset Accent'),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      _hex.clear();
                      widget.controller.setAccent(null);
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset Accent'),
                  ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        widget.controller.customAccent ??
                        Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _categories(BuildContext context, {required bool compact}) {
    return LayoutBuilder(
      builder: (context, box) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (compact || box.maxWidth < 560) ...[
              TextField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'New Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _addCategory,
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'New Category',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.tonalIcon(
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Category'),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.controller.categories.map((cat) {
                final selected = _selectedCategory == cat.name;
                return ChoiceChip(
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(
                    () => _selectedCategory = selected ? null : cat.name,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (compact)
              OutlinedButton.icon(
                onPressed: _selectedCategory == null
                    ? null
                    : _removeSelectedCategory,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Remove Selected Category'),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _selectedCategory == null
                      ? null
                      : _removeSelectedCategory,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Remove Selected Category'),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _addCategory() async {
    try {
      await widget.controller.addCategory(_category.text);
      _category.clear();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _removeSelectedCategory() async {
    final name = _selectedCategory;
    if (name == null) return;
    final ok = await showSmartConfirm(
      context,
      message: "Remove category '$name'?",
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    try {
      await widget.controller.removeCategory(name);
      setState(() => _selectedCategory = null);
    } catch (e) {
      _error(e);
    }
  }

  Widget _dangerZone(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final message = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Danger Zone',
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.error),
        ),
        const SizedBox(height: 3),
        const Text(
          'Reset All Data deletes all inventory items while preserving the category list.',
        ),
      ],
    );

    return Card(
      color: scheme.errorContainer.withValues(alpha: .35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.error.withValues(alpha: .35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: scheme.error),
                      const SizedBox(width: 12),
                      Expanded(child: message),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: _resetInventory,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Reset All Data'),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error),
                  const SizedBox(width: 12),
                  Expanded(child: message),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    onPressed: _resetInventory,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Reset All Data'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DataActions extends StatelessWidget {
  const _DataActions({
    required this.controller,
    required this.compact,
    required this.onError,
  });
  final SmartStockController controller;
  final bool compact;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context) {
    final backup = FilledButton.icon(
      onPressed: () async {
        try {
          await controller.backupDatabase();
        } catch (e) {
          onError(e);
        }
      },
      icon: const Icon(Icons.backup_outlined),
      label: const Text('Backup Database'),
    );
    final import = OutlinedButton.icon(
      onPressed: () async {
        final ok = await showSmartConfirm(
          context,
          destructive: false,
          title: 'Import Legacy Database',
          message:
              'Choose a plaintext SmartStock .db backup from the PyQt version. The current Flutter database will be replaced.',
          confirmLabel: 'Choose Database',
        );
        if (!ok) return;
        try {
          await controller.importLegacyDatabase();
        } catch (e) {
          onError(e);
        }
      },
      icon: const Icon(Icons.move_to_inbox_outlined),
      label: const Text('Import Legacy .db'),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          backup,
          const SizedBox(height: 10),
          import,
          const SizedBox(height: 12),
          const _EncryptionNote(),
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [backup, import, const _EncryptionNote()],
    );
  }
}

class _EncryptionNote extends StatelessWidget {
  const _EncryptionNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 18),
        Text('Encrypted at rest after clean shutdown'),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          child,
        ],
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
  late double r = widget.initial.r * 255;
  late double g = widget.initial.g * 255;
  late double b = widget.initial.b * 255;

  Color get color => Color.fromARGB(255, r.round(), g.round(), b.round());

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pick Accent Color'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          _slider('Red', r, (v) => setState(() => r = v)),
          _slider('Green', g, (v) => setState(() => g = v)),
          _slider('Blue', b, (v) => setState(() => b = v)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, color),
        child: const Text('Apply'),
      ),
    ],
  );

  Widget _slider(String label, double value, ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${value.round()}'),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            label: '${value.round()}',
            onChanged: onChanged,
          ),
        ],
      );
}
