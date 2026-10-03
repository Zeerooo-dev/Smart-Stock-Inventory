import 'package:flutter/material.dart';

import '../../services/notification_service.dart';
import '../../state/smartstock_controller.dart';
import 'reports_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.controller});

  final SmartStockController controller;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  NotificationService get _notifications => widget.controller.notifications;

  @override
  void initState() {
    super.initState();
    _notifications.addListener(_changed);
  }

  @override
  void dispose() {
    _notifications.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _notifications.history;
    final unread = _notifications.unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _notifications.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        child: entries.isEmpty
            ? const _EmptyNotifications()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _FeedSummary(unread: unread, total: entries.length),
                  const SizedBox(height: 14),
                  for (final entry in entries) ...[
                    _NotificationCard(
                      entry: entry,
                      onTap: () => _notifications.markRead(entry.id),
                      onReviewStock: _isStockAlert(entry)
                          ? () {
                              _notifications.markRead(entry.id);
                              showLowStockItems(context, widget.controller);
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Notification history is kept for this SmartStock session.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FeedSummary extends StatelessWidget {
  const _FeedSummary({required this.unread, required this.total});

  final int unread;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? 'You are all caught up' : '$unread unread',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '$total notification${total == 1 ? '' : 's'} this session',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.entry,
    required this.onTap,
    this.onReviewStock,
  });

  final SmartStockNotification entry;
  final VoidCallback onTap;
  final VoidCallback? onReviewStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _visuals(entry, theme);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            style.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: style.color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          _relativeTime(entry.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!entry.isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (onReviewStock != null) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: onReviewStock,
                          icon: const Icon(Icons.inventory_2_outlined, size: 17),
                          label: const Text('Review stock'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 72),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 34,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'No notifications yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Low-stock alerts and successful SmartStock actions will appear here while the app is open.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

bool _isStockAlert(SmartStockNotification entry) {
  final title = entry.title.toLowerCase();
  return title.contains('low stock') || title.contains('out of stock');
}

_NotificationVisuals _visuals(
  SmartStockNotification entry,
  ThemeData theme,
) {
  final title = entry.title.toLowerCase();
  if (title.contains('low stock')) {
    return _NotificationVisuals(
      label: 'Stock alert',
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFB86B00),
    );
  }
  if (title.contains('out of stock')) {
    return _NotificationVisuals(
      label: 'Critical',
      icon: Icons.error_outline_rounded,
      color: theme.colorScheme.error,
    );
  }
  if (title.contains('export')) {
    return _NotificationVisuals(
      label: 'Export',
      icon: Icons.file_download_done_outlined,
      color: const Color(0xFF2563EB),
    );
  }
  if (title.contains('added')) {
    return const _NotificationVisuals(
      label: 'Inventory',
      icon: Icons.add_box_outlined,
      color: Color(0xFF047857),
    );
  }
  return _NotificationVisuals(
    label: 'SmartStock',
    icon: Icons.check_circle_outline_rounded,
    color: theme.colorScheme.primary,
  );
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays == 1) return 'Yesterday';
  return '${difference.inDays}d ago';
}

class _NotificationVisuals {
  const _NotificationVisuals({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
