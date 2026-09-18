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

class _SmartStockShellState extends State<SmartStockShell> {
  String _scanBuffer = '';
  DateTime? _lastScanKey;

  SmartStockController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onScannerKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;
          final extendedRail = constraints.maxWidth >= 900;

          final page = Column(
            children: [
              Expanded(child: _currentPage()),
              _StatusBar(text: controller.statusMessage),
            ],
          );

          if (compact) {
            return Scaffold(
              appBar: AppBar(
                toolbarHeight: 56,
                titleSpacing: 16,
                scrolledUnderElevation: 0,
                title: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 19,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _sectionLabel(controller.section),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              body: SafeArea(top: false, bottom: false, child: page),
              bottomNavigationBar: _MobileNav(controller: controller),
            );
          }

          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _AdaptiveRail(controller: controller, extended: extendedRail),
                  const VerticalDivider(width: 1),
                  Expanded(child: page),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _currentPage() => switch (controller.section) {
    AppSection.inventory => InventoryPageView(controller: controller),
    AppSection.reports => ReportsPage(controller: controller),
    AppSection.audit => AuditPage(controller: controller),
    AppSection.suppliers => SuppliersPage(controller: controller),
    AppSection.settings => SettingsPage(controller: controller),
  };

  KeyEventResult _onScannerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _isTextEditing()) {
      return KeyEventResult.ignored;
    }

    final now = DateTime.now();
    final gap = _lastScanKey == null ? null : now.difference(_lastScanKey!);
    if (gap != null && gap > const Duration(milliseconds: 80)) {
      _scanBuffer = '';
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final scanned = _scanBuffer.trim();
      _scanBuffer = '';
      _lastScanKey = null;
      if (scanned.length >= 6) {
        unawaited(controller.locateSku(scanned));
      }
      return KeyEventResult.ignored;
    }

    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        character.codeUnitAt(0) >= 32 &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isAltPressed) {
      _scanBuffer += character;
      _lastScanKey = now;
    }
    return KeyEventResult.ignored;
  }

  bool _isTextEditing() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

String _sectionLabel(AppSection section) => switch (section) {
  AppSection.inventory => 'Inventory',
  AppSection.reports => 'Reports',
  AppSection.audit => 'Audit Log',
  AppSection.suppliers => 'Suppliers',
  AppSection.settings => 'Settings',
};

class _AdaptiveRail extends StatelessWidget {
  const _AdaptiveRail({required this.controller, required this.extended});
  final SmartStockController controller;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 220,
      selectedIndex: controller.section.index,
      onDestinationSelected: (index) =>
          controller.goTo(AppSection.values[index]),
      groupAlignment: -0.78,
      leading: Padding(
        padding: EdgeInsets.fromLTRB(
          extended ? 20 : 8,
          18,
          extended ? 20 : 8,
          18,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (extended) ...[
              const SizedBox(width: 12),
              Text(
                'SmartStock',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('Inventory'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Audit'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: Text('Suppliers'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.controller});
  final SmartStockController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: NavigationBar(
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      selectedIndex: controller.section.index,
      onDestinationSelected: (index) =>
          controller.goTo(AppSection.values[index]),
      destinations: const [
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
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: 'Suppliers',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty || text == 'Ready') return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
