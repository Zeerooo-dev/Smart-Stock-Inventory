import 'package:flutter/material.dart';

import '../../services/export_service.dart';
import '../../state/smartstock_controller.dart';

class ImportInventoryPage extends StatefulWidget {
  const ImportInventoryPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  State<ImportInventoryPage> createState() => _ImportInventoryPageState();
}

class _ImportInventoryPageState extends State<ImportInventoryPage> {
  int _step = 0;
  bool _busy = false;
  InventoryImportSelection? _selection;
  String? _error;
  int? _imported;
  List<String> _skipped = const [];

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selection = await widget.controller.exports.pickInventoryImportFile();
      if (!mounted || selection == null) return;
      setState(() => _selection = selection);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final selection = _selection;
    if (selection == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.controller.exports.commitInventoryImport(selection);
      await widget.controller.refreshAll();
      widget.controller.setStatus(
        result.skippedDuplicates.isEmpty
            ? 'Imported ${result.imported} item(s).'
            : 'Imported ${result.imported}; skipped ${result.skippedDuplicates.length} duplicate name(s).',
      );
      if (!mounted) return;
      setState(() {
        _imported = result.imported;
        _skipped = result.skippedDuplicates;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Import Inventory')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _WizardSteps(
                labels: const ['File', 'Review', 'Confirm'],
                current: _imported != null ? 2 : _step,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _imported != null
                      ? _ImportSuccess(
                          key: const ValueKey('success'),
                          imported: _imported!,
                          skipped: _skipped,
                          onViewInventory: () {
                            widget.controller.goTo(AppSection.inventory);
                            Navigator.pop(context);
                          },
                          onDone: () => Navigator.pop(context),
                        )
                      : switch (_step) {
                          0 => _ImportFileStep(
                              key: const ValueKey('file'),
                              selection: _selection,
                              busy: _busy,
                              error: _error,
                              onChoose: _chooseFile,
                              onContinue: _selection == null
                                  ? null
                                  : () => setState(() => _step = 1),
                            ),
                          1 => _ImportReviewStep(
                              key: const ValueKey('review'),
                              selection: _selection!,
                              error: _error,
                              onBack: () => setState(() => _step = 0),
                              onContinue: () => setState(() => _step = 2),
                            ),
                          _ => _ImportConfirmStep(
                              key: const ValueKey('confirm'),
                              selection: _selection!,
                              busy: _busy,
                              error: _error,
                              onBack: () => setState(() => _step = 1),
                              onConfirm: _confirmImport,
                            ),
                        },
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }
}

class ExportInventoryPage extends StatefulWidget {
  const ExportInventoryPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  State<ExportInventoryPage> createState() => _ExportInventoryPageState();
}

enum _ExportData { inventory, audit }
enum _ExportFormat { pdf, xlsx }

class _ExportInventoryPageState extends State<ExportInventoryPage> {
  int _step = 0;
  _ExportData _data = _ExportData.inventory;
  _ExportFormat _format = _ExportFormat.pdf;
  bool _busy = false;
  String? _error;
  Uri? _result;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Uri? uri = switch ((_data, _format)) {
        (_ExportData.inventory, _ExportFormat.pdf) =>
          await widget.controller.exportInventoryPdf(),
        (_ExportData.inventory, _ExportFormat.xlsx) =>
          await widget.controller.exportInventoryXlsx(),
        (_ExportData.audit, _ExportFormat.pdf) =>
          await widget.controller.exportAuditPdf(),
        (_ExportData.audit, _ExportFormat.xlsx) =>
          await widget.controller.exportAuditXlsx(),
      };
      if (!mounted || uri == null) return;
      setState(() => _result = uri);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Export Inventory')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _WizardSteps(
              labels: const ['Data', 'Format', 'Options'],
              current: _result != null ? 2 : _step,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _result != null
                    ? _ExportSuccess(
                        key: const ValueKey('export-success'),
                        uri: _result!,
                        onDone: () => Navigator.pop(context),
                      )
                    : switch (_step) {
                        0 => _ExportDataStep(
                            key: const ValueKey('export-data'),
                            value: _data,
                            onChanged: (value) => setState(() => _data = value),
                            onContinue: () => setState(() => _step = 1),
                          ),
                        1 => _ExportFormatStep(
                            key: const ValueKey('export-format'),
                            value: _format,
                            onChanged: (value) => setState(() => _format = value),
                            onBack: () => setState(() => _step = 0),
                            onContinue: () => setState(() => _step = 2),
                          ),
                        _ => _ExportOptionsStep(
                            key: const ValueKey('export-options'),
                            data: _data,
                            format: _format,
                            busy: _busy,
                            error: _error,
                            onBack: () => setState(() => _step = 1),
                            onGenerate: _generate,
                          ),
                      },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WizardSteps extends StatelessWidget {
  const _WizardSteps({required this.labels, required this.current});

  final List<String> labels;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: i <= current
                          ? colors.primary
                          : colors.surfaceContainerHighest,
                      foregroundColor: i <= current
                          ? colors.onPrimary
                          : colors.onSurfaceVariant,
                      child: Text('${i + 1}'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        color: i == current
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (i != labels.length - 1)
                Expanded(
                  child: Divider(
                    color: i < current ? colors.primary : colors.outlineVariant,
                    thickness: 2,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportFileStep extends StatelessWidget {
  const _ImportFileStep({
    super.key,
    required this.selection,
    required this.busy,
    required this.error,
    required this.onChoose,
    required this.onContinue,
  });

  final InventoryImportSelection? selection;
  final bool busy;
  final String? error;
  final VoidCallback onChoose;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.upload_file_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text('Upload Inventory Spreadsheet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Choose an existing CSV or XLSX inventory file.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: busy ? null : onChoose,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(selection == null ? 'Browse Files' : 'Change File'),
              ),
            ],
          ),
        ),
      ),
      if (selection != null) ...[
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(selection!.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${(selection!.bytes.length / 1024).toStringAsFixed(1)} KB · ${selection!.extension.toUpperCase()} · Ready to review'),
          ),
        ),
      ],
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Required File Columns'),
          subtitle: Text('ItemName, Category, Quantity, and UnitPrice are required. Existing item names are skipped rather than overwritten.'),
        ),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        _ErrorCard(message: error!),
      ],
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: busy ? null : onContinue,
        icon: busy
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.arrow_forward),
        label: const Text('Review Import'),
      ),
    ],
  );
}

class _ImportReviewStep extends StatelessWidget {
  const _ImportReviewStep({
    super.key,
    required this.selection,
    required this.error,
    required this.onBack,
    required this.onContinue,
  });

  final InventoryImportSelection selection;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final preview = selection.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryGrid(
          values: [
            ('Detected', '${preview.totalRows}'),
            ('Ready', '${preview.importableRows}'),
            ('Warnings', '${preview.warningCount}'),
            ('Errors', '0'),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Review', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(selection.fileName),
                const SizedBox(height: 6),
                Text(
                  preview.warningCount == 0
                      ? 'All rows passed validation and are ready to import.'
                      : '${preview.warningCount} existing item name(s) will be skipped to preserve current inventory.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (preview.duplicateNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final name in preview.duplicateNames.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(child: Text('$name · duplicate name')),
                        ],
                      ),
                    ),
                  if (preview.duplicateNames.length > 5)
                    Text('+${preview.duplicateNames.length - 5} more duplicate name(s)'),
                ],
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorCard(message: error!),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: onBack, child: const Text('Back'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: onContinue, child: const Text('Continue'))),
          ],
        ),
      ],
    );
  }
}

class _ImportConfirmStep extends StatelessWidget {
  const _ImportConfirmStep({
    super.key,
    required this.selection,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onConfirm,
  });

  final InventoryImportSelection selection;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final preview = selection.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confirm Import', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('${preview.importableRows} new item(s) are ready to import.'),
                const SizedBox(height: 6),
                Text('${preview.warningCount} duplicate name(s) will be skipped.'),
                const SizedBox(height: 12),
                const Text('Imported rows use SmartStock’s existing behavior: new categories are created as needed and every imported item is recorded in the audit ledger.'),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          _ErrorCard(message: error!),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: busy ? null : onBack, child: const Text('Back'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: busy ? null : onConfirm,
                icon: busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_done_outlined),
                label: Text('Confirm Import (${preview.importableRows})'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImportSuccess extends StatelessWidget {
  const _ImportSuccess({
    super.key,
    required this.imported,
    required this.skipped,
    required this.onViewInventory,
    required this.onDone,
  });

  final int imported;
  final List<String> skipped;
  final VoidCallback onViewInventory;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Import Complete', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$imported item(s) imported successfully.'),
              if (skipped.isNotEmpty) Text('${skipped.length} duplicate name(s) skipped.'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: onViewInventory, child: const Text('View Inventory')),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: onDone, child: const Text('Done')),
    ],
  );
}

class _ExportDataStep extends StatelessWidget {
  const _ExportDataStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onContinue,
  });

  final _ExportData value;
  final ValueChanged<_ExportData> onChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepCard(
        title: '1. Choose Data',
        children: [
          _ChoiceTile(
            selected: value == _ExportData.inventory,
            icon: Icons.inventory_2_outlined,
            title: 'Current Inventory Catalog',
            subtitle: 'Active SKU registry, quantities, prices and categories',
            onTap: () => onChanged(_ExportData.inventory),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            selected: value == _ExportData.audit,
            icon: Icons.history_outlined,
            title: 'Audit Log History',
            subtitle: 'Current audit filter with Before / Change / After data',
            onTap: () => onChanged(_ExportData.audit),
          ),
        ],
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: onContinue,
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Continue'),
      ),
    ],
  );
}

class _ExportFormatStep extends StatelessWidget {
  const _ExportFormatStep({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  final _ExportFormat value;
  final ValueChanged<_ExportFormat> onChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepCard(
        title: '2. Select Format',
        children: [
          _ChoiceTile(
            selected: value == _ExportFormat.pdf,
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF',
            subtitle: 'Print-ready SmartStock report',
            onTap: () => onChanged(_ExportFormat.pdf),
          ),
          const SizedBox(height: 8),
          _ChoiceTile(
            selected: value == _ExportFormat.xlsx,
            icon: Icons.table_chart_outlined,
            title: 'XLSX',
            subtitle: 'Spreadsheet export for analysis',
            onTap: () => onChanged(_ExportFormat.xlsx),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: onBack, child: const Text('Back'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: onContinue, child: const Text('Continue'))),
        ],
      ),
    ],
  );
}

class _ExportOptionsStep extends StatelessWidget {
  const _ExportOptionsStep({
    super.key,
    required this.data,
    required this.format,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onGenerate,
  });

  final _ExportData data;
  final _ExportFormat format;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepCard(
        title: '3. Export Options',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dataset_outlined),
            title: Text(data == _ExportData.inventory ? 'Inventory Catalog' : 'Audit Log'),
            subtitle: Text(
              data == _ExportData.inventory
                  ? 'Exports the current inventory catalog.'
                  : 'Uses the current Audit Log filters and includes quantity history where available.',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_present_outlined),
            title: Text(format == _ExportFormat.pdf ? 'PDF' : 'XLSX'),
            subtitle: const Text('SmartStock uses the existing export columns and formatting for this file type.'),
          ),
          if (data == _ExportData.audit)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.swap_horiz),
              title: Text('Quantity Before / Change / After'),
              subtitle: Text('Included from the audit ledger when those values are available.'),
            ),
        ],
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        _ErrorCard(message: error!),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: busy ? null : onBack, child: const Text('Back'))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: busy ? null : onGenerate,
              icon: busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_outlined),
              label: const Text('Generate Export'),
            ),
          ),
        ],
      ),
    ],
  );
}

class _ExportSuccess extends StatelessWidget {
  const _ExportSuccess({super.key, required this.uri, required this.onDone});

  final Uri uri;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.check_circle, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Export Complete', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(uri.pathSegments.isEmpty ? uri.toString() : uri.pathSegments.last),
              const SizedBox(height: 4),
              Text('Your SmartStock export was saved successfully.', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(onPressed: onDone, child: const Text('Done')),
    ],
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer.withValues(alpha: 0.35) : colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? colors.primary : colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.check_circle : icon, color: selected ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.values});
  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 24) / 4;
      return Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                  child: Column(
                    children: [
                      Text(values[i].$1, style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(values[i].$2, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
              ),
            ),
            if (i != values.length - 1) const SizedBox(width: 8),
          ],
        ],
      );
    },
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: ListTile(
      leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
      title: Text('Could not complete this step', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      subtitle: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
    ),
  );
}
