import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/core/app_theme.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/state/smartstock_controller.dart';
import 'package:smartstock_flutter/ui/smartstock_shell.dart';
import 'package:smartstock_flutter/ui/pages/inventory_page.dart';
import 'package:smartstock_flutter/ui/pages/suppliers_page.dart';
import 'package:smartstock_flutter/ui/pages/settings_page.dart';
import 'package:smartstock_flutter/ui/widgets/dialogs.dart';
import 'inventory_ui_test.dart' as fixture;
import 'ui_redesign_test.dart' as regression;

const item = InventoryItem(
  id: 1,
  sku: 'SYNTHETIC-123456',
  name: 'Synthetic inventory fixture',
  category: 'Synthetic category',
  quantity: 123456,
  unitPrice: 1234.56,
  reorderLevel: 5,
);

fixture.UiController controllerFor(AppSection section) {
  final database = regression.RedesignDatabase()..current = item;
  return fixture.UiController(database: database)
    ..section = section
    ..categories = const [CategoryRecord(id: 1, name: 'Synthetic category')]
    ..inventoryPage = const InventoryPage(items: [item], total: 1)
    ..auditPage = const LedgerPage(entries: [regression.largeEntry], total: 1)
    ..auditItemNames = [item.name]
    ..suppliers = const [
      SupplierRecord(
        id: 1,
        name: 'Synthetic supplier',
        email: 'fixture@example.invalid',
        phone: '00000000000',
        notes: 'Synthetic notes',
      ),
    ]
    ..categorySummaries = [
      CategorySummary(
        category: item.category,
        quantity: item.quantity,
        value: item.value,
      ),
    ]
    ..kpis = KpiSnapshot(
      totalQuantity: item.quantity,
      lowStockCount: 0,
      totalValue: item.value,
    );
}

void main() {
  testWidgets(
    'all screens and task dialogs reflow across sizes, text scales, and themes',
    (tester) async {
      await regression.loadRoboto();
      final output = Directory('.dart_tool/ui-review')
        ..createSync(recursive: true);
      final results = <Map<String, Object?>>[];
      final sizes = [
        const Size(320, 640),
        const Size(360, 800),
        const Size(412, 915),
        const Size(800, 1280),
        const Size(1280, 900),
      ];
      Future<void> check(
        String task,
        Size size,
        double scale,
        SmartStockTheme theme, {
        AppSection? section,
      }) async {
        final controller = controllerFor(section ?? AppSection.inventory);
        final errors = <String>[];
        final original = FlutterError.onError;
        final boundaryKey = GlobalKey();
        FlutterError.onError = (details) => errors.add(details.toString());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: SmartStockThemes.build(theme),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: boundaryKey, child: child!),
              ),
              home: section != null
                  ? SmartStockShell(controller: controller)
                  : Scaffold(
                      body: switch (task) {
                        'itemEditor' => InventoryPageView(
                          controller: controller,
                        ),
                        'supplierEditor' => SuppliersPage(
                          controller: controller,
                        ),
                        'rgb' => SettingsPage(controller: controller),
                        _ => Builder(
                          builder: (context) => TextButton(
                            onPressed: () {
                              switch (task) {
                                case 'details':
                                  showItemDetailsDialog(
                                    context,
                                    item,
                                    controller: controller,
                                  );
                                case 'history':
                                  showItemHistoryDialog(
                                    context,
                                    controller,
                                    item,
                                  );
                                case 'confirm':
                                  showSmartConfirm(
                                    context,
                                    message:
                                        "Delete '${item.name}'? Existing audit history is kept and the deletion is recorded.",
                                  );
                                case 'scheduler':
                                  showSchedulerDialog(context, controller);
                                case 'amount':
                                  showStockAmountDialog(
                                    context,
                                    restock: false,
                                    item: item,
                                  );
                                case 'scanner':
                                  showScanner(context, controller);
                              }
                            },
                            child: const Text('Open'),
                          ),
                        ),
                      },
                    ),
            ),
          );
          await tester.pumpAndSettle();
          if (section == null) {
            final label = switch (task) {
              'itemEditor' => 'Add Item',
              'supplierEditor' => 'Add Supplier',
              'rgb' => 'Pick color',
              _ => 'Open',
            };
            if (task == 'rgb') {
              await regression.reveal(tester, find.text(label));
            } else {
              await tester.ensureVisible(find.text(label));
            }
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
          }
          for (final element in find.byType(Scrollable).evaluate().toList()) {
            if (!element.mounted) continue;
            final state = (element as StatefulElement).state as ScrollableState;
            if (state.position.hasContentDimensions &&
                state.position.axis == Axis.vertical) {
              for (var step = 0; step < 20; step++) {
                state.position.jumpTo(state.position.maxScrollExtent);
                await tester.pumpAndSettle();
                if (!element.mounted || state.position.extentAfter < 1) break;
              }
            }
          }
          if (section != null &&
              size == const Size(360, 800) &&
              theme == SmartStockTheme.defaultLight) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              File(
                '${output.path}/$task-${scale.toInt()}x.png',
              ).writeAsBytesSync(data!.buffer.asUint8List());
              image.dispose();
            });
          }
        } catch (error, stack) {
          errors.add('$error\n$stack');
        } finally {
          FlutterError.onError = original;
        }
        results.add({
          'screen': task,
          'width': size.width,
          'height': size.height,
          'scale': scale,
          'theme': theme.name,
          'errors': errors.toSet().toList(),
        });
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }

      for (final size in sizes) {
        for (final orientation in [size, Size(size.height, size.width)]) {
          for (final scale in [1.0, 2.0]) {
            for (final theme in SmartStockTheme.values) {
              for (final section in AppSection.values) {
                await check(
                  section.name,
                  orientation,
                  scale,
                  theme,
                  section: section,
                );
              }
            }
          }
        }
      }
      for (final size in [
        const Size(320, 640),
        const Size(360, 800),
        const Size(640, 320),
        const Size(800, 1280),
        const Size(1280, 900),
      ]) {
        for (final scale in [1.0, 2.0]) {
          for (final theme in SmartStockTheme.values) {
            for (final task in [
              'details',
              'history',
              'confirm',
              'scheduler',
              'amount',
              'scanner',
              'itemEditor',
              'supplierEditor',
              'rgb',
            ]) {
              await check(task, size, scale, theme);
            }
          }
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      File(
        '${output.path}/matrix.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
      final failures = results
          .where((result) => (result['errors'] as List).isNotEmpty)
          .toList();
      expect(
        failures,
        isEmpty,
        reason:
            '${failures.length} of ${results.length} configurations failed; see .dart_tool/ui-review/matrix.json',
      );
    },
  );
}
