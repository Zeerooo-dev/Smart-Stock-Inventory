import 'package:flutter/material.dart';

import '../../state/smartstock_controller.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.controller,
    required this.onNotifications,
    required this.onSuppliers,
    required this.onSettings,
    required this.onImport,
    required this.onExport,
    required this.onScanner,
    required this.onHelp,
    required this.onAbout,
  });

  final SmartStockController controller;
  final VoidCallback onNotifications;
  final VoidCallback onSuppliers;
  final VoidCallback onSettings;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onScanner;
  final VoidCallback onHelp;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final inventory = _Section(
      label: 'INVENTORY MANAGEMENT',
      children: [
        _MoreRow(
          icon: Icons.category_outlined,
          title: 'Categories & appearance',
          subtitle: 'Manage categories and visual preferences',
          onTap: onSettings,
        ),
        _MoreRow(
          icon: Icons.local_shipping_outlined,
          title: 'Suppliers',
          subtitle: 'Manage existing supplier records',
          onTap: onSuppliers,
        ),
        _MoreRow(
          icon: Icons.file_upload_outlined,
          title: 'Import Inventory',
          subtitle: 'Import supported CSV or XLSX inventory files',
          onTap: onImport,
        ),
        _MoreRow(
          icon: Icons.file_download_outlined,
          title: 'Export Inventory',
          subtitle: 'Export inventory, reports, or audit data',
          onTap: onExport,
        ),
      ],
    );
    final preferences = _Section(
      label: 'PREFERENCES & SYSTEM',
      children: [
        _MoreRow(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications',
          subtitle: controller.notifications.unreadCount == 0
              ? 'Stock alerts and completed actions'
              : '${controller.notifications.unreadCount} unread notification(s)',
          badge: controller.notifications.unreadCount,
          onTap: onNotifications,
        ),
        _MoreRow(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Backup, data controls, theme and categories',
          onTap: onSettings,
        ),
        _MoreRow(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Barcode Scanner',
          subtitle: 'Scan or manually look up an inventory code',
          onTap: onScanner,
        ),
      ],
    );
    final appInfo = _Section(
      label: 'APPLICATION INFO',
      children: [
        _MoreRow(
          icon: Icons.help_outline_rounded,
          title: 'Help & Inventory Guide',
          subtitle: 'Quick guidance for common inventory workflows',
          onTap: onHelp,
        ),
        _MoreRow(
          icon: Icons.info_outline_rounded,
          title: 'About SmartStock',
          subtitle: 'Precision stock management system',
          trailingLabel: 'v2.1.0',
          onTap: onAbout,
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.6;
        final horizontal = wide ? 24.0 : 16.0;
        return ListView(
          key: const PageStorageKey('more-scroll'),
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: inventory),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              children: [
                                preferences,
                                const SizedBox(height: 18),
                                appInfo,
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          inventory,
                          const SizedBox(height: 18),
                          preferences,
                          const SizedBox(height: 18),
                          appInfo,
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 66,
                    color: theme.colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (trailingLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  trailingLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
