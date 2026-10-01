import 'package:flutter_test/flutter_test.dart';
import 'package:smartstock_flutter/models/models.dart';
import 'package:smartstock_flutter/services/notification_service.dart';

InventoryItem item(int id, int quantity) => InventoryItem(
  id: id,
  sku: 'SKU-$id',
  name: 'Mouse $id',
  category: 'Electronics',
  quantity: quantity,
  unitPrice: 500,
  reorderLevel: 5,
);

void main() {
  test(
    'low-stock transitions deduplicate, rearm, batch, and tolerate failed reads',
    () async {
      var items = [item(1, 6)];
      var fail = false;
      final messages = <String>[];
      final notifications = NotificationService()
        ..onNotification = (_, message) => messages.add(message);
      final monitor = LowStockMonitor(() async {
        if (fail) throw StateError('Read failed');
        return items;
      }, notifications);
      addTearDown(monitor.dispose);
      await monitor.check(notify: false);
      items = [item(1, 3)];
      await monitor.check();
      await monitor.check();
      expect(messages, hasLength(1));
      expect(messages.single, contains('Only 3 units'));
      items = [item(1, 2)];
      await monitor.check();
      expect(messages, hasLength(1));
      fail = true;
      await monitor.check();
      fail = false;
      await monitor.check();
      expect(messages, hasLength(1));
      items = [item(1, 5)];
      await monitor.check(); // Existing rule is quantity < threshold.
      items = [item(1, 3), item(2, 2), item(3, 1)];
      await monitor.check();
      expect(messages, hasLength(2));
      expect(messages.last, contains('3 items'));
      monitor.dispose();
      items = [item(4, 0)];
      await monitor.check();
      expect(messages, hasLength(2));
    },
  );

  testWidgets('timer checks while app runs and stops after disposal', (
    tester,
  ) async {
    var items = [item(1, 6)];
    final messages = <String>[];
    final notifications = NotificationService()
      ..onNotification = (_, message) => messages.add(message);
    final monitor = LowStockMonitor(() async => items, notifications);
    await monitor.start(interval: const Duration(seconds: 1));
    items = [item(1, 3)];
    await tester.pump(const Duration(seconds: 1));
    expect(messages, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(messages, hasLength(1));
    monitor.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(messages, hasLength(1));
  });
}
