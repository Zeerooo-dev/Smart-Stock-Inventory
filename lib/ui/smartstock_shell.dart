import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/smartstock_controller.dart';
import 'pages/audit_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/import_export_pages.dart';
import 'pages/inventory_page.dart';
import 'pages/more_page.dart';
import 'pages/notifications_page.dart';
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

  static const _mobileSections = <AppSection>[
    AppSection.dashboard,
    AppSection.inventory,
    AppSection.reports,
    AppSection.audit,
    AppSection.more,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.notifications.addListener(_notificationChanged);
  }

  @override
  void dispose() {
    controller.notifications.removeListener(_notificationChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _notificationChanged() {
    if (mounted) setState(() {});
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
        case AppSection.dashboard:
          await controller.refreshAll();
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
        case AppSection.more:
          break;
      }
    } catch (e) {
      if (mounted && request == _navigation) {
        setState(
          () => _error =
              'Could not refresh ${_label(section).toLowerCase()}: $e',
        );
      }
    } finally {
      if (mounted && request == _navigation) setState(() => _loading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(controller: controller),
      ),
    );
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ImportInventoryPage(controller: controller),
      ),
    );
  }

  Future<void> _openExport() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ExportInventoryPage(controller: controller),
      ),
    );
  }

  Future<void> _showHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Inventory Guide'),
        content: const SingleChildScrollView(
          child: Text(
            'Use Dashboard for a quick inventory overview.\n\n'
            'Open Inventory to search items, view details, restock, dispense, add items, or scan a barcode.\n\n'
            'Reports summarizes current stock and export tools. Audit Log keeps the recorded inventory history.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'SmartStock',
      applicationVersion: '2.1.0',
      applicationLegalese: 'Precision stock management system',
    );
  }

  Future<void> _inventoryAction(String message) async {
    controller.setStatus(message);
    await _navigate(AppSection.inventory);
  }

  Future<void> _openLowStock(String itemName) async {
    await _navigate(AppSection.inventory);
    await controller.setInventorySearch(itemName);
  }

  @override
  Widget build(BuildContext context) {
    _visited.add(controller.section);
    return PopScope(
      canPop: controller.section == AppSection.dashboard,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.section == AppSection.settings ||
            controller.section == AppSection.suppliers) {
          _navigate(AppSection.more);
        } else {
          _navigate(AppSection.dashboard);
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _onScannerKeyEvent,
        child: LayoutBuilder(
          builder: (context, box) {
            final rail =
                box.maxWidth >= 600 &&
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
                                  AppSection.dashboard => DashboardPage(
                                    controller: controller,
                                    onInventory: () =>
                                        _navigate(AppSection.inventory),
                                    onReports: () =>
                                        _navigate(AppSection.reports),
                                    onAudit: () => _navigate(AppSection.audit),
                                    onScan: () =>
                                        showScanner(context, controller),
                                    onRestock: () => _inventoryAction(
                                      'Select an item to restock.',
                                    ),
                                    onDispense: () => _inventoryAction(
                                      'Select an item to dispense.',
                                    ),
                                    onAddItem: () => _inventoryAction(
                                      'Use Add Item to create new inventory.',
                                    ),
                                    onOpenLowStock: (name) =>
                                        unawaited(_openLowStock(name)),
                                  ),
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
                                  AppSection.more => MorePage(
                                    controller: controller,
                                    onNotifications: () =>
                                        unawaited(_openNotifications()),
                                    onSuppliers: () =>
                                        unawaited(_navigate(AppSection.suppliers)),
                                    onSettings: () =>
                                        unawaited(_navigate(AppSection.settings)),
                                    onImport: () => unawaited(_openImport()),
                                    onExport: () => unawaited(_openExport()),
                                    onScanner: () =>
                                        showScanner(context, controller),
                                    onHelp: () => unawaited(_showHelp()),
                                    onAbout: _showAbout,
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
                      title: controller.section == AppSection.dashboard
                          ? const _DashboardTitle()
                          : Text(_label(controller.section)),
                      actions: [
                        IconButton(
                          tooltip: 'Notifications',
                          onPressed: _openNotifications,
                          icon: _NotificationIcon(
                            count: controller.notifications.unreadCount,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Scan barcode',
                          onPressed: () => showScanner(context, controller),
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                      ],
                    ),
              drawer: short
                  ? Drawer(
                      child: SafeArea(
                        child: ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'SmartStock',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
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
                            width: box.maxWidth >= 1200 ? 210 : 176,
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                                  child: Text(
                                    'SmartStock',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                ),
                                ...destinations,
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: _openNotifications,
                                    icon: _NotificationIcon(
                                      count: controller.notifications.unreadCount,
                                    ),
                                    label: const Text('Notifications'),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        showScanner(context, controller),
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan barcode'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          VerticalDivider(
                            width: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          Expanded(child: page),
                        ],
                      )
                    : page,
              ),
              bottomNavigationBar: rail || short
                  ? null
                  : NavigationBar(
                      selectedIndex: _mobileSelectedIndex,
                      onDestinationSelected: (index) {
                        _navigate(_mobileSections[index]);
                      },
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: 'Dashboard',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: 'Inventory',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.analytics_outlined),
                          selectedIcon: Icon(Icons.analytics),
                          label: 'Reports',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: 'Audit',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.more_horiz),
                          label: 'More',
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  int get _mobileSelectedIndex {
    final index = _mobileSections.indexOf(controller.section);
    return index >= 0 ? index : 4;
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

class _NotificationIcon extends StatelessWidget {
  const _NotificationIcon({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Icon(Icons.notifications_none_rounded),
      if (count > 0)
        Positioned(
          right: -2,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
          ),
        ),
    ],
  );
}

class _DashboardTitle extends StatelessWidget {
  const _DashboardTitle();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SmartStock',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Inventory overview',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ],
  );
}

String _label(AppSection section) => switch (section) {
  AppSection.dashboard => 'Dashboard',
  AppSection.inventory => 'Inventory',
  AppSection.reports => 'Reports',
  AppSection.audit => 'Audit Log',
  AppSection.suppliers => 'Suppliers',
  AppSection.settings => 'Settings',
  AppSection.more => 'More',
};

IconData _icon(AppSection section) => switch (section) {
  AppSection.dashboard => Icons.dashboard_outlined,
  AppSection.inventory => Icons.inventory_2_outlined,
  AppSection.reports => Icons.analytics_outlined,
  AppSection.audit => Icons.receipt_long_outlined,
  AppSection.suppliers => Icons.local_shipping_outlined,
  AppSection.settings => Icons.settings_outlined,
  AppSection.more => Icons.more_horiz,
};
