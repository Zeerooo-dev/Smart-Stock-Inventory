import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/services/sales_service.dart';
import 'package:smartstock_flutter/services/stock_movement_service.dart';

Future<Database> _openSalesTestDatabase() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE Item (
      ItemID INTEGER PRIMARY KEY,
      ItemName TEXT,
      SKU TEXT,
      Quantity INTEGER,
      UnitPrice REAL
    )
  ''');
  await db.execute('''
    CREATE TABLE InventoryLedger (
      LedgerID INTEGER PRIMARY KEY AUTOINCREMENT,
      ItemID INTEGER,
      ItemNameSnapshot TEXT,
      DeltaQuantity INTEGER,
      PriceSnapshot REAL,
      ChangeType TEXT,
      SourceType TEXT,
      SourceID INTEGER,
      SourceRef TEXT,
      Notes TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE Sale (
      SaleID INTEGER PRIMARY KEY AUTOINCREMENT,
      SaleNumber TEXT NOT NULL UNIQUE,
      Timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      TotalAmount REAL NOT NULL DEFAULT 0,
      TotalItems INTEGER NOT NULL DEFAULT 0,
      Status TEXT NOT NULL DEFAULT 'COMPLETED',
      Notes TEXT,
      VoidedAt DATETIME
    )
  ''');
  await db.execute('''
    CREATE TABLE SaleItem (
      SaleItemID INTEGER PRIMARY KEY AUTOINCREMENT,
      SaleID INTEGER NOT NULL,
      ItemID INTEGER,
      ItemNameSnapshot TEXT NOT NULL,
      SKUSnapshot TEXT,
      Quantity INTEGER NOT NULL,
      UnitPrice REAL NOT NULL,
      Subtotal REAL NOT NULL
    )
  ''');
  return db;
}

Future<void> _insertItem(
  Database db, {
  required int id,
  required String name,
  required int quantity,
  required double price,
}) async {
  await db.insert('Item', {
    'ItemID': id,
    'ItemName': name,
    'SKU': 'SKU-$id',
    'Quantity': quantity,
    'UnitPrice': price,
  });
}

void main() {
  sqfliteFfiInit();

  const service = SalesService(StockMovementService());

  test('checkout deducts all sale lines and writes linked audit rows', () async {
    final db = await _openSalesTestDatabase();
    addTearDown(db.close);
    await _insertItem(db, id: 1, name: 'Cola', quantity: 10, price: 25);
    await _insertItem(db, id: 2, name: 'Chips', quantity: 5, price: 15);

    final sale = await service.completeSale(
      db,
      const [
        SaleDraftLine(itemId: 1, quantity: 3),
        SaleDraftLine(itemId: 2, quantity: 2),
      ],
      notes: 'Counter sale',
    );

    expect(sale.saleNumber, 'SALE-000001');
    expect(sale.totalItems, 5);
    expect(sale.totalAmount, 105);

    final items = await db.query('Item', orderBy: 'ItemID');
    expect(items[0]['Quantity'], 7);
    expect(items[1]['Quantity'], 3);

    final saleLines = await db.query('SaleItem', orderBy: 'SaleItemID');
    expect(saleLines, hasLength(2));
    expect(saleLines[0]['Subtotal'], 75.0);
    expect(saleLines[1]['Subtotal'], 30.0);

    final ledger = await db.query('InventoryLedger', orderBy: 'LedgerID');
    expect(ledger, hasLength(2));
    expect(ledger.every((row) => row['ChangeType'] == 'SALE'), isTrue);
    expect(ledger.every((row) => row['SourceRef'] == 'SALE-000001'), isTrue);
  });

  test('insufficient stock rolls back the entire checkout', () async {
    final db = await _openSalesTestDatabase();
    addTearDown(db.close);
    await _insertItem(db, id: 1, name: 'Cola', quantity: 10, price: 25);
    await _insertItem(db, id: 2, name: 'Chips', quantity: 1, price: 15);

    await expectLater(
      service.completeSale(
        db,
        const [
          SaleDraftLine(itemId: 1, quantity: 3),
          SaleDraftLine(itemId: 2, quantity: 2),
        ],
      ),
      throwsStateError,
    );

    final items = await db.query('Item', orderBy: 'ItemID');
    expect(items[0]['Quantity'], 10);
    expect(items[1]['Quantity'], 1);
    expect(await db.query('Sale'), isEmpty);
    expect(await db.query('SaleItem'), isEmpty);
    expect(await db.query('InventoryLedger'), isEmpty);
  });

  test('void restores all sale stock once and preserves sale history', () async {
    final db = await _openSalesTestDatabase();
    addTearDown(db.close);
    await _insertItem(db, id: 1, name: 'Cola', quantity: 10, price: 25);
    await _insertItem(db, id: 2, name: 'Chips', quantity: 5, price: 15);

    final sale = await service.completeSale(
      db,
      const [
        SaleDraftLine(itemId: 1, quantity: 3),
        SaleDraftLine(itemId: 2, quantity: 2),
      ],
    );

    await service.voidSale(db, sale.id);

    final items = await db.query('Item', orderBy: 'ItemID');
    expect(items[0]['Quantity'], 10);
    expect(items[1]['Quantity'], 5);

    final saleRows = await db.query('Sale', where: 'SaleID=?', whereArgs: [sale.id]);
    expect(saleRows.single['Status'], 'VOIDED');
    expect(saleRows.single['VoidedAt'], isNotNull);

    final ledger = await db.query('InventoryLedger', orderBy: 'LedgerID');
    expect(ledger, hasLength(4));
    expect(ledger.where((row) => row['ChangeType'] == 'SALE'), hasLength(2));
    expect(
      ledger.where((row) => row['ChangeType'] == 'ROLLBACK_REVERSAL'),
      hasLength(2),
    );

    await expectLater(service.voidSale(db, sale.id), throwsStateError);
    expect(await db.query('InventoryLedger'), hasLength(4));
  });
}
