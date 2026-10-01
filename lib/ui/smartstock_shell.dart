import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/smartstock_controller.dart';
import 'pages/audit_page.dart';
import 'pages/inventory_page.dart';
import 'pages/reports_page.dart';
import 'pages/settings_page.dart';
import 'pages/suppliers_page.dart';

class SmartStockShell extends StatefulWidget {
  const SmartStockShell({super.key, required this.controller});
  final SmartStockController controller;
  @override
  State<SmartStockShell> createState() => _SmartStockShellState();
}

class _SmartStockShellState extends State<SmartStockShell>
    with WidgetsBindingObserver {
  String _scanBuffer = '';
  DateTime? _lastScanKey;
  bool _loading = false;
  String? _error;
  int _navigation = 0;
  final _visited = <AppSection>{};
  SmartStockController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      await controller.refreshAll();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not refresh data: $e');
    }
  }

  Future<void> _navigate(AppSection section) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final request = ++_navigation;
    controller.section = section;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (section) {
        case AppSection.inventory:
          await controller.refreshInventory();
        case AppSection.reports:
          await controller.refreshReports();
        case AppSection.audit:
          await controller.refreshAudit();
        case AppSection.suppliers:
          await controller.refreshSuppliers();
        case AppSection.settings:
          await controller.refreshCategories();
      }
    } catch (e) {
      if (mounted && request == _navigation) {
        setState(
          () =>
              _error = 'Could not refresh ${_label(section).toLowerCase()}: $e',
        );
      }
    } finally {
      if (mounted && request == _navigation) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    final section = await showModalBottomSheet<AppSection>(
      context: context,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in [AppSection.suppliers, AppSection.settings])
              ListTile(
                leading: Icon(_icon(section)),
                title: Text(_label(section)),
                onTap: () => Navigator.pop(context, section),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (section != null && mounted) await _navigate(section);
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(controller.section);
    return PopScope(
      canPop: controller.section == AppSection.inventory,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigate(AppSection.inventory);
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onScannerKeyEvent,
        child: LayoutBuilder(
          builder: (context, box) {
            final rail =
                box.maxWidth >= 760 &&
                box.maxHeight >= 500 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.6;
            final short = box.maxHeight < 450;
            final page = Column(
              children: [
                if (_loading)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Refreshing data',
                  ),
                if (_error != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: MaterialBanner(
                        content: Text(_error!),
                        actions: [
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _error = null),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: controller.section.index,
                    children: [
                      for (final section in AppSection.values)
                        _visited.contains(section)
                            ? KeyedSubtree(
                                key: ValueKey(section),
                                child: switch (section) {
                                  AppSection.inventory => InventoryPageView(
                                    controller: controller,
                                  ),
                                  AppSection.reports => ReportsPage(
                                    controller: controller,
                                  ),
                                  AppSection.audit => AuditPage(
                                    controller: controller,
                                  ),
                                  AppSection.suppliers => SuppliersPage(
                                    controller: controller,
                                  ),
                                  AppSection.settings => SettingsPage(
                                    controller: controller,
                                  ),
                                },
                              )
                            : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            );
            final destinations = [
              for (final section in AppSection.values)
                ListTile(
                  selected: controller.section == section,
                  leading: Icon(_icon(section)),
                  title: Text(_label(section)),
                  onTap: () {
                    if (!rail) Navigator.pop(context);
                    _navigate(section);
                  },
                ),
            ];
            return Scaffold(
              appBar: rail
                  ? null
                  : AppBar(
                      leadingWidth: short ? 80 : null,
                      leading: short
                          ? Builder(
                              builder: (context) => TextButton(
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                                child: const Text('Menu'),
                              ),
                            )
                          : null,
                      title: Text(_label(controller.section)),
                      actions: [
                        IconButton(
                          tooltip: 'Scan barcode',
                          onPressed: () => showScanner(context, controller),
                          icon: const Icon(Icons.barcode_reader),
                        ),
                      ],
                    ),
              drawer: short
                  ? Drawer(
                      child: SafeArea(
                        child: ListView(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('SmartStock'),
                            ),
                            ...destinations,
                          ],
                        ),
                      ),
                    )
                  : null,
              body: SafeArea(
                top: rail,
                bottom: true,
                child: rail
                    ? Row(
                        children: [
                          SizedBox(
                            width: box.maxWidth >= 1200 ? 210 : 180,
                            child: ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'SmartStock',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                ...destinations,
                                TextButton.icon(
                                  onPressed: () =>
                                      showScanner(context, controller),
                                  icon: const Icon(Icons.barcode_reader),
                                  label: const Text('Scan barcode'),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: page),
                        ],
                      )
                    : page,
              ),
              bottomNavigationBar: rail || short
                  ? null
                  : SafeArea(
                      top: false,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: Wrap(
                          children: [
                            for (var index = 0; index < 4; index++)
                              SizedBox(
                                width:
                                    box.maxWidth /
                                    (MediaQuery.textScalerOf(
                                              context,
                                            ).scale(1) >=
                                            1.5
                                        ? 2
                                        : 4),
                                child: Semantics(
                                  selected:
                                      index ==
                                      (controller.section.index < 3
                                          ? controller.section.index
                                          : 3),
                                  child: TextButton(
                                    onPressed: () => index == 3
                                        ? _more()
                                        : _navigate(AppSection.values[index]),
                                    style: TextButton.styleFrom(
                                      textStyle: Theme.of(
                                        context,
                                      ).textTheme.labelMedium,
                                      foregroundColor:
                                          index ==
                                              (controller.section.index < 3
                                                  ? controller.section.index
                                                  : 3)
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 10,
                                      ),
                                      backgroundColor:
                                          index ==
                                              (controller.section.index < 3
                                                  ? controller.section.index
                                                  : 3)
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          index == 3
                                              ? Icons.more_horiz
                                              : _icon(AppSection.values[index]),
                                        ),
                                        Text(
                                          index == 3
                                              ? 'More'
                                              : index == 2
                                              ? 'Audit'
                                              : _label(
                                                  AppSection.values[index],
                                                ),
                                          textAlign: TextAlign.center,
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
          },
        ),
      ),
    );
  }

  KeyEventResult _onScannerKeyEvent(FocusNode node, KeyEvent event) {
    final focus = FocusManager.instance.primaryFocus?.context;
    final editing =
        focus?.widget is EditableText ||
        focus?.findAncestorWidgetOfExactType<EditableText>() != null;
    if (event is! KeyDownEvent || editing) {
      _scanBuffer = '';
      _lastScanKey = null;
      return KeyEventResult.ignored;
    }
    final now = DateTime.now();
    if (_lastScanKey != null &&
        now.difference(_lastScanKey!) > const Duration(milliseconds: 80)) {
      _scanBuffer = '';
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final sku = _scanBuffer.trim();
      _scanBuffer = '';
      _lastScanKey = null;
      if (sku.length >= 6) {
        unawaited(_locate(sku));
        return KeyEventResult.handled;
      }
    } else if (event.character != null &&
        event.character!.length == 1 &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      _scanBuffer += event.character!;
      _lastScanKey = now;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _locate(String sku) async {
    try {
      await controller.locateSku(sku);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not look up barcode: $e');
    }
  }
}

String _label(AppSection section) => switch (section) {
  AppSection.inventory => 'Inventory',
  AppSection.reports => 'Reports',
  AppSection.audit => 'Audit Log',
  AppSection.suppliers => 'Suppliers',
  AppSection.settings => 'Settings',
};
IconData _icon(AppSection section) => switch (section) {
  AppSection.inventory => Icons.inventory_2_outlined,
  AppSection.reports => Icons.analytics_outlined,
  AppSection.audit => Icons.receipt_long_outlined,
  AppSection.suppliers => Icons.local_shipping_outlined,
  AppSection.settings => Icons.settings_outlined,
};
