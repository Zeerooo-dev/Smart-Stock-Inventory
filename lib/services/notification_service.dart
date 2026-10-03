import 'dart:async';

import '../models/models.dart';

class SmartStockNotification {
  SmartStockNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;
}

/// One best-effort notification boundary. UI delivery must never undo a write.
///
/// The in-memory history is intentionally session-scoped: it mirrors the
/// existing notification behavior without adding a new persistence contract.
class NotificationService {
  void Function(String title, String message)? onNotification;

  final List<SmartStockNotification> _history = [];
  final Set<void Function()> _listeners = {};
  int _nextId = 1;

  List<SmartStockNotification> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((entry) => !entry.isRead).length;

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void show(String title, String message) {
    _history.insert(
      0,
      SmartStockNotification(
        id: _nextId++,
        title: title,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
    if (_history.length > 100) {
      _history.removeRange(100, _history.length);
    }
    _notifyListeners();

    try {
      onNotification?.call(title, message);
    } catch (_) {
      // Notifications are optional; database/export success is independent.
    }
  }

  void markRead(int id) {
    final entry = _history.where((item) => item.id == id).firstOrNull;
    if (entry == null || entry.isRead) return;
    entry.isRead = true;
    _notifyListeners();
  }

  void markAllRead() {
    var changed = false;
    for (final entry in _history) {
      if (entry.isRead) continue;
      entry.isRead = true;
      changed = true;
    }
    if (changed) _notifyListeners();
  }

  void clear() {
    if (_history.isEmpty) return;
    _history.clear();
    _notifyListeners();
  }

  void _notifyListeners() {
    for (final listener in List<void Function()>.of(_listeners)) {
      try {
        listener();
      } catch (_) {
        // A notification-center listener must not affect inventory writes.
      }
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
