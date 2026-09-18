import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../platform/database_factory.dart';
import '../services/database_crypto.dart';
import '../services/sales_service.dart';
import '../services/stock_movement_service.dart';

class CsvImportResult {
  const CsvImportResult({required this.imported, required this.skippedDuplicates});
  final int imported;
  final List<String> skippedDuplicates;
}

class DatabaseService {
  static const int inventoryPageSize = 50;
  static const int auditPageSize = 100;
  static const int historyPageSize = 50;

  DatabaseFactory? _factory;
  Database? _db;
  String? _path;
  DatabaseCrypto? _crypto;
  final StockMovementService _stockMovements = const StockMovementService();
  late final SalesService _sales = SalesService(_stockMovements);

  Database get db => _db ?? (throw StateError('Database is not initialized.'));
  DatabaseFactory get factory => _factory ?? (throw StateError('Database factory is not initialized.'));
  String get path => _path ?? '';

  Future<void> initialize({
    bool sandbox = false,
    String? legacyPassphrase,
  }) async {
    final info = await createSmartStockDatabaseFactory(sandbox: sandbox);
    _factory = info.factory;
    _path = info.path;
    _crypto = DatabaseCrypto(factory, path);
    await _crypto!.decryptIfNeeded(legacyPassphrase: legacyPassphrase);
    await _open();
  }

  Future<void> _open() async {
    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
          // DELETE journal mode keeps backups/restores self-contained as one DB file.
          await database.rawQuery('PRAGMA journal_mode = DELETE');
        },
        onCreate: (database, version) async => _createSchema(database),
        onUpgrade: (database, oldVersion, newVersion) async => _migrate(database),
        onOpen: (database) async {
          await _migrate(database);
          await _seedCategories(database);
        },
      ),
    );
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS Category (
        CategoryID INTEGER PRIMARY KEY AUTOINCREMENT,
        CategoryName TEXT UNIQUE
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS Supplier (
        SupplierID INTEGER PRIMARY KEY AUTOINCREMENT,
        SupplierName TEXT NOT NULL,
        ContactEmail TEXT,
        Phone TEXT,
        Notes TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS Item (
        ItemID INTEGER PRIMARY KEY AUTOINCREMENT,
        ItemName TEXT,
        SKU TEXT,
        Quantity INTEGER,
        UnitPrice REAL,
        CategoryID INTEGER,
        ReorderLevel INTEGER NOT NULL DEFAULT 5,
        FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS InventoryLedger (
        LedgerID INTEGER PRIMARY KEY AUTOINCREMENT,
        ItemID INTEGER,
        ItemNameSnapshot TEXT,
        DeltaQuantity INTEGER,
        PriceSnapshot REAL,
        ChangeType TEXT,
        Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        SupplierID INTEGER,
        SourceType TEXT,
        SourceID INTEGER,
        SourceRef TEXT,
        Notes TEXT,
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID) ON DELETE SET NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE IF NOT EXISTS Sale (
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
    await database.execute('''
      CREATE TABLE IF NOT EXISTS SaleItem (
        SaleItemID INTEGER PRIMARY KEY AUTOINCREMENT,
        SaleID INTEGER NOT NULL,
        ItemID INTEGER,
        ItemNameSnapshot TEXT NOT NULL,
        SKUSnapshot TEXT,
        Quantity INTEGER NOT NULL,
        UnitPrice REAL NOT NULL,
        Subtotal REAL NOT NULL,
        FOREIGN KEY (SaleID) REFERENCES Sale(SaleID) ON DELETE CASCADE,
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID) ON DELETE SET NULL
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_sale_timestamp ON Sale(Timestamp)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_saleitem_sale ON SaleItem(SaleID)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_ledger_item ON InventoryLedger(ItemID)');
    await _seedCategories(database);
  }

  Future<void> _migrate(Database database) async {
    final ledgerInfo = await database.rawQuery('PRAGMA table_info(InventoryLedger)');
    final ledgerCols = ledgerInfo.map((e) => e['name']?.toString()).toSet();
    if (!ledgerCols.contains('ItemNameSnapshot')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN ItemNameSnapshot TEXT');
    }
    if (!ledgerCols.contains('SupplierID')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN SupplierID INTEGER');
    }
    if (!ledgerCols.contains('SourceType')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN SourceType TEXT');
    }
    if (!ledgerCols.contains('SourceID')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN SourceID INTEGER');
    }
    if (!ledgerCols.contains('SourceRef')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN SourceRef TEXT');
    }
    if (!ledgerCols.contains('Notes')) {
      await database.execute('ALTER TABLE InventoryLedger ADD COLUMN Notes TEXT');
    }

    final itemInfo = await database.rawQuery('PRAGMA table_info(Item)');
    final itemCols = itemInfo.map((e) => e['name']?.toString()).toSet();
    if (!itemCols.contains('ReorderLevel')) {
      await database.execute('ALTER TABLE Item ADD COLUMN ReorderLevel INTEGER NOT NULL DEFAULT 5');
    }
    if (!itemCols.contains('SKU')) {
      await database.execute('ALTER TABLE Item ADD COLUMN SKU TEXT');
    }

    await database.execute('''
      CREATE TABLE IF NOT EXISTS Sale (
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
    await database.execute('''
      CREATE TABLE IF NOT EXISTS SaleItem (
        SaleItemID INTEGER PRIMARY KEY AUTOINCREMENT,
        SaleID INTEGER NOT NULL,
        ItemID INTEGER,
        ItemNameSnapshot TEXT NOT NULL,
        SKUSnapshot TEXT,
        Quantity INTEGER NOT NULL,
        UnitPrice REAL NOT NULL,
        Subtotal REAL NOT NULL,
        FOREIGN KEY (SaleID) REFERENCES Sale(SaleID) ON DELETE CASCADE,
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID) ON DELETE SET NULL
      )
    ''');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_sale_timestamp ON Sale(Timestamp)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_saleitem_sale ON SaleItem(SaleID)');
    await database.execute('CREATE INDEX IF NOT EXISTS idx_ledger_item ON InventoryLedger(ItemID)');
  }

  Future<void> _seedCategories(DatabaseExecutor executor) async {
    final count = Sqflite.firstIntValue(await executor.rawQuery('SELECT COUNT(*) FROM Category')) ?? 0;
    if (count == 0) {
      final batch = executor.batch();
      for (final name in ['Electronics', 'Stationery', 'Groceries', 'Hardware']) {
        batch.insert('Category', {'CategoryName': name});
      }
      await batch.commit(noResult: true);
    }
  }


  Future<List<CategoryRecord>> getCategories() async {
    final rows = await db.rawQuery('SELECT CategoryID, CategoryName FROM Category ORDER BY CategoryName');
    return rows.map(CategoryRecord.fromMap).toList();
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Category name is required.');
    await db.insert('Category', {'CategoryName': trimmed});
  }

  Future<void> removeCategory(String name) async {
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID '
          'WHERE Category.CategoryName=?',
          [name],
        )) ??
        0;
    if (count > 0) {
      throw StateError("'$name' is used by $count item(s). Reassign or delete them first.");
    }
    await db.delete('Category', where: 'CategoryName=?', whereArgs: [name]);
  }

  Future<InventoryPage> getInventoryPage({String search = '', int page = 0}) async {
    final clean = search.trim();
    final where = clean.isEmpty
        ? ''
        : ' WHERE (Item.ItemName LIKE ? OR Category.CategoryName LIKE ? OR Item.SKU LIKE ?)';
    final args = clean.isEmpty ? <Object?>[] : List<Object?>.filled(3, '%$clean%');
    const from = ' FROM Item JOIN Category ON Item.CategoryID = Category.CategoryID';
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*)$from$where', args)) ?? 0;
    final offset = page * inventoryPageSize;
    final rows = await db.rawQuery(
      'SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName, '
      'Item.Quantity, Item.UnitPrice, Item.ReorderLevel$from$where '
      'ORDER BY Item.ItemID LIMIT ? OFFSET ?',
      [...args, inventoryPageSize, offset],
    );
    return InventoryPage(items: rows.map(InventoryItem.fromMap).toList(), total: total);
  }

  Future<List<InventoryItem>> getAllInventory() async {
    final rows = await db.rawQuery(
      'SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName, '
      'Item.Quantity, Item.UnitPrice, Item.ReorderLevel '
      'FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID ORDER BY Item.ItemID',
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<InventoryItem?> findItemBySku(String sku) async {
    final rows = await db.rawQuery(
      'SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName, '
      'Item.Quantity, Item.UnitPrice, Item.ReorderLevel '
      'FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID WHERE Item.SKU = ? COLLATE NOCASE LIMIT 1',
      [sku.trim()],
    );
    return rows.isEmpty ? null : InventoryItem.fromMap(rows.first);
  }

  Future<List<InventoryItem>> getInventoryItemsByIds(Iterable<int> ids) async {
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return const [];
    final placeholders = List.filled(unique.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName, '
      'Item.Quantity, Item.UnitPrice, Item.ReorderLevel '
      'FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID '
      'WHERE Item.ItemID IN ($placeholders)',
      unique,
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<List<InventoryItem>> searchSaleInventory(String search, {int limit = 24}) async {
    final clean = search.trim();
    final args = <Object?>[];
    var where = '';
    if (clean.isNotEmpty) {
      where = ' WHERE (Item.ItemName LIKE ? OR Category.CategoryName LIKE ? OR Item.SKU LIKE ?)';
      args.addAll(List<Object?>.filled(3, '%$clean%'));
    }
    final rows = await db.rawQuery(
      'SELECT Item.ItemID, Item.SKU, Item.ItemName, Category.CategoryName, '
      'Item.Quantity, Item.UnitPrice, Item.ReorderLevel '
      'FROM Item JOIN Category ON Item.CategoryID=Category.CategoryID$where '
      'ORDER BY CASE WHEN Item.Quantity > 0 THEN 0 ELSE 1 END, Item.ItemName COLLATE NOCASE LIMIT ?',
      [...args, limit],
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<int> _categoryId(DatabaseExecutor executor, String category) async {
    final rows = await executor.rawQuery('SELECT CategoryID FROM Category WHERE CategoryName=?', [category]);
    if (rows.isEmpty) throw StateError('Category not found: $category');
    return (rows.first['CategoryID'] as num).toInt();
  }

  String generateSku() {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    final rng = Random.secure();
    const hex = '0123456789ABCDEF';
    final suffix = List.generate(8, (_) => hex[rng.nextInt(hex.length)]).join();
    return 'SS-$date-$suffix';
  }

  Future<int> addItem({
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Item name cannot be empty.');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    if (unitPrice < 0) throw ArgumentError('Unit price cannot be negative.');
    if (reorderLevel < 0) throw ArgumentError('Reorder level cannot be negative.');
    return db.transaction((txn) async {
      final categoryId = await _categoryId(txn, category);
      final sku = generateSku();
      final itemId = await txn.insert('Item', {
        'ItemName': trimmed,
        'SKU': sku,
        // Quantity is always moved through StockMovementService.
        'Quantity': 0,
        'UnitPrice': unitPrice,
        'CategoryID': categoryId,
        'ReorderLevel': reorderLevel,
      });
      await _stockMovements.apply(
        txn,
        StockMovementRequest(
          itemId: itemId,
          deltaQuantity: quantity,
          priceSnapshot: unitPrice,
          changeType: 'CREATE',
          sourceType: 'ITEM',
          sourceId: itemId,
          sourceReference: sku,
          notes: 'Opening quantity at item creation.',
          writeZeroDelta: true,
        ),
      );
      return itemId;
    });
  }

  Future<void> updateItem({
    required int itemId,
    required String name,
    required String category,
    required int quantity,
    required double unitPrice,
    required int reorderLevel,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Item name cannot be empty.');
    if (quantity < 0) throw ArgumentError('Quantity cannot be negative.');
    if (unitPrice < 0) throw ArgumentError('Unit price cannot be negative.');
    if (reorderLevel < 0) throw ArgumentError('Reorder level cannot be negative.');

    await db.transaction((txn) async {
      final old = await txn.rawQuery(
        'SELECT Quantity, UnitPrice FROM Item WHERE ItemID=?',
        [itemId],
      );
      if (old.isEmpty) throw StateError('Item not found.');
      final oldQuantity = ((old.first['Quantity'] ?? 0) as num).toInt();
      final oldPrice = ((old.first['UnitPrice'] ?? 0) as num).toDouble();
      final categoryId = await _categoryId(txn, category);

      // Metadata can be edited here, but quantity itself is changed only by the
      // central StockMovementService below.
      await txn.update(
        'Item',
        {
          'ItemName': trimmed,
          'UnitPrice': unitPrice,
          'CategoryID': categoryId,
          'ReorderLevel': reorderLevel,
        },
        where: 'ItemID=?',
        whereArgs: [itemId],
      );

      final delta = quantity - oldQuantity;
      if (delta != 0 || unitPrice != oldPrice) {
        await _stockMovements.apply(
          txn,
          StockMovementRequest(
            itemId: itemId,
            deltaQuantity: delta,
            priceSnapshot: unitPrice,
            changeType: 'MANUAL_EDIT',
            sourceType: 'ITEM_EDIT',
            sourceId: itemId,
            notes: delta == 0
                ? 'Unit price changed by manual item edit.'
                : 'Quantity changed by manual item edit.',
            writeZeroDelta: unitPrice != oldPrice,
          ),
        );
      }
    });
  }

  Future<void> deleteItem(int itemId) => db.delete('Item', where: 'ItemID=?', whereArgs: [itemId]);


  Future<KpiSnapshot> getKpis() async {
    final totals = await db.rawQuery('SELECT SUM(Quantity) AS Qty, SUM(Quantity*UnitPrice) AS Value FROM Item');
    final low = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Item WHERE Quantity < ReorderLevel')) ?? 0;
    return KpiSnapshot(
      totalQuantity: ((totals.first['Qty'] ?? 0) as num).toInt(),
      lowStockCount: low,
      totalValue: ((totals.first['Value'] ?? 0) as num).toDouble(),
    );
  }

  Future<List<CategorySummary>> getCategorySummaries() async {
    final rows = await db.rawQuery('''
      SELECT Category.CategoryName AS CategoryName,
             COALESCE(SUM(Item.Quantity), 0) AS Quantity,
             COALESCE(SUM(Item.Quantity * Item.UnitPrice), 0) AS Value
      FROM Category JOIN Item ON Item.CategoryID=Category.CategoryID
      GROUP BY Category.CategoryID, Category.CategoryName
      ORDER BY Category.CategoryName
    ''');
    return rows
        .map((r) => CategorySummary(
              category: (r['CategoryName'] ?? '').toString(),
              quantity: ((r['Quantity'] ?? 0) as num).toInt(),
              value: ((r['Value'] ?? 0) as num).toDouble(),
            ))
        .toList();
  }

  Future<List<LowStockThreat>> getLowStockThreats() async {
    final rows = await db.rawQuery('''
      SELECT ItemName, Quantity, ReorderLevel FROM Item
      ORDER BY CAST(Quantity AS REAL) / MAX(ReorderLevel, 1) ASC LIMIT 5
    ''');
    return rows
        .map((r) => LowStockThreat(
              name: (r['ItemName'] ?? '').toString(),
              quantity: ((r['Quantity'] ?? 0) as num).toInt(),
              reorderLevel: ((r['ReorderLevel'] ?? 5) as num).toInt(),
            ))
        .toList();
  }

  Future<CsvImportResult> importInventoryRows(List<Map<String, String>> rows) async {
    final incomingNames = rows.map((e) => (e['ItemName'] ?? '').trim()).where((e) => e.isNotEmpty).toSet();
    final existing = <String>{};
    if (incomingNames.isNotEmpty) {
      final placeholders = List.filled(incomingNames.length, '?').join(',');
      final found = await db.rawQuery(
        'SELECT ItemName FROM Item WHERE ItemName IN ($placeholders)',
        incomingNames.toList(),
      );
      existing.addAll(found.map((e) => (e['ItemName'] ?? '').toString()));
    }
    final skipped = <String>[];
    var imported = 0;
    await db.transaction((txn) async {
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final rowNumber = index + 2;
        final name = (row['ItemName'] ?? '').trim();
        final category = (row['Category'] ?? '').trim();
        final quantity = int.tryParse((row['Quantity'] ?? '').trim());
        final price = double.tryParse((row['UnitPrice'] ?? '').trim());
        if (name.isEmpty) throw FormatException('Row $rowNumber: ItemName is blank.');
        if (category.isEmpty) throw FormatException('Row $rowNumber: Category is blank.');
        if (quantity == null || quantity < 0) throw FormatException('Row $rowNumber: Quantity must be a non-negative integer.');
        if (price == null || price < 0) throw FormatException('Row $rowNumber: UnitPrice must be a non-negative number.');
        if (existing.contains(name)) {
          skipped.add(name);
          continue;
        }
        var categoryRows = await txn.rawQuery('SELECT CategoryID FROM Category WHERE CategoryName=?', [category]);
        int categoryId;
        if (categoryRows.isEmpty) {
          categoryId = await txn.insert('Category', {'CategoryName': category});
        } else {
          categoryId = (categoryRows.first['CategoryID'] as num).toInt();
        }
        final sku = generateSku();
        final itemId = await txn.insert('Item', {
          'ItemName': name,
          'SKU': sku,
          'Quantity': 0,
          'UnitPrice': price,
          'CategoryID': categoryId,
          'ReorderLevel': 5,
        });
        await _stockMovements.apply(
          txn,
          StockMovementRequest(
            itemId: itemId,
            deltaQuantity: quantity,
            priceSnapshot: price,
            changeType: 'CSV_IMPORT',
            sourceType: 'CSV_IMPORT',
            sourceReference: 'inventory.csv',
            notes: 'Opening quantity imported from CSV.',
            writeZeroDelta: true,
          ),
        );
        imported++;
        existing.add(name);
      }
    });
    return CsvImportResult(imported: imported, skippedDuplicates: skipped);
  }

  Future<List<String>> getAuditItemNames() async {
    final rows = await db.rawQuery('''
      SELECT DISTINCT COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]') AS ItemName
      FROM InventoryLedger il LEFT JOIN Item i ON il.ItemID=i.ItemID
      ORDER BY ItemName
    ''');
    return rows.map((e) => (e['ItemName'] ?? '').toString()).toList();
  }

  ({String sql, List<Object?> args}) _auditWhere(AuditFilter filter) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (filter.itemName != null && filter.itemName!.isNotEmpty) {
      clauses.add("COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]') = ?");
      args.add(filter.itemName);
    }
    if (filter.changeType != null && filter.changeType!.isNotEmpty) {
      clauses.add('il.ChangeType = ?');
      args.add(filter.changeType);
    }
    clauses.add('date(il.Timestamp) >= date(?)');
    clauses.add('date(il.Timestamp) <= date(?)');
    args.add(DateFormat('yyyy-MM-dd').format(filter.dateFrom));
    args.add(DateFormat('yyyy-MM-dd').format(filter.dateTo));
    return (sql: clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}', args: args);
  }

  Future<LedgerPage> getAuditPage({required AuditFilter filter, int page = 0}) async {
    final where = _auditWhere(filter);
    const from = ' FROM InventoryLedger il LEFT JOIN Item i ON il.ItemID=i.ItemID';
    final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*)$from${where.sql}', where.args)) ?? 0;
    final rows = await db.rawQuery(
      '''SELECT il.LedgerID AS LedgerID, il.Timestamp AS Timestamp,
      COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]') AS ItemName,
      COALESCE(i.SKU, '—') AS SKU, il.ChangeType AS ChangeType,
      il.DeltaQuantity AS DeltaQuantity, il.PriceSnapshot AS PriceSnapshot,
      il.SourceType AS SourceType, il.SourceID AS SourceID,
      il.SourceRef AS SourceRef, il.Notes AS Notes,
      SUM(il.DeltaQuantity) OVER (
        PARTITION BY il.ItemID ORDER BY il.LedgerID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS RunningBalance
      $from${where.sql}
      ORDER BY il.LedgerID DESC LIMIT ? OFFSET ?''',
      [...where.args, auditPageSize, page * auditPageSize],
    );
    return LedgerPage(entries: rows.map(LedgerEntry.fromMap).toList(), total: total);
  }

  Future<List<LedgerEntry>> getAllAuditEntries(AuditFilter filter) async {
    final where = _auditWhere(filter);
    const from = ' FROM InventoryLedger il LEFT JOIN Item i ON il.ItemID=i.ItemID';
    final rows = await db.rawQuery(
      '''SELECT il.LedgerID AS LedgerID, il.Timestamp AS Timestamp,
      COALESCE(i.ItemName, il.ItemNameSnapshot, '[Deleted Item]') AS ItemName,
      COALESCE(i.SKU, '—') AS SKU, il.ChangeType AS ChangeType,
      il.DeltaQuantity AS DeltaQuantity, il.PriceSnapshot AS PriceSnapshot,
      il.SourceType AS SourceType, il.SourceID AS SourceID,
      il.SourceRef AS SourceRef, il.Notes AS Notes,
      SUM(il.DeltaQuantity) OVER (
        PARTITION BY il.ItemID ORDER BY il.LedgerID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS RunningBalance
      $from${where.sql} ORDER BY il.LedgerID''',
      where.args,
    );
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<ItemHistorySnapshot> getItemHistory(int itemId, {int page = 0}) async {
    final currentRows = await db.rawQuery('SELECT Quantity FROM Item WHERE ItemID=?', [itemId]);
    final current = currentRows.isEmpty ? 0 : ((currentRows.first['Quantity'] ?? 0) as num).toInt();
    final stats = await db.rawQuery('''
      SELECT COUNT(*) AS Total,
      COALESCE(SUM(CASE WHEN DeltaQuantity > 0 THEN DeltaQuantity ELSE 0 END), 0) AS Added,
      COALESCE(SUM(CASE WHEN DeltaQuantity < 0 THEN -DeltaQuantity ELSE 0 END), 0) AS Removed
      FROM InventoryLedger WHERE ItemID=?
    ''', [itemId]);
    final total = ((stats.first['Total'] ?? 0) as num).toInt();
    final rows = await db.rawQuery('''
      SELECT LedgerID, Timestamp, '' AS ItemName, '' AS SKU, ChangeType,
             DeltaQuantity, PriceSnapshot, SourceType, SourceID, SourceRef, Notes,
             SUM(DeltaQuantity) OVER (
               PARTITION BY ItemID ORDER BY LedgerID
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             ) AS RunningBalance
      FROM InventoryLedger WHERE ItemID=?
      ORDER BY LedgerID DESC LIMIT ? OFFSET ?
    ''', [itemId, historyPageSize, page * historyPageSize]);
    return ItemHistorySnapshot(
      currentQuantity: current,
      totalAdded: ((stats.first['Added'] ?? 0) as num).toInt(),
      totalRemoved: ((stats.first['Removed'] ?? 0) as num).toInt(),
      entries: rows.map(LedgerEntry.fromMap).toList(),
      totalEntries: total,
    );
  }

  Future<List<LedgerEntry>> getAllItemHistory(int itemId) async {
    final rows = await db.rawQuery('''
      SELECT LedgerID, Timestamp, '' AS ItemName, '' AS SKU, ChangeType,
             DeltaQuantity, PriceSnapshot, SourceType, SourceID, SourceRef, Notes,
             SUM(DeltaQuantity) OVER (
               PARTITION BY ItemID ORDER BY LedgerID
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
             ) AS RunningBalance
      FROM InventoryLedger WHERE ItemID=? ORDER BY LedgerID
    ''', [itemId]);
    return rows.map(LedgerEntry.fromMap).toList();
  }

  Future<void> rollbackLedgerEntry(int ledgerId) async {
    await db.transaction((txn) async {
      final ledgerRows = await txn.rawQuery(
        'SELECT ItemID, DeltaQuantity, PriceSnapshot, ChangeType, SourceType, SourceID, SourceRef '
        'FROM InventoryLedger WHERE LedgerID=?',
        [ledgerId],
      );
      if (ledgerRows.isEmpty) throw StateError('Ledger entry not found.');
      final row = ledgerRows.first;
      final changeType = (row['ChangeType'] ?? '').toString();
      if (changeType == 'SALE') {
        throw StateError('Sale movements must be voided from Sales so the whole transaction stays consistent.');
      }
      if (changeType == 'ROLLBACK_REVERSAL') {
        throw StateError('A rollback reversal cannot itself be rolled back.');
      }
      final itemIdValue = row['ItemID'];
      if (itemIdValue == null) {
        throw StateError('The associated item was deleted. Rollback is not possible.');
      }
      final itemId = (itemIdValue as num).toInt();
      final originalDelta = ((row['DeltaQuantity'] ?? 0) as num).toInt();
      if (originalDelta == 0) {
        throw StateError('This ledger entry has no quantity change to roll back.');
      }
      final inverse = -originalDelta;
      final price = ((row['PriceSnapshot'] ?? 0) as num).toDouble();

      await _stockMovements.apply(
        txn,
        StockMovementRequest(
          itemId: itemId,
          deltaQuantity: inverse,
          priceSnapshot: price,
          changeType: 'ROLLBACK_REVERSAL',
          sourceType: 'LEDGER',
          sourceId: ledgerId,
          sourceReference: 'LEDGER-$ledgerId',
          notes: 'Reversal of ledger entry #$ledgerId.',
          writeZeroDelta: true,
        ),
      );
    });
  }

  Future<SaleRecord> completeSale(List<SaleDraftLine> lines, {String notes = ''}) =>
      _sales.completeSale(db, lines, notes: notes);

  Future<List<SaleRecord>> getRecentSales({int limit = 30}) async {
    final rows = await db.rawQuery(
      'SELECT SaleID, SaleNumber, Timestamp, TotalAmount, TotalItems, Status, Notes, VoidedAt '
      'FROM Sale ORDER BY SaleID DESC LIMIT ?',
      [limit],
    );
    return rows.map(SaleRecord.fromMap).toList();
  }

  Future<SaleDetail> getSaleDetail(int saleId) async {
    final saleRows = await db.rawQuery(
      'SELECT SaleID, SaleNumber, Timestamp, TotalAmount, TotalItems, Status, Notes, VoidedAt '
      'FROM Sale WHERE SaleID=? LIMIT 1',
      [saleId],
    );
    if (saleRows.isEmpty) throw StateError('Sale not found.');
    final itemRows = await db.rawQuery(
      'SELECT SaleItemID, SaleID, ItemID, ItemNameSnapshot, SKUSnapshot, Quantity, UnitPrice, Subtotal '
      'FROM SaleItem WHERE SaleID=? ORDER BY SaleItemID',
      [saleId],
    );
    return SaleDetail(
      sale: SaleRecord.fromMap(saleRows.first),
      lines: itemRows.map(SaleLineRecord.fromMap).toList(),
    );
  }

  Future<void> voidSale(int saleId) => _sales.voidSale(db, saleId);

  Future<List<SupplierRecord>> getSuppliers() async {
    final rows = await db.rawQuery(
      'SELECT SupplierID, SupplierName, ContactEmail, Phone, Notes FROM Supplier ORDER BY SupplierName',
    );
    return rows.map(SupplierRecord.fromMap).toList();
  }

  Future<void> saveSupplier({int? id, required String name, String email = '', String phone = '', String notes = ''}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Company name is required.');
    final values = {
      'SupplierName': trimmed,
      'ContactEmail': email.trim(),
      'Phone': phone.trim(),
      'Notes': notes.trim(),
    };
    if (id == null) {
      await db.insert('Supplier', values);
    } else {
      await db.update('Supplier', values, where: 'SupplierID=?', whereArgs: [id]);
    }
  }

  Future<void> deleteSupplier(int id) => db.delete('Supplier', where: 'SupplierID=?', whereArgs: [id]);

  Future<void> resetInventory() => db.delete('Item');

  Future<List<int>> backupBytes() async {
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    return factory.readDatabaseBytes(path);
  }

  Future<void> restorePlaintextDatabase(List<int> bytes) async {
    // Keep the current database bytes so a malformed legacy import cannot
    // destroy a working SmartStock database.
    final previousBytes = await factory.readDatabaseBytes(path);
    await _db?.close();
    _db = null;
    try {
      await factory.writeDatabaseBytes(path, Uint8List.fromList(bytes));
      await _open();
      // Force a basic schema read so invalid/non-SmartStock files fail here.
      await db.rawQuery('SELECT CategoryID, CategoryName FROM Category LIMIT 1');
      await db.rawQuery('SELECT ItemID, ItemName FROM Item LIMIT 1');
    } catch (_) {
      await _db?.close();
      _db = null;
      if (previousBytes.isNotEmpty) {
        await factory.writeDatabaseBytes(path, Uint8List.fromList(previousBytes));
        await _open();
      }
      rethrow;
    }
  }

  Future<void> close({bool encrypt = true}) async {
    final database = _db;
    if (database == null) return;
    // Detach synchronously so repeated lifecycle notifications cannot encrypt twice.
    _db = null;
    await database.close();
    if (encrypt && _crypto != null) {
      await _crypto!.encryptAndDeletePlaintext();
    }
  }
}
