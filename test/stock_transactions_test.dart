import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/data/database_service.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/services/export_service.dart';
import 'package:smartstock_flutter/services/notification_service.dart';
import 'package:smartstock_flutter/state/smartstock_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final allDates = AuditFilter(dateFrom: DateTime(2000), dateTo: DateTime(2100));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late DatabaseService db;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('smartstock-test-');
    db = DatabaseService.forTesting(databaseFactoryFfi, '${temp.path}/test.db');
    await db.initialize();
  });
  tearDown(() async {
    await db.close(encrypt: false);
    await temp.delete(recursive: true);
  });

  Future<int> mouse({int quantity = 20}) => db.addItem(
    name: 'Mouse',
    category: 'Electronics',
    quantity: quantity,
    unitPrice: 500,
    reorderLevel: 5,
  );

  test(
    'atomic snapshots: restock 20 +10 =30; dispense 30 -6 =24, independent of filters',
    () async {
      final id = await mouse();
      await db.adjustStock(
        itemId: id,
        amount: 10,
        restock: true,
        notes: 'Delivery',
      );
      await db.adjustStock(
        itemId: id,
        amount: 6,
        restock: false,
        notes: 'Issued',
      );
      final entries = await db.getReportTransactions();
      expect(
        entries.map(
          (e) => [e.quantityBefore, e.deltaQuantity, e.quantityAfter],
        ),
        [
          [0, 20, 20],
          [20, 10, 30],
          [30, -6, 24],
        ],
      );
      final filtered = await db.getAllAuditEntries(
        AuditFilter(
          dateFrom: DateTime(2000),
          dateTo: DateTime(2100),
          changeType: 'DISPENSE',
        ),
      );
      expect(filtered.single.quantityBefore, 30);
      expect(filtered.single.quantityAfter, 24);
      expect((await db.getItemHistory(id)).entries.first.quantityAfter, 24);
      final sku = entries.last.sku;
      await db.deleteItem(id);
      final deleted = (await db.getReportTransactions()).last;
      expect(deleted.sku, sku);
      expect(deleted.itemName, 'Mouse');
      expect(deleted.changeType, 'DELETE');
      expect(
        [deleted.quantityBefore, deleted.deltaQuantity, deleted.quantityAfter],
        [24, -24, 0],
      );
      expect(
        (await db.getReportTransactions())
            .where((e) => e.changeType == 'DISPENSE')
            .single
            .quantityAfter,
        24,
      );
    },
  );

  test(
    'deletion refreshes Audit and preserves identity with DELETE filtering',
    () async {
      final id = await mouse();
      final item = (await db.getAllInventory()).single;
      // Simulate earlier history with no identity snapshots.
      await db.db.update('InventoryLedger', {
        'ItemNameSnapshot': null,
        'SkuSnapshot': null,
      });
      final controller = SmartStockController(database: db);
      addTearDown(controller.dispose);
      controller.auditFilter = allDates;
      await controller.deleteItem(item);
      expect(controller.inventoryPage.items, isEmpty);
      expect(controller.auditPage.entries.first.changeType, 'DELETE');
      expect(controller.auditPage.entries, hasLength(2));
      expect(
        controller.auditPage.entries.every(
          (e) => e.itemName == 'Mouse' && e.sku == item.sku,
        ),
        isTrue,
      );
      final filtered = await db.getAuditPage(
        filter: AuditFilter(
          dateFrom: allDates.dateFrom,
          dateTo: allDates.dateTo,
          changeType: 'DELETE',
          itemName: 'Mouse',
        ),
      );
      expect(filtered.entries.single.quantityBefore, 20);
      await expectLater(db.deleteItem(id), throwsStateError);
      expect(await db.getReportTransactions(), hasLength(2));
      await expectLater(
        db.rollbackLedgerEntry(filtered.entries.single.ledgerId),
        throwsStateError,
      );
    },
  );

  test(
    'failed deletion or deletion logging leaves inventory and ledger intact',
    () async {
      final id = await mouse();
      await db.db.execute(
        "CREATE TRIGGER fail_delete BEFORE DELETE ON Item BEGIN SELECT RAISE(ABORT, 'test delete failure'); END",
      );
      await expectLater(db.deleteItem(id), throwsA(isA<Exception>()));
      expect((await db.getAllInventory()).single.quantity, 20);
      expect(await db.getReportTransactions(), hasLength(1));
      await db.db.execute('DROP TRIGGER fail_delete');
      await db.db.execute(
        "CREATE TRIGGER fail_log BEFORE INSERT ON InventoryLedger WHEN NEW.ChangeType = 'DELETE' BEGIN SELECT RAISE(ABORT, 'test log failure'); END",
      );
      await expectLater(db.deleteItem(id), throwsA(isA<Exception>()));
      expect((await db.getAllInventory()).single.quantity, 20);
      expect(await db.getReportTransactions(), hasLength(1));
    },
  );

  test('reset records deletions including zero-stock items', () async {
    await mouse(quantity: 0);
    await db.addItem(
      name: 'Cable',
      category: 'Electronics',
      quantity: 4,
      unitPrice: 10,
      reorderLevel: 5,
    );
    await db.resetInventory();
    expect(await db.getAllInventory(), isEmpty);
    final deletions = (await db.getReportTransactions())
        .where((e) => e.changeType == 'DELETE')
        .toList();
    expect(deletions, hasLength(2));
    expect(
      deletions.map(
        (e) => [e.quantityBefore, e.deltaQuantity, e.quantityAfter],
      ),
      [
        [0, 0, 0],
        [4, -4, 0],
      ],
    );
  });

  test(
    'overselling, missing items, invalid amounts/prices leave inventory and history intact',
    () async {
      final id = await mouse(quantity: 3);
      await expectLater(
        db.adjustStock(itemId: id, amount: 5, restock: false),
        throwsStateError,
      );
      await expectLater(
        db.adjustStock(itemId: id, amount: 0, restock: true),
        throwsArgumentError,
      );
      await expectLater(
        db.adjustStock(itemId: 999, amount: 1, restock: true),
        throwsStateError,
      );
      await expectLater(
        db.addItem(
          name: 'Bad',
          category: 'Electronics',
          quantity: 0,
          unitPrice: double.nan,
          reorderLevel: 5,
        ),
        throwsArgumentError,
      );
      await expectLater(
        db.updateItem(
          itemId: id,
          name: 'Mouse',
          category: 'Electronics',
          quantity: 3,
          unitPrice: -1,
          reorderLevel: 5,
        ),
        throwsArgumentError,
      );
      expect((await db.getAllInventory()).single.quantity, 3);
      expect(await db.getReportTransactions(), hasLength(1));
    },
  );

  test('a failed ledger insert rolls back the inventory update', () async {
    final id = await mouse();
    await db.db.execute(
      "CREATE TRIGGER reject_stock BEFORE INSERT ON InventoryLedger WHEN NEW.ChangeType = 'RESTOCK' BEGIN SELECT RAISE(ABORT, 'test ledger failure'); END",
    );
    await expectLater(
      db.adjustStock(itemId: id, amount: 10, restock: true),
      throwsA(isA<Exception>()),
    );
    expect((await db.getAllInventory()).single.quantity, 20);
    expect(await db.getReportTransactions(), hasLength(1));
  });

  test('concurrent dispensations serialize and cannot oversell', () async {
    final id = await mouse(quantity: 5);
    final outcomes = await Future.wait(
      List.generate(2, (_) async {
        try {
          await db.adjustStock(itemId: id, amount: 4, restock: false);
          return true;
        } catch (_) {
          return false;
        }
      }),
    );
    expect(outcomes.where((ok) => ok), hasLength(1));
    expect((await db.getAllInventory()).single.quantity, 1);
    expect((await db.getReportTransactions()).last.quantityBefore, 5);
  });

  test(
    'migration preserves legacy data and unknown quantities; reopening is idempotent',
    () async {
      await db.close(encrypt: false);
      final legacyPath = '${temp.path}/legacy.db';
      final legacy = await databaseFactoryFfi.openDatabase(legacyPath);
      await legacy.execute(
        'CREATE TABLE Category(CategoryID INTEGER PRIMARY KEY, CategoryName TEXT)',
      );
      await legacy.execute("INSERT INTO Category VALUES(1, 'Electronics')");
      await legacy.execute(
        'CREATE TABLE Supplier(SupplierID INTEGER PRIMARY KEY, SupplierName TEXT, ContactEmail TEXT, Phone TEXT, Notes TEXT)',
      );
      await legacy.execute(
        "INSERT INTO Supplier VALUES(1, 'Supply Co', '', '', 'Keep notes')",
      );
      await legacy.execute(
        'CREATE TABLE Item(ItemID INTEGER PRIMARY KEY, ItemName TEXT, Quantity INTEGER, UnitPrice REAL, CategoryID INTEGER)',
      );
      await legacy.execute(
        "INSERT INTO Item VALUES(1, 'Old Mouse', 20, 500, 1)",
      );
      await legacy.execute(
        'CREATE TABLE InventoryLedger(LedgerID INTEGER PRIMARY KEY, ItemID INTEGER, DeltaQuantity INTEGER, PriceSnapshot REAL, ChangeType TEXT, Timestamp TEXT)',
      );
      await legacy.execute(
        "INSERT INTO InventoryLedger VALUES(1, 1, 7, 500, 'RESTOCK', '2020-01-01 00:00:00')",
      );
      await legacy.execute('PRAGMA user_version=1');
      await legacy.close();
      db = DatabaseService.forTesting(databaseFactoryFfi, legacyPath);
      await db.initialize();
      expect((await db.getAllInventory()).single.quantity, 20);
      expect((await db.getSuppliers()).single.notes, 'Keep notes');
      final old = (await db.getReportTransactions()).single;
      expect(old.beforeText, 'N/A');
      expect(old.afterText, 'N/A');
      await db.adjustStock(itemId: 1, amount: 10, restock: true);
      await db.close(encrypt: false);
      await db.initialize();
      expect((await db.getReportTransactions()).last.quantityBefore, 20);
      expect((await db.getReportTransactions()).last.quantityAfter, 30);
      expect(await db.getReportTransactions(), hasLength(2));
    },
  );

  test(
    'manual edit, import and rollback also store consistent snapshots',
    () async {
      final id = await mouse();
      await db.updateItem(
        itemId: id,
        name: 'Mouse',
        category: 'Electronics',
        quantity: 25,
        unitPrice: 500,
        reorderLevel: 5,
      );
      final edit = (await db.getReportTransactions()).last;
      expect(
        [edit.quantityBefore, edit.deltaQuantity, edit.quantityAfter],
        [20, 5, 25],
      );
      await db.rollbackLedgerEntry(edit.ledgerId);
      final reversal = (await db.getReportTransactions()).last;
      expect(
        [
          reversal.quantityBefore,
          reversal.deltaQuantity,
          reversal.quantityAfter,
        ],
        [25, -5, 20],
      );
      await db.importInventoryRows([
        {
          'ItemName': 'Cable',
          'Category': 'Electronics',
          'Quantity': '10',
          'UnitPrice': '20',
        },
      ]);
      expect((await db.getReportTransactions()).last.quantityBefore, 0);
    },
  );

  test(
    'controller immediately reports 6 to 3 low stock and rearms after restock',
    () async {
      final notifications = NotificationService();
      final messages = <String>[];
      notifications.onNotification = (title, message) {
        if (title == 'Low Stock Alert') messages.add(message);
      };
      final controller = SmartStockController(
        database: db,
        notifications: notifications,
      );
      addTearDown(controller.dispose);
      final id = await mouse(quantity: 6);
      await controller.lowStockMonitor.check(notify: false);
      await controller.adjustStock(
        (await db.getAllInventory()).single,
        3,
        restock: false,
      );
      expect(messages.single, contains('Only 3 units'));
      final entry = (await db.getReportTransactions()).last;
      expect(
        [entry.quantityBefore, entry.deltaQuantity, entry.quantityAfter],
        [6, -3, 3],
      );
      await controller.lowStockMonitor.check();
      expect(messages, hasLength(1));
      await db.adjustStock(itemId: id, amount: 4, restock: true);
      await controller.lowStockMonitor.check();
      await controller.adjustStock(
        (await db.getAllInventory()).single,
        4,
        restock: false,
      );
      expect(messages, hasLength(2));
    },
  );

  test(
    'a migration failure rolls back all added columns and preserves old rows',
    () async {
      final path = '${temp.path}/broken.db';
      final broken = await databaseFactoryFfi.openDatabase(path);
      await broken.execute(
        'CREATE TABLE InventoryLedger(LedgerID INTEGER PRIMARY KEY, DeltaQuantity INTEGER)',
      );
      await broken.execute('INSERT INTO InventoryLedger VALUES(1, 10)');
      await broken.execute('PRAGMA user_version=1');
      await broken.close();
      final service = DatabaseService.forTesting(databaseFactoryFfi, path);
      await expectLater(service.initialize(), throwsA(isA<Exception>()));
      final reopened = await databaseFactoryFfi.openDatabase(path);
      final columns = await reopened.rawQuery(
        'PRAGMA table_info(InventoryLedger)',
      );
      expect(columns.map((c) => c['name']), ['LedgerID', 'DeltaQuantity']);
      expect(
        (await reopened.query('InventoryLedger')).single['DeltaQuantity'],
        10,
      );
      await reopened.close();
    },
  );

  test(
    'PDF generation failure does not invoke save or send a success notification',
    () async {
      final notifications = NotificationService();
      final messages = <String>[];
      notifications.onNotification = (title, _) => messages.add(title);
      final controller = SmartStockController(
        database: db,
        exports: BrokenPdfExport(db),
        notifications: notifications,
      );
      addTearDown(controller.dispose);
      await expectLater(controller.exportAuditPdf(), throwsStateError);
      expect(messages, isEmpty);
    },
  );

  test(
    'XLSX and PDF export paths preserve stored transaction values and styles',
    () async {
      final id = await mouse();
      await db.adjustStock(
        itemId: id,
        amount: 10,
        restock: true,
        notes: 'Delivery ₱500',
      );
      await db.adjustStock(
        itemId: id,
        amount: 6,
        restock: false,
        notes: 'Issued',
      );
      final saved = <String, Uint8List>{};
      final exports = ExportService(
        db,
        save: (name, bytes, ext) async {
          saved[name] = bytes;
          await File('${temp.path}/$name').writeAsBytes(bytes);
          return Uri.file('${temp.path}/$name');
        },
      );
      final controller = SmartStockController(database: db, exports: exports);
      addTearDown(controller.dispose);
      controller.auditFilter = allDates;
      await exports.exportItemHistoryXlsx(id, 'Mouse');
      await db.deleteItem(id);
      await controller.exportInventoryXlsx();
      await controller.exportInventoryPdf();
      await controller.exportAuditXlsx();
      await controller.exportAuditPdf();
      expect(saved, hasLength(5));
      for (final name in [
        'inventory_report.xlsx',
        'smartstock_audit_ledger.xlsx',
        'history_Mouse.xlsx',
      ]) {
        final workbook = xl.Excel.decodeBytes(saved[name]!);
        final sheet =
            workbook.tables[name == 'inventory_report.xlsx'
                ? 'Transaction History'
                : name == 'smartstock_audit_ledger.xlsx'
                ? 'Audit Ledger'
                : 'Item History']!;
        expect(sheet.frozenRows, 1);
        final cells = sheet.rows;
        final rows = cells
            .map(
              (row) =>
                  row.map((cell) => cell?.value?.toString() ?? '').toList(),
            )
            .toList();
        final header = rows.first;
        expect(header, ExportService.transactionHeaders);
        final type = header.indexOf('Transaction Type');
        final before = header.indexOf('Quantity Before');
        final change = header.indexOf('Quantity Changed');
        final after = header.indexOf('Quantity After');
        for (final expected in [
          ['RESTOCK', '20', '10', '30'],
          ['DISPENSE', '30', '-6', '24'],
          if (name != 'history_Mouse.xlsx') ['DELETE', '24', '-24', '0'],
        ]) {
          expect(
            rows.any((r) => r[type] == expected[0]),
            isTrue,
            reason: '$name is missing ${expected[0]}; rows: $rows',
          );
          final row = rows.singleWhere((r) => r[type] == expected[0]);
          expect([
            row[before].toString(),
            row[change].toString(),
            row[after].toString(),
          ], expected.sublist(1));
        }
        for (final row in cells.skip(1)) {
          final kind = row[type]!.value.toString();
          expect(row[change]!.value, isA<xl.IntCellValue>());
          expect(
            row[change]!.cellStyle!.numberFormat.formatCode,
            '+#,##0.##;-#,##0.##;0',
          );
          expect(row[2]!.cellStyle!.numberFormat.formatCode, '₱#,##0.00');
          expect(row[before]!.cellStyle!.numberFormat.formatCode, '#,##0.##');
          expect(row[change]!.cellStyle!.backgroundColor, xl.ExcelColor.none);
          expect(row[type]!.cellStyle!.backgroundColor, xl.ExcelColor.none);
          expect(row[before]!.cellStyle!.backgroundColor, xl.ExcelColor.none);
          final positive = (row[change]!.value as xl.IntCellValue).value > 0;
          expect(
            row[change]!.cellStyle!.fontColor,
            xl.ExcelColor.fromHexString(positive ? 'FF006100' : 'FF9C0006'),
          );
          if (kind == 'CREATE' || kind == 'DISPENSE') {
            expect(
              row[type]!.cellStyle!.fontColor,
              xl.ExcelColor.fromHexString(
                kind == 'CREATE' ? 'FF006100' : 'FF9C0006',
              ),
            );
          }
          expect(
            row[after]!.cellStyle!.backgroundColor,
            kind == 'DELETE'
                ? xl.ExcelColor.fromHexString('FFFFC7CE')
                : xl.ExcelColor.none,
          );
        }
      }
      // Optional Poppler verification of the actual rendered document text. Set
      // SMARTSTOCK_PDF_QA=1 locally; normal Flutter CI does not require Poppler.
      if (Platform.environment['SMARTSTOCK_PDF_QA'] == '1') {
        for (final name in [
          'smartstock_report.pdf',
          'smartstock_audit_report.pdf',
        ]) {
          final result = Process.runSync('pdftotext', [
            '-layout',
            '${temp.path}/$name',
            '-',
          ]);
          expect(result.exitCode, 0);
          final text = result.stdout as String;
          final raw =
              Process.runSync('pdftotext', [
                    '-raw',
                    '${temp.path}/$name',
                    '-',
                  ]).stdout
                  as String;
          expect(raw, matches(RegExp(r'Quantity\s+Before')));
          expect(raw, matches(RegExp(r'Quantity\s+After')));
          expect(
            text,
            matches(RegExp(r'₱500\.00\s+20\s+\+10\s+30\s+[^\n]+RESTOCK')),
          );
          expect(
            text,
            matches(RegExp(r'₱500\.00\s+30\s+-6\s+24\s+[^\n]+DISPENSE')),
          );
          expect(
            text,
            matches(RegExp(r'₱500\.00\s+24\s+-24\s+0\s+[^\n]+DELETE')),
          );
        }
        final qa = Directory('/tmp/smartstock-pdf-qa')..createSync();
        for (final e in saved.entries) {
          File('${qa.path}/${e.key}').writeAsBytesSync(e.value);
        }
      }
    },
  );

  test(
    'inventory importer accepts CSV and the exported XLSX Inventory sheet',
    () async {
      await db.addItem(
        name: 'Spreadsheet source',
        category: 'Hardware',
        quantity: 1250,
        unitPrice: 1234.50,
        reorderLevel: 5,
      );
      final source = ExportService(db);
      final xlsx = await source.buildInventoryXlsx();
      final audit = await source.buildAuditXlsx(allDates);
      final target = DatabaseService.forTesting(
        databaseFactoryFfi,
        '${temp.path}/import-target.db',
      );
      await target.initialize();
      try {
        final importer = ExportService(target);
        final spreadsheet = await importer.importInventoryBytes(
          xlsx,
          extension: 'xlsx',
        );
        expect(spreadsheet.imported, 1);
        final imported = (await target.getAllInventory()).single;
        expect(
          (imported.name, imported.quantity, imported.unitPrice),
          ('Spreadsheet source', 1250, 1234.50),
        );
        final duplicate = await importer.importInventoryBytes(
          xlsx,
          extension: 'xlsx',
        );
        expect(duplicate.imported, 0);
        expect(duplicate.skippedDuplicates, ['Spreadsheet source']);

        final csv = Uint8List.fromList(
          utf8.encode(
            'ItemName,Category,Quantity,UnitPrice\n'
            'CSV source,Hardware,2,25.50\n',
          ),
        );
        expect(
          (await importer.importInventoryBytes(csv, extension: 'csv')).imported,
          1,
        );
      expect((await target.getAllInventory()).length, 2);
      final otherSheet = xl.Excel.createExcel()..rename('Sheet1', 'Warehouse');
      otherSheet.appendRow('Warehouse', [
        xl.TextCellValue('ItemName'),
        xl.TextCellValue('Category'),
        xl.TextCellValue('Quantity'),
        xl.TextCellValue('UnitPrice'),
      ]);
      otherSheet.appendRow('Warehouse', [
        xl.TextCellValue('Warehouse source'),
        xl.TextCellValue('Hardware'),
        xl.IntCellValue(3),
        xl.DoubleCellValue(40.25),
      ]);
      expect((await importer.importInventoryBytes(
        Uint8List.fromList(otherSheet.encode()!),
        extension: 'xlsx',
      )).imported, 1);
      expect((await target.getAllInventory()).length, 3);
      await expectLater(
          importer.importInventoryBytes(audit, extension: 'xlsx'),
          throwsA(isA<FormatException>()),
        );
      } finally {
        await target.close(encrypt: false);
      }
    },
  );

  test(
    'large audit PDF spans more than 20 pages, repeats headings and keeps long notes',
    () async {
      final id = await mouse();
      final sku = (await db.getAllInventory()).single.sku;
      final batch = db.db.batch();
      for (var i = 0; i < 850; i++) {
        batch.insert('InventoryLedger', {
          'ItemID': id,
          'ItemNameSnapshot': 'Mouse',
          'SkuSnapshot': sku,
          'DeltaQuantity': 1,
          'QuantityBefore': 20 + i,
          'QuantityAfter': 21 + i,
          'PriceSnapshot': 500,
          'ChangeType': 'RESTOCK',
          'Notes': i == 849
              ? '${'Long note. ' * 100}${'Line break.\n' * 100}END-NOTE'
              : 'Delivery $i',
        });
      }
      await batch.commit(noResult: true);
      final bytes = await ExportService(db).buildAuditPdf(allDates);
      expect(bytes.length, greaterThan(10000));
      if (Platform.environment['SMARTSTOCK_PDF_QA'] == '1') {
        Directory('/tmp/smartstock-pdf-qa').createSync(recursive: true);
        final file = File('/tmp/smartstock-pdf-qa/large-audit.pdf');
        await file.writeAsBytes(bytes);
        final text =
            Process.runSync('pdftotext', ['-layout', file.path, '-']).stdout
                as String;
        expect(
          'SmartStock Audit Report'.allMatches(text).length,
          greaterThan(20),
        );
        final raw =
            Process.runSync('pdftotext', ['-raw', file.path, '-']).stdout
                as String;
        expect(
          RegExp(r'Quantity\s+Before').allMatches(raw).length,
          greaterThan(20),
        );
        expect(text, contains('END-NOTE'));
      }
    },
  );

  test(
    'export cancellation/failure never notifies; successful saves notify once',
    () async {
      await mouse();
      final notifications = NotificationService();
      final messages = <String>[];
      notifications.onNotification = (title, message) => messages.add(title);
      for (final pdf in [false, true]) {
        for (final mode in ['cancel', 'unwritable', 'success']) {
          final exports = ExportService(
            db,
            save: (name, bytes, ext) async {
              if (mode == 'cancel') return null;
              if (mode == 'unwritable') {
                return File(
                  '${temp.path}/missing/$name',
                ).writeAsBytes(bytes).then((f) => f.uri);
              }
              return Uri.file('${temp.path}/$name');
            },
          );
          final controller = SmartStockController(
            database: db,
            exports: exports,
            notifications: notifications,
          );
          controller.auditFilter = allDates;
          final previous = messages.length;
          final action = pdf
              ? controller.exportAuditPdf()
              : controller.exportAuditXlsx();
          if (mode == 'unwritable') {
            await expectLater(action, throwsA(isA<FileSystemException>()));
          } else {
            await action;
          }
          expect(messages.length, previous + (mode == 'success' ? 1 : 0));
          controller.dispose();
        }
      }
    },
  );

  test(
    'add confirmation follows successful commit; notification failure cannot fail a write',
    () async {
      final notifications = NotificationService();
      final titles = <String>[];
      notifications.onNotification = (title, _) => titles.add(title);
      final controller = SmartStockController(
        database: db,
        notifications: notifications,
      );
      addTearDown(controller.dispose);
      await controller.addItem(
        name: 'Mouse',
        category: 'Electronics',
        quantity: 20,
        unitPrice: 500,
        reorderLevel: 5,
      );
      expect(titles, ['Item Added Successfully']);
      expect(controller.inventoryPage.items.single.quantity, 20);
      await expectLater(
        controller.addItem(
          name: 'Bad',
          category: 'Electronics',
          quantity: -1,
          unitPrice: 500,
          reorderLevel: 5,
        ),
        throwsArgumentError,
      );
      expect(titles, hasLength(1));
      notifications.onNotification = (_, _) => throw StateError('Unavailable');
      await controller.addItem(
        name: 'Keyboard',
        category: 'Electronics',
        quantity: 20,
        unitPrice: 500,
        reorderLevel: 5,
      );
      expect(await db.getAllInventory(), hasLength(2));
    },
  );
}

class BrokenPdfExport extends ExportService {
  BrokenPdfExport(super.database);
  @override
  Future<Uint8List> buildAuditPdf(AuditFilter filter) async =>
      throw StateError('PDF failed');
}
