import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/models.dart';
import 'stock_movement_service.dart';

/// Owns the transactional business rules for checkout and sale voids.
///
/// Sales never update Item.Quantity directly. Every stock change is delegated
/// to [StockMovementService] inside the same SQLite transaction as the Sale and
/// SaleItem rows, so checkout either commits completely or not at all.
class SalesService {
  const SalesService(this.stockMovements);

  final StockMovementService stockMovements;

  Future<SaleRecord> completeSale(
    Database database,
    List<SaleDraftLine> lines, {
    String notes = '',
  }) async {
    if (lines.isEmpty) {
      throw ArgumentError('Add at least one item to the sale.');
    }

    final combined = <int, int>{};
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Sale quantities must be greater than zero.');
      }
      combined.update(
        line.itemId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    final cleanNotes = notes.trim();
    return database.transaction((txn) async {
      // SaleID is the durable sequence. A temporary unique number lets us get
      // that ID without maintaining a second counter table.
      final pendingNumber =
          'PENDING-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(999999)}';
      final saleId = await txn.insert('Sale', {
        'SaleNumber': pendingNumber,
        'TotalAmount': 0.0,
        'TotalItems': 0,
        'Status': 'COMPLETED',
        'Notes': cleanNotes,
      });
      final saleNumber = 'SALE-${saleId.toString().padLeft(6, '0')}';
      await txn.update(
        'Sale',
        {'SaleNumber': saleNumber},
        where: 'SaleID=?',
        whereArgs: [saleId],
      );

      var total = 0.0;
      var totalItems = 0;
      for (final entry in combined.entries) {
        final quantity = entry.value;
        final movement = await stockMovements.apply(
          txn,
          StockMovementRequest(
            itemId: entry.key,
            deltaQuantity: -quantity,
            changeType: 'SALE',
            sourceType: 'SALE',
            sourceId: saleId,
            sourceReference: saleNumber,
            notes: cleanNotes.isEmpty ? 'Sold through Quick Checkout.' : cleanNotes,
          ),
        );
        final subtotal = movement.unitPrice * quantity;
        await txn.insert('SaleItem', {
          'SaleID': saleId,
          'ItemID': movement.itemId,
          'ItemNameSnapshot': movement.itemName,
          'SKUSnapshot': movement.sku,
          'Quantity': quantity,
          'UnitPrice': movement.unitPrice,
          'Subtotal': subtotal,
        });
        total += subtotal;
        totalItems += quantity;
      }

      await txn.update(
        'Sale',
        {'TotalAmount': total, 'TotalItems': totalItems},
        where: 'SaleID=?',
        whereArgs: [saleId],
      );

      final rows = await txn.rawQuery(
        'SELECT SaleID, SaleNumber, Timestamp, TotalAmount, TotalItems, Status, Notes, VoidedAt '
        'FROM Sale WHERE SaleID=?',
        [saleId],
      );
      return SaleRecord.fromMap(rows.first);
    });
  }

  Future<void> voidSale(Database database, int saleId) async {
    await database.transaction((txn) async {
      final saleRows = await txn.rawQuery(
        'SELECT SaleNumber, Status FROM Sale WHERE SaleID=? LIMIT 1',
        [saleId],
      );
      if (saleRows.isEmpty) throw StateError('Sale not found.');

      final saleNumber = (saleRows.first['SaleNumber'] ?? '').toString();
      final status = (saleRows.first['Status'] ?? '').toString().toUpperCase();
      if (status == 'VOIDED') {
        throw StateError('$saleNumber is already voided.');
      }
      if (status != 'COMPLETED') {
        throw StateError('$saleNumber cannot be voided from status $status.');
      }

      final lines = await txn.rawQuery(
        'SELECT ItemID, Quantity, UnitPrice FROM SaleItem WHERE SaleID=? ORDER BY SaleItemID',
        [saleId],
      );
      if (lines.isEmpty) throw StateError('$saleNumber has no sale lines.');

      // Validate every product before applying any reversal. This gives a clear
      // error before the first stock movement and keeps the void all-or-nothing.
      for (final line in lines) {
        if (line['ItemID'] == null) {
          throw StateError(
            'Cannot void $saleNumber because one of its products was deleted.',
          );
        }
        final itemId = (line['ItemID'] as num).toInt();
        final exists = Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM Item WHERE ItemID=?',
                [itemId],
              ),
            ) ??
            0;
        if (exists == 0) {
          throw StateError(
            'Cannot void $saleNumber because product #$itemId no longer exists.',
          );
        }
      }

      for (final line in lines) {
        final itemId = (line['ItemID'] as num).toInt();
        final quantity = ((line['Quantity'] ?? 0) as num).toInt();
        final price = ((line['UnitPrice'] ?? 0) as num).toDouble();
        await stockMovements.apply(
          txn,
          StockMovementRequest(
            itemId: itemId,
            deltaQuantity: quantity,
            priceSnapshot: price,
            changeType: 'ROLLBACK_REVERSAL',
            sourceType: 'SALE_VOID',
            sourceId: saleId,
            sourceReference: saleNumber,
            notes: 'Voided $saleNumber and restored sold stock.',
          ),
        );
      }

      await txn.rawUpdate(
        "UPDATE Sale SET Status='VOIDED', VoidedAt=CURRENT_TIMESTAMP WHERE SaleID=?",
        [saleId],
      );
    });
  }
}
