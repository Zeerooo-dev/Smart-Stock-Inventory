import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/core/app_theme.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/ui/pages/audit_page.dart';
import 'package:smartstock_flutter/ui/pages/inventory_page.dart';
import 'package:smartstock_flutter/ui/pages/reports_page.dart';
import 'package:smartstock_flutter/ui/pages/settings_page.dart';
import 'package:smartstock_flutter/ui/pages/suppliers_page.dart';
import 'package:smartstock_flutter/ui/widgets/dialogs.dart';
import 'package:smartstock_flutter/ui/widgets/stock_widgets.dart';
import 'package:smartstock_flutter/ui/smartstock_shell.dart';
import 'inventory_ui_test.dart' as fixture;

const largeEntry = LedgerEntry(
  ledgerId: 1,
  timestamp: '2026-10-01 12:00:00',
  itemName: 'Synthetic fixture with a long item name',
  sku: 'SYNTHETIC-FIXTURE-123456',
  changeType: 'DELETE',
  deltaQuantity: -123456,
  priceSnapshot: 1234.56,
  quantityBefore: 123456,
  quantityAfter: 0,
  notes: 'Synthetic deletion note',
);

class RedesignDatabase extends fixture.UiDatabase {
  @override
  Future<InventoryItem?> findItemBySku(String sku) async =>
      sku == current.sku ? current : null;
  @override
  Future<ItemHistorySnapshot> getItemHistory(int id, {int page = 0}) async =>
      const ItemHistorySnapshot(
        currentQuantity: 0,
        totalAdded: 123456,
        totalRemoved: 123456,
        entries: [largeEntry],
        totalEntries: 1,
      );
}

class FullInventoryDatabase extends RedesignDatabase {
  @override
  Future<List<InventoryItem>> getAllInventory() async => [
    fixture.mouse,
    for (var id = 2; id <= 2000; id++)
      InventoryItem(
        id: id,
        sku: 'SYNTHETIC-$id',
        name: 'Synthetic item $id',
        category: 'Electronics',
        quantity: id == 2000 ? 0 : 20,
        unitPrice: 1,
        reorderLevel: 5,
      ),
  ];
}

class SupplierController extends fixture.UiController {
  int calls = 0;
  final saved = Completer<void>();
  @override
  Future<void> saveSupplier({
    int? id,
    required String name,
    String email = '',
    String phone = '',
    String notes = '',
  }) async {
    calls++;
    await saved.future;
  }
}

class UnavailableItemDatabase extends RedesignDatabase {
  @override
  Future<InventoryItem?> findItemById(int id) async =>
      throw StateError('Synthetic read failure');
}

class UnavailableRefreshController extends fixture.UiController {
  @override
  Future<void> refreshAll() async =>
      throw StateError('Synthetic refresh failure with a long explanation');
}

Future<void> loadRoboto() async {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final path = File('${artifacts.path}/material_fonts/Roboto-Regular.ttf');
  if (!path.existsSync()) {
    throw StateError('Flutter SDK Roboto font is required for layout tests.');
  }
  final font = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(path.readAsBytesSync())));
  await font.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

Future<void> setup(
  WidgetTester tester,
  Widget page, {
  Size size = const Size(360, 800),
  double scale = 1,
  SmartStockTheme theme = SmartStockTheme.defaultLight,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SmartStockThemes.build(theme),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(
  WidgetTester tester,
  Finder finder, [
  double delta = 200,
]) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'stock lookup failure stays visible without opening a stale form',
    (tester) async {
      final controller = fixture.UiController(
        database: UnavailableItemDatabase(),
      );
      addTearDown(controller.dispose);
      await setup(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => adjustItemStock(
              context,
              controller,
              fixture.mouse,
              restock: true,
            ),
            child: const Text('Restock fixture'),
          ),
        ),
      );
      await tester.tap(find.text('Restock fixture'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load this item'), findsOneWidget);
      expect(fixture.field('Quantity'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh error actions remain reachable in short landscape at 200 percent',
    (tester) async {
      await loadRoboto();
      final controller = UnavailableRefreshController();
      addTearDown(controller.dispose);
      await setup(
        tester,
        SmartStockShell(controller: controller),
        size: const Size(640, 320),
        scale: 2,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not refresh data'), findsOneWidget);
      await tester.ensureVisible(find.text('Dismiss'));
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not refresh data'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide inventory opens a read-only detail pane and edit reloads current stock',
    (tester) async {
      final database = RedesignDatabase();
      final controller = fixture.UiController(database: database);
      addTearDown(controller.dispose);
      await setup(
        tester,
        InventoryPageView(controller: controller),
        size: const Size(1450, 1000),
      );
      await tester.tap(find.text('Mouse'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ItemDetails>(find.byType(ItemDetails)).embedded,
        isTrue,
      );
      expect(fixture.field('Quantity'), findsNothing);
      database.current = const InventoryItem(
        id: 1,
        sku: 'WM-001',
        name: 'Mouse',
        category: 'Electronics',
        quantity: 17,
        unitPrice: 500,
        reorderLevel: 5,
      );
      await tester.tap(find.byTooltip('Item actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(fixture.value(tester, 'Quantity'), '17');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'supplier validation and pending save prevent duplicate submissions',
    (tester) async {
      final controller = SupplierController();
      addTearDown(controller.dispose);
      await setup(tester, SuppliersPage(controller: controller));
      await tester.tap(find.text('Add Supplier'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save supplier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save supplier'));
      await tester.pumpAndSettle();
      expect(controller.calls, 0);
      await tester.enterText(
        fixture.field('Company Name'),
        'Synthetic supplier',
      );
      await tester.ensureVisible(find.text('Save supplier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save supplier'));
      await tester.pump();
      expect(controller.calls, 1);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      controller.saved.complete();
      await tester.pumpAndSettle();
      expect(find.text('Supplier saved.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'file save displays its provider destination and cancellation stays honest',
    (tester) async {
      await setup(
        tester,
        Column(
          children: [
            TaskButton(
              label: 'Save fixture',
              savedFile: true,
              action: () async =>
                  Uri.parse('content://synthetic-provider/report.pdf'),
            ),
            TaskButton(
              label: 'Cancel fixture',
              savedFile: true,
              action: () async => null,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Save fixture'));
      await tester.pumpAndSettle();
      expect(
        find.text('content://synthetic-provider/report.pdf'),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel fixture'));
      await tester.pumpAndSettle();
      expect(find.text('Save cancelled.'), findsOneWidget);
    },
  );

  testWidgets(
    'stock sheet retains invalid quantity and note with keyboard at 200 percent',
    (tester) async {
      await loadRoboto();
      var submitted = 0;
      await setup(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showStockAmountDialog(
              context,
              restock: false,
              item: fixture.mouse,
              onSubmit: (amount, notes) async {
                submitted++;
                expect(amount, 2);
                expect(notes, 'Synthetic reason');
              },
            ),
            child: const Text('Stock'),
          ),
        ),
        size: const Size(320, 640),
        scale: 2,
      );
      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(fixture.field('Quantity'), '99');
      await tester.enterText(
        fixture.field('Notes (optional)'),
        'Synthetic reason',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      expect(submitted, 0);
      expect(fixture.value(tester, 'Notes (optional)'), 'Synthetic reason');
      await tester.enterText(fixture.field('Quantity'), '2');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      expect(submitted, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('RGB picker labels and values work with semantics enabled', (
    tester,
  ) async {
    final controller = fixture.UiController();
    addTearDown(controller.dispose);
    final semantics = tester.ensureSemantics();
    try {
      await setup(tester, SettingsPage(controller: controller));
      await reveal(tester, find.text('Pick color'));
      await tester.tap(find.text('Pick color'));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNWidgets(3));
      await tester.tap(find.byType(Slider).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Use color'));
      await tester.pumpAndSettle();
      expect(controller.customAccent, isNotNull);
    } finally {
      semantics.dispose();
    }
  });

  test('theme contrast survives every preset and extreme accents', () {
    for (final preset in SmartStockTheme.values) {
      for (final accent in [
        null,
        Colors.white,
        Colors.black,
        Colors.yellow,
        Colors.red,
        Colors.green,
      ]) {
        final theme = SmartStockThemes.build(preset, accent: accent);
        final s = theme.colorScheme;
        for (final pair in [
          (s.primary, s.surface),
          (s.primary, theme.scaffoldBackgroundColor),
          (s.onPrimary, s.primary),
          (s.onPrimaryContainer, s.primaryContainer),
          (s.onSurface, s.surface),
          (s.onSurfaceVariant, s.surface),
          (theme.extension<StockColors>()!.healthy, s.surface),
          (theme.extension<StockColors>()!.warning, s.surface),
        ]) {
          expect(
            SmartStockThemes.contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$preset / $accent',
          );
        }
        expect(
          SmartStockThemes.contrast(s.outline, s.surface),
          greaterThanOrEqualTo(3),
        );
      }
    }
  });

  testWidgets(
    'unsaved item draft survives cancel and rotation; discard is explicit',
    (tester) async {
      final controller = fixture.UiController();
      addTearDown(controller.dispose);
      await setup(tester, InventoryPageView(controller: controller));
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      await tester.enterText(fixture.field('Item Name'), 'Unsaved fixture');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpAndSettle();
      expect(fixture.value(tester, 'Item Name'), 'Unsaved fixture');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(fixture.field('Item Name'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'name, SKU search and stock filter operate on the full inventory',
    (tester) async {
      final controller = fixture.UiController(database: FullInventoryDatabase())
        ..inventoryPage = const InventoryPage(
          items: [fixture.mouse],
          total: 2000,
        );
      addTearDown(controller.dispose);
      await setup(tester, InventoryPageView(controller: controller));
      expect(find.byType(InventoryRow).evaluate().length, lessThan(30));
      final search = fixture.field('Search inventory');
      await tester.enterText(search, 'WM-001');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Mouse'), findsOneWidget);
      await tester.enterText(search, 'SYNTHETIC-2000');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Synthetic item 2000'), findsOneWidget);
      await tester.enterText(search, 'nonexistent');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('No matching items'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      await tester.tap(find.text('Low stock (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic item 2000'), findsOneWidget);
      expect(find.text('Mouse'), findsNothing);
    },
  );

  testWidgets(
    'audit exposes deleted snapshots and notes without offering reversal',
    (tester) async {
      final controller = fixture.UiController()
        ..auditPage = const LedgerPage(entries: [largeEntry], total: 1);
      addTearDown(controller.dispose);
      await loadRoboto();
      await setup(
        tester,
        AuditPage(controller: controller),
        scale: 2,
        size: const Size(320, 640),
      );
      await reveal(tester, find.text(largeEntry.itemName));
      await tester.tap(find.text(largeEntry.itemName));
      await tester.pumpAndSettle();
      expect(find.text('Reverse stock change'), findsNothing);
      await reveal(tester, find.text('Note: Synthetic deletion note'));
      expect(find.text('Before: 123456'), findsOneWidget);
      expect(find.text('After: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending audit filter blocks exports and validates the item name',
    (tester) async {
      final controller = fixture.UiController();
      addTearDown(controller.dispose);
      await setup(tester, AuditPage(controller: controller));
      await tester.tap(find.text('Filter history'));
      await tester.pumpAndSettle();
      await tester.enterText(
        fixture.field('Item name (blank for all)'),
        'Unknown fixture',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply filters'));
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      final export = tester.widget<TaskButton>(
        find.byWidgetPredicate(
          (w) => w is TaskButton && w.label == 'Export Audit PDF',
        ),
      );
      expect(export.enabled, isFalse);
      await reveal(tester, find.textContaining('Choose an existing item name'));
      expect(
        find.textContaining('Choose an existing item name'),
        findsOneWidget,
      );
    },
  );

  testWidgets('history and confirmation reflow at 200 percent in all themes', (
    tester,
  ) async {
    final controller = fixture.UiController(database: RedesignDatabase());
    addTearDown(controller.dispose);
    await loadRoboto();
    for (final theme in SmartStockTheme.values) {
      for (final size in [const Size(320, 640), const Size(640, 320)]) {
        await setup(
          tester,
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showSmartConfirm(
                    context,
                    message:
                        'Delete this synthetic fixture and preserve the complete audit history?',
                  ),
                  child: const Text('Confirm'),
                ),
                TextButton(
                  onPressed: () =>
                      showItemHistoryDialog(context, controller, fixture.mouse),
                  child: const Text('History'),
                ),
              ],
            ),
          ),
          size: size,
          scale: 2,
          theme: theme,
        );
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        await reveal(tester, find.text('Note: Synthetic deletion note'));
        expect(tester.takeException(), isNull);
        await reveal(tester, find.byTooltip('Close history'), -150);
        await tester.tap(find.byTooltip('Close history'));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets(
    'explicit scanner submits with the field focused and reports unknown SKUs',
    (tester) async {
      final controller = fixture.UiController(database: RedesignDatabase());
      addTearDown(controller.dispose);
      await setup(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showScanner(context, controller),
            child: const Text('Scan'),
          ),
        ),
      );
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      await tester.enterText(fixture.field('Barcode or SKU'), 'WM-001');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Item Details'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.enterText(fixture.field('Barcode or SKU'), 'UNKNOWN');
      await tester.tap(find.text('Find item'));
      await tester.pumpAndSettle();
      expect(find.text('No inventory item matches UNKNOWN.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Blue Steel dark toggle reflects theme and keeps custom accent', (
    tester,
  ) async {
    final controller = fixture.UiController()
      ..theme = SmartStockTheme.blueSteel
      ..customAccent = Colors.yellow;
    addTearDown(controller.dispose);
    await setup(
      tester,
      AnimatedBuilder(
        animation: controller,
        builder: (_, _) => SettingsPage(controller: controller),
      ),
    );
    await reveal(tester, find.text('Dark mode'));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.theme, SmartStockTheme.defaultLight);
    expect(controller.customAccent, Colors.yellow);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.theme, SmartStockTheme.blueSteel);
  });

  testWidgets(
    'report renders real categories without progress semantics errors',
    (tester) async {
      final controller = fixture.UiController()
        ..categorySummaries = const [
          CategorySummary(
            category: 'Synthetic category',
            quantity: 20,
            value: 500,
          ),
        ];
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();
      await setup(tester, ReportsPage(controller: controller));
      await tester.scrollUntilVisible(find.text('Synthetic category'), 200);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
