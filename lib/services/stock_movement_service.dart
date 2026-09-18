import 'package:sqflite_common/sqlite_api.dart';

class StockMovementRequest {
  const StockMovementRequest({
    required this.itemId,
    required this.deltaQuantity,
    required this.changeType,
    this.priceSnapshot,
    this.sourceType,
    this.sourceId,
    this.sourceReference,
    this.notes,
    this.allowNegative = false,
    this.writeZeroDelta = false,
  });

  final int itemId;
  final int deltaQuantity;
  final String changeType;
  final double? priceSnapshot;
  final String? sourceType;
  final int? sourceId;
  final String? sourceReference;
  final String? notes;
  final bool allowNegative;
  final bool writeZeroDelta;
}

class StockMovementResult {
  const StockMovementResult({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.oldQuantity,
    required this.newQuantity,
    required this.unitPrice,
    required this.deltaQuantity,
  });

  final int itemId;
  final String itemName;
  final String sku;
  final int oldQuantity;
  final int newQuantity;
  final double unitPrice;
  final int deltaQuantity;
}

/// The single write path for inventory quantity changes.
///
/// Callers provide an already-open [DatabaseExecutor] (usually a transaction).
/// The stock update and immutable ledger entry therefore succeed or fail together.
class StockMovementService {
  const StockMovementService();

  static const writableChangeTypes = <String>{
    'CREATE',
    'MANUAL_EDIT',
    'CSV_IMPORT',
    'SALE',
    'ROLLBACK_REVERSAL',
  };

  Future<StockMovementResult> apply(
    DatabaseExecutor executor,
    StockMovementRequest request,
  ) async {
    if (!writableChangeTypes.contains(request.changeType)) {
      throw ArgumentError.value(
        request.changeType,
        'changeType',
        'Unsupported stock movement type',
      );
    }

    final rows = await executor.rawQuery(
      'SELECT ItemName, SKU, Quantity, UnitPrice FROM Item WHERE ItemID=? LIMIT 1',
      [request.itemId],
    );
    if (rows.isEmpty) {
      throw StateError('Inventory item #${request.itemId} was not found.');
    }

    final row = rows.first;
    final itemName = (row['ItemName'] ?? '').toString();
    final sku = (row['SKU'] ?? '').toString();
    final oldQuantity = ((row['Quantity'] ?? 0) as num).toInt();
    final unitPrice = request.priceSnapshot ?? ((row['UnitPrice'] ?? 0) as num).toDouble();
    final newQuantity = oldQuantity + request.deltaQuantity;

    if (!request.allowNegative && newQuantity < 0) {
      final requested = -request.deltaQuantity;
      throw StateError(
        'Insufficient stock for $itemName. Requested $requested unit(s), but only $oldQuantity are available.',
      );
    }

    if (request.deltaQuantity != 0) {
      await executor.rawUpdate(
        'UPDATE Item SET Quantity=? WHERE ItemID=?',
        [newQuantity, request.itemId],
      );
    }

    if (request.deltaQuantity != 0 || request.writeZeroDelta) {
      await executor.insert('InventoryLedger', {
        'ItemID': request.itemId,
        'ItemNameSnapshot': itemName,
        'DeltaQuantity': request.deltaQuantity,
        'PriceSnapshot': unitPrice,
        'ChangeType': request.changeType,
        'SourceType': request.sourceType,
        'SourceID': request.sourceId,
        'SourceRef': request.sourceReference,
        'Notes': request.notes,
      });
    }

    return StockMovementResult(
      itemId: request.itemId,
      itemName: itemName,
      sku: sku,
      oldQuantity: oldQuantity,
      newQuantity: newQuantity,
      unitPrice: unitPrice,
      deltaQuantity: request.deltaQuantity,
    );
  }
}
