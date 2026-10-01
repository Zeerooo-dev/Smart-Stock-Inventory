import 'dart:async';

import '../models/models.dart';

/// One best-effort notification boundary. UI delivery must never undo a write.
class NotificationService {
  void Function(String title, String message)? onNotification;

  void show(String title, String message) {
    try {
      onNotification?.call(title, message);
    } catch (_) {
      // Notifications are optional; database/export success is independent.
    }
  }
}

/// Watches all inventory, independent of dashboard search and pagination.
class LowStockMonitor {
  LowStockMonitor(this.loadItems, this.notifications);
  final Future<List<InventoryItem>> Function() loadItems;
  final NotificationService notifications;
  final Set<int> _lowIds = {};
  Timer? _timer;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  Future<void> start({Duration interval = const Duration(minutes: 1)}) async {
    _timer?.cancel();
    await check(notify: false);
    if (_disposed) return;
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  Future<void> check({bool notify = true}) {
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        final items = await loadItems();
        if (_disposed) return;
        final low = items.where((i) => i.isLowStock).toList();
        final newlyLow = low.where((i) => !_lowIds.contains(i.id)).toList();
        _lowIds
          ..clear()
          ..addAll(low.map((i) => i.id));
        if (!notify || newlyLow.isEmpty) return;
        final message = newlyLow.length == 1
            ? '${newlyLow.single.name} is low on stock. Only ${newlyLow.single.quantity} units remaining.'
            : '${newlyLow.length} items are low on stock: '
                  '${newlyLow.take(3).map((i) => '${i.name} (${i.quantity} left)').join(', ')}'
                  '${newlyLow.length > 3 ? ', and ${newlyLow.length - 3} more' : ''}.';
        notifications.show('Low Stock Alert', message);
      } catch (_) {
        // A transient read failure leaves the last successful baseline intact.
      }
    });
    return _pending;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
