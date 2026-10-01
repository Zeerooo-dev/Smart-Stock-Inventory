import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/data/database_service.dart';
import 'package:smartstock_flutter/core/app_theme.dart';
import 'package:smartstock_flutter/ui/widgets/dialogs.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/state/smartstock_controller.dart';
import 'package:smartstock_flutter/ui/pages/inventory_page.dart';

const mouse = InventoryItem(
  id: 1,
  sku: 'WM-001',
  name: 'Mouse',
  category: 'Electronics',
  quantity: 20,
  unitPrice: 500,
  reorderLevel: 5,
);

class UiDatabase extends DatabaseService {
  InventoryItem current = mouse;
  @override
  Future<List<InventoryItem>> getAllInventory() async => [current];
  @override
  Future<InventoryItem?> findItemById(int id) async => id == 1 ? current : null;
}

class UiController extends SmartStockController {
  UiController({UiDatabase? database})
    : super(database: database ?? UiDatabase()) {
    categories = [const CategoryRecord(id: 1, name: 'Electronics')];
    inventoryPage = const InventoryPage(items: [mouse], total: 1);
    loading = false;
  }
  int added = 0;
  int updated = 0;
  @override
  Future<void> adjustStock(
    InventoryItem item,
    int amount, {
    required bool restock,
    String notes = '',
  }) async {
    final db = database as UiDatabase;
    final quantity = db.current.quantity + (restock ? amount : -amount);
    if (quantity < 0) throw StateError('Not enough stock.');
    db.current = InventoryItem(
      id: item.id,
      sku: item.sku,
      name: item.name,
      category: item.category,
      quantity: quantity,
      unitPrice: item.unitPrice,
      reorderLevel: item.reorderLevel,
    );
    inventoryPage = InventoryPage(items: [db.current], total: 1);
    notifyListeners();
  }

  @override
  Future<void> addItem({
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    expect(name, 'Keyboard');
    expect(quantity, 25);
    expect(unitPrice, 499.99);
    added++;
    notifyListeners();
  }

  @override
  Future<void> updateItem({
    required int itemId,
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    expect(itemId, 1);
    updated++;
    notifyListeners();
  }
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
String value(WidgetTester tester, String label) =>
    field(label).evaluate().isEmpty
    ? ''
    : tester.widget<TextField>(field(label)).controller!.text;

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} row activation is view-only; only Item Actions Edit populates form',
      (tester) async {
        tester.view.physicalSize = Size(mobile ? 420 : 1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = UiController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: AnimatedBuilder(
                animation: controller,
                builder: (_, _) => InventoryPageView(controller: controller),
              ),
            ),
          ),
        );
        expect(value(tester, 'Quantity'), '');
        expect(value(tester, 'Unit Price (PHP)'), '');
        expect(field('Quantity'), findsNothing);
        expect(find.text('Restock'), findsNothing);
        expect(find.text('Dispense'), findsNothing);
        expect(find.byType(BarcodeWidget), findsNothing);
        if (mobile) {
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('inventory-avatar-1')))
                .data,
            'M',
          );
          expect(find.text('Qty: 20'), findsOneWidget);
        }
        await tester.ensureVisible(find.text('Mouse'));
        await tester.tap(find.text('Mouse'));
        await tester.pumpAndSettle();
        expect(find.text('Item Details'), findsOneWidget);
        expect(find.text('Current Quantity: 20'), findsOneWidget);
        expect(find.text('Restock'), findsOneWidget);
        expect(find.text('Dispense'), findsOneWidget);
        expect(
          tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).data,
          'WM-001'.codeUnits,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          findsNothing,
        );
        expect(value(tester, 'Item Name'), '');
        expect(value(tester, 'Quantity'), '');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        // Repeated mouse activation must never turn into editing.
        await tester.tap(find.text('Mouse'));
        await tester.tap(find.text('Mouse'), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('Item Details'), findsOneWidget);
        expect(value(tester, 'Item Name'), '');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        // Keyboard activation shares the same read-only handler.
        Focus.of(tester.element(find.text('Mouse'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Item Details'), findsOneWidget);
        expect(value(tester, 'Item Name'), '');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Mouse'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('Item Details'), findsOneWidget);
        expect(value(tester, 'Quantity'), '');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Item actions'));
        await tester.tap(find.byTooltip('Item actions'));
        await tester.pumpAndSettle();
        expect(value(tester, 'Item Name'), '');
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        expect(value(tester, 'Item Name'), 'Mouse');
        expect(value(tester, 'Quantity'), '20');
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(controller.updated, 1);
        expect(value(tester, 'Item Name'), '');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'details stock controls refresh the preview and handle cancellation and failure',
    (tester) async {
      tester.view.physicalSize = const Size(420, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemDetailsDialog(
                  context,
                  mouse,
                  controller: controller,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Current Quantity: 20'), findsOneWidget);
      await tester.tap(find.text('Restock'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10');
      await tester.ensureVisible(find.text('Confirm restock'));
      await tester.tap(find.text('Confirm restock'));
      await tester.pumpAndSettle();
      expect(find.text('Current Quantity: 30'), findsOneWidget);
      expect(find.text('Inventory Value: ₱15000.00'), findsOneWidget);
      await tester.tap(find.text('Dispense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '27');
      await tester.ensureVisible(find.text('Confirm dispense'));
      await tester.tap(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      expect(find.text('Current Quantity: 3'), findsOneWidget);
      expect(find.text('Stock Status: Low stock'), findsOneWidget);
      await tester.tap(find.text('Dispense'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '5');
      await tester.ensureVisible(find.text('Confirm dispense'));
      await tester.tap(find.text('Confirm dispense'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not enough stock'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Current Quantity: 3'), findsOneWidget);
      expect(
        tester.widget<BarcodeWidget>(find.byType(BarcodeWidget)).data,
        'WM-001'.codeUnits,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inventory icons use name initials, with quantity in a separate badge',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = UiController();
      addTearDown(controller.dispose);
      controller.inventoryPage = const InventoryPage(
        items: [
          InventoryItem(
            id: 1,
            sku: 'WM-001',
            name: 'Wireless Mouse',
            category: 'Electronics',
            quantity: 42,
            unitPrice: 500,
            reorderLevel: 5,
          ),
        ],
        total: 1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InventoryPageView(controller: controller)),
        ),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('inventory-avatar-1')))
            .data,
        'WM',
      );
      expect(find.text('Qty: 42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in SmartStockTheme.values) {
    testWidgets('read-only details fit ${theme.name} on a small screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: SmartStockThemes.build(theme),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showItemDetailsDialog(
                  context,
                  mouse,
                  controller: controller,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Item Details'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets(
    'Add Item accepts immediate input, resets after success and rejects bad input',
    (tester) async {
      tester.view.physicalSize = const Size(1450, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = UiController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (_, _) => InventoryPageView(controller: controller),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(controller.added, 0);
      await tester.enterText(field('Item Name'), 'Keyboard');
      await tester.enterText(field('Quantity'), '25');
      await tester.enterText(field('Unit Price (PHP)'), '499.99');
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();
      expect(controller.added, 1);
      expect(value(tester, 'Item Name'), '');
      expect(value(tester, 'Quantity'), '');
      expect(value(tester, 'Unit Price (PHP)'), '');
      expect(tester.takeException(), isNull);
    },
  );
}
