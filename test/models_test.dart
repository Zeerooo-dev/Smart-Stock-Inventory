import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/models/models.dart';

void main() {
  test('InventoryItem derives value and low-stock state', () {
    final item = InventoryItem.fromMap({
      'ItemID': 7,
      'SKU': 'SS-TEST-0007',
      'ItemName': 'USB Cable',
      'Quantity': 3,
      'UnitPrice': 125.50,
      'CategoryName': 'Electronics',
      'ReorderLevel': 5,
    });

    expect(item.value, 376.50);
    expect(item.isLowStock, isTrue);
  });

  test('SupplierRecord accepts nullable database text fields', () {
    final supplier = SupplierRecord.fromMap({
      'SupplierID': 1,
      'SupplierName': 'Example Supply Co.',
      'ContactEmail': null,
      'Phone': null,
      'Notes': null,
    });

    expect(supplier.name, 'Example Supply Co.');
    expect(supplier.email, '');
    expect(supplier.phone, '');
    expect(supplier.notes, '');
  });
}
