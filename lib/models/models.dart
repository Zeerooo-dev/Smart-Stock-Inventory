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
  });

  final int ledgerId;
  final String timestamp;
  final String itemName;
  final String sku;
  final String changeType;
  final int deltaQuantity;
  final double priceSnapshot;
  final int runningBalance;

  factory LedgerEntry.fromMap(Map<String, Object?> m) => LedgerEntry(
        ledgerId: ((m['LedgerID'] ?? 0) as num).toInt(),
        timestamp: (m['Timestamp'] ?? '').toString(),
        itemName: (m['ItemName'] ?? '[Deleted Item]').toString(),
        sku: (m['SKU'] ?? '—').toString(),
        changeType: (m['ChangeType'] ?? '').toString(),
        deltaQuantity: ((m['DeltaQuantity'] ?? 0) as num).toInt(),
        priceSnapshot: ((m['PriceSnapshot'] ?? 0) as num).toDouble(),
        runningBalance: ((m['RunningBalance'] ?? 0) as num).toInt(),
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
