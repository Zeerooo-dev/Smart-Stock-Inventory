import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartstock_flutter/services/stock_movement_service.dart';

void main() {
  sqfliteFfiInit();

  test('StockMovementService updates quantity and ledger atomically', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
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
    await db.insert('Item', {
      'ItemID': 1,
      'ItemName': 'USB Cable',
      'SKU': 'USB-1',
      'Quantity': 10,
      'UnitPrice': 100.0,
    });

    const service = StockMovementService();
    await db.transaction((txn) async {
      final result = await service.apply(
        txn,
        const StockMovementRequest(
          itemId: 1,
          deltaQuantity: -3,
          changeType: 'SALE',
          sourceType: 'SALE',
          sourceId: 9,
          sourceReference: 'SALE-000009',
        ),
      );
      expect(result.oldQuantity, 10);
      expect(result.newQuantity, 7);
    });

    final item = (await db.query('Item', where: 'ItemID=?', whereArgs: [1])).single;
    expect(item['Quantity'], 7);

    final ledger = (await db.query('InventoryLedger')).single;
    expect(ledger['ChangeType'], 'SALE');
    expect(ledger['DeltaQuantity'], -3);
    expect(ledger['SourceRef'], 'SALE-000009');
  });

  test('StockMovementService blocks negative inventory without writing a ledger row', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
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
    await db.insert('Item', {
      'ItemID': 1,
      'ItemName': 'USB Cable',
      'SKU': 'USB-1',
      'Quantity': 2,
      'UnitPrice': 100.0,
    });

    const service = StockMovementService();
    await expectLater(
      () => db.transaction((txn) => service.apply(
            txn,
            const StockMovementRequest(
              itemId: 1,
              deltaQuantity: -3,
              changeType: 'SALE',
            ),
          )),
      throwsStateError,
    );

    final item = (await db.query('Item', where: 'ItemID=?', whereArgs: [1])).single;
    expect(item['Quantity'], 2);
    expect(await db.query('InventoryLedger'), isEmpty);
  });
}
