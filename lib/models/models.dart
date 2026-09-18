class CategoryRecord {
  const CategoryRecord({required this.id, required this.name});
  final int id;
  final String name;

  factory CategoryRecord.fromMap(Map<String, Object?> m) => CategoryRecord(
        id: (m['CategoryID'] as num).toInt(),
        name: (m['CategoryName'] ?? '').toString(),
      );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.reorderLevel,
  });

  final int id;
  final String sku;
  final String name;
  final String category;
  final int quantity;
  final double unitPrice;
  final int reorderLevel;

  bool get isLowStock => quantity < reorderLevel;
  double get value => quantity * unitPrice;

  factory InventoryItem.fromMap(Map<String, Object?> m) => InventoryItem(
        id: (m['ItemID'] as num).toInt(),
        sku: (m['SKU'] ?? '').toString(),
        name: (m['ItemName'] ?? '').toString(),
        category: (m['CategoryName'] ?? '').toString(),
        quantity: ((m['Quantity'] ?? 0) as num).toInt(),
        unitPrice: ((m['UnitPrice'] ?? 0) as num).toDouble(),
        reorderLevel: ((m['ReorderLevel'] ?? 5) as num).toInt(),
      );
}

class InventoryPage {
  const InventoryPage({required this.items, required this.total});
  final List<InventoryItem> items;
  final int total;
}

class KpiSnapshot {
  const KpiSnapshot({
    required this.totalQuantity,
    required this.lowStockCount,
    required this.totalValue,
  });
  final int totalQuantity;
  final int lowStockCount;
  final double totalValue;

  static const empty = KpiSnapshot(totalQuantity: 0, lowStockCount: 0, totalValue: 0);
}

class CategorySummary {
  const CategorySummary({required this.category, required this.quantity, required this.value});
  final String category;
  final int quantity;
  final double value;
}

class LowStockThreat {
  const LowStockThreat({
    required this.name,
    required this.quantity,
    required this.reorderLevel,
  });
  final String name;
  final int quantity;
  final int reorderLevel;
  double get ratio => quantity / (reorderLevel <= 0 ? 1 : reorderLevel);
}

class LedgerEntry {
  const LedgerEntry({
    required this.ledgerId,
    required this.timestamp,
    required this.itemName,
    required this.sku,
    required this.changeType,
    required this.deltaQuantity,
    required this.priceSnapshot,
    required this.runningBalance,
    this.sourceType = '',
    this.sourceId,
    this.sourceReference = '',
    this.notes = '',
  });

  final int ledgerId;
  final String timestamp;
  final String itemName;
  final String sku;
  final String changeType;
  final int deltaQuantity;
  final double priceSnapshot;
  final int runningBalance;
  final String sourceType;
  final int? sourceId;
  final String sourceReference;
  final String notes;

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        ledgerId: ((m['LedgerID'] ?? 0) as num).toInt(),
        timestamp: (m['Timestamp'] ?? '').toString(),
        itemName: (m['ItemName'] ?? '[Deleted Item]').toString(),
        sku: (m['SKU'] ?? '—').toString(),
        changeType: (m['ChangeType'] ?? '').toString(),
        deltaQuantity: ((m['DeltaQuantity'] ?? 0) as num).toInt(),
        priceSnapshot: ((m['PriceSnapshot'] ?? 0) as num).toDouble(),
        runningBalance: ((m['RunningBalance'] ?? 0) as num).toInt(),
        sourceType: (m['SourceType'] ?? '').toString(),
        sourceId: m['SourceID'] == null ? null : (m['SourceID'] as num).toInt(),
        sourceReference: (m['SourceRef'] ?? '').toString(),
        notes: (m['Notes'] ?? '').toString(),
      );
}

class LedgerPage {
  const LedgerPage({required this.entries, required this.total});
  final List<LedgerEntry> entries;
  final int total;
}

class SupplierRecord {
  const SupplierRecord({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.notes,
  });
  final int id;
  final String name;
  final String email;
  final String phone;
  final String notes;

  factory SupplierRecord.fromMap(Map<String, Object?> m) => SupplierRecord(
        id: (m['SupplierID'] as num).toInt(),
        name: (m['SupplierName'] ?? '').toString(),
        email: (m['ContactEmail'] ?? '').toString(),
        phone: (m['Phone'] ?? '').toString(),
        notes: (m['Notes'] ?? '').toString(),
      );
}

class AuditFilter {
  const AuditFilter({
    this.itemName,
    this.changeType,
    required this.dateFrom,
    required this.dateTo,
  });
  final String? itemName;
  final String? changeType;
  final DateTime dateFrom;
  final DateTime dateTo;
}

class ItemHistorySnapshot {
  const ItemHistorySnapshot({
    required this.currentQuantity,
    required this.totalAdded,
    required this.totalRemoved,
    required this.entries,
    required this.totalEntries,
  });
  final int currentQuantity;
  final int totalAdded;
  final int totalRemoved;
  final List<LedgerEntry> entries;
  final int totalEntries;
}


class SaleDraftLine {
  const SaleDraftLine({required this.itemId, required this.quantity});
  final int itemId;
  final int quantity;
}

class SaleCartLine {
  const SaleCartLine({required this.item, required this.quantity});
  final InventoryItem item;
  final int quantity;

  double get subtotal => item.unitPrice * quantity;

  SaleCartLine copyWith({InventoryItem? item, int? quantity}) => SaleCartLine(
        item: item ?? this.item,
        quantity: quantity ?? this.quantity,
      );
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.saleNumber,
    required this.timestamp,
    required this.totalAmount,
    required this.totalItems,
    required this.status,
    required this.notes,
    this.voidedAt = '',
  });

  final int id;
  final String saleNumber;
  final String timestamp;
  final double totalAmount;
  final int totalItems;
  final String status;
  final String notes;
  final String voidedAt;

  bool get isVoided => status.toUpperCase() == 'VOIDED';

  factory SaleRecord.fromMap(Map<String, Object?> m) => SaleRecord(
        id: ((m['SaleID'] ?? 0) as num).toInt(),
        saleNumber: (m['SaleNumber'] ?? '').toString(),
        timestamp: (m['Timestamp'] ?? '').toString(),
        totalAmount: ((m['TotalAmount'] ?? 0) as num).toDouble(),
        totalItems: ((m['TotalItems'] ?? 0) as num).toInt(),
        status: (m['Status'] ?? 'COMPLETED').toString(),
        notes: (m['Notes'] ?? '').toString(),
        voidedAt: (m['VoidedAt'] ?? '').toString(),
      );
}

class SaleLineRecord {
  const SaleLineRecord({
    required this.id,
    required this.saleId,
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final int id;
  final int saleId;
  final int? itemId;
  final String itemName;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  factory SaleLineRecord.fromMap(Map<String, Object?> m) => SaleLineRecord(
        id: ((m['SaleItemID'] ?? 0) as num).toInt(),
        saleId: ((m['SaleID'] ?? 0) as num).toInt(),
        itemId: m['ItemID'] == null ? null : (m['ItemID'] as num).toInt(),
        itemName: (m['ItemNameSnapshot'] ?? '').toString(),
        sku: (m['SKUSnapshot'] ?? '').toString(),
        quantity: ((m['Quantity'] ?? 0) as num).toInt(),
        unitPrice: ((m['UnitPrice'] ?? 0) as num).toDouble(),
        subtotal: ((m['Subtotal'] ?? 0) as num).toDouble(),
      );
}

class SaleDetail {
  const SaleDetail({required this.sale, required this.lines});
  final SaleRecord sale;
  final List<SaleLineRecord> lines;
}
