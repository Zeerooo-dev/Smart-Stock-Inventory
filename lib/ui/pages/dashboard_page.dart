import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/smartstock_controller.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.controller,
    required this.onInventory,
    required this.onReports,
    required this.onAudit,
    required this.onScan,
    required this.onRestock,
    required this.onDispense,
    required this.onAddItem,
    required this.onOpenLowStock,
  });

  final SmartStockController controller;
  final VoidCallback onInventory;
  final VoidCallback onReports;
  final VoidCallback onAudit;
  final VoidCallback onScan;
  final VoidCallback onRestock;
  final VoidCallback onDispense;
  final VoidCallback onAddItem;
  final ValueChanged<String> onOpenLowStock;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final decimal = NumberFormat.decimalPattern();
    final lowStock = controller.lowStockThreats
        .where((item) => item.quantity < item.reorderLevel)
        .toList();
    final recent = controller.auditPage.entries.take(4).toList();
    final movement = _movement(controller.auditPage.entries);

    Widget attentionSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Needs Attention',
          badge: '${controller.kpis.lowStockCount} items',
          onTap: onInventory,
          actionLabel: 'View all',
        ),
        const SizedBox(height: 10),
        if (lowStock.isEmpty)
          const _CalmStateCard(
            icon: Icons.check_circle_outline,
            title: 'Stock levels look healthy',
            message: 'No tracked item is currently below its reorder threshold.',
          )
        else
          ...lowStock.take(3).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AttentionCard(
                threat: item,
                onTap: () => onOpenLowStock(item.name),
              ),
            ),
          ),
      ],
    );

    Widget movementSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Stock Movement',
          onTap: onReports,
          actionLabel: 'Reports',
        ),
        const SizedBox(height: 10),
        _MovementCard(
          restocked: movement.restocked,
          dispensed: movement.dispensed,
        ),
      ],
    );

    Widget mixSection() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Inventory Mix',
          onTap: onReports,
          actionLabel: 'Details',
        ),
        const SizedBox(height: 10),
        _CategoryMixCard(categories: controller.categorySummaries),
      ],
    );

    Widget activitySection() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Recent Activity',
          onTap: onAudit,
          actionLabel: 'Audit Log',
        ),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          const _CalmStateCard(
            icon: Icons.history,
            title: 'No recent activity',
            message: 'Inventory changes will appear here after they are recorded.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (var index = 0; index < recent.length; index++) ...[
                    _ActivityRow(entry: recent[index]),
                    if (index != recent.length - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final tablet = constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.6;
        final horizontal = tablet ? 24.0 : 16.0;
        return ListView(
          key: const PageStorageKey('dashboard-scroll'),
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _JumpPills(
                      onNeedsAttention: onInventory,
                      onMovement: onReports,
                      onAudit: onAudit,
                    ),
                    const SizedBox(height: 14),
                    _OverviewCard(
                      totalValue: money.format(controller.kpis.totalValue),
                      totalUnits: decimal.format(controller.kpis.totalQuantity),
                      lowStockCount: controller.kpis.lowStockCount,
                      categoryCount: controller.categorySummaries.length,
                    ),
                    const SizedBox(height: 14),
                    _QuickActions(
                      onRestock: onRestock,
                      onDispense: onDispense,
                      onScan: onScan,
                      onAddItem: onAddItem,
                    ),
                    const SizedBox(height: 22),
                    if (tablet)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 11,
                            child: Column(
                              children: [
                                attentionSection(),
                                const SizedBox(height: 22),
                                activitySection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            flex: 9,
                            child: Column(
                              children: [
                                movementSection(),
                                const SizedBox(height: 22),
                                mixSection(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      attentionSection(),
                      const SizedBox(height: 12),
                      movementSection(),
                      const SizedBox(height: 22),
                      mixSection(),
                      const SizedBox(height: 22),
                      activitySection(),
                    ],
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

class _JumpPills extends StatelessWidget {
  const _JumpPills({
    required this.onNeedsAttention,
    required this.onMovement,
    required this.onAudit,
  });

  final VoidCallback onNeedsAttention;
  final VoidCallback onMovement;
  final VoidCallback onAudit;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        const _Pill(label: 'Overview', selected: true),
        const SizedBox(width: 8),
        _Pill(label: 'Needs Attention', onTap: onNeedsAttention),
        const SizedBox(width: 8),
        _Pill(label: 'Movement', onTap: onMovement),
        const SizedBox(width: 8),
        _Pill(label: 'Audit Log', onTap: onAudit),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.selected = false, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalValue,
    required this.totalUnits,
    required this.lowStockCount,
    required this.categoryCount,
  });

  final String totalValue;
  final String totalUnits;
  final int lowStockCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TOTAL INVENTORY VALUE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              totalValue,
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _OverviewMetric(
                    label: 'Total units',
                    value: totalUnits,
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OverviewMetric(
                    label: 'Needs attention',
                    value: '$lowStockCount',
                    icon: Icons.warning_amber_rounded,
                    warning: lowStockCount > 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _OverviewMetric(
                    label: 'Categories',
                    value: '$categoryCount',
                    icon: Icons.category_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = warning ? const Color(0xFF92400E) : scheme.onSurface;
    final background = warning
        ? const Color(0xFFFFFBEB)
        : scheme.surfaceContainerLow;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: warning
                  ? const Color(0xFF92400E)
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onRestock,
    required this.onDispense,
    required this.onScan,
    required this.onAddItem,
  });

  final VoidCallback onRestock;
  final VoidCallback onDispense;
  final VoidCallback onScan;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _QuickAction(
          icon: Icons.add,
          label: 'Restock',
          onTap: onRestock,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _QuickAction(
          icon: Icons.remove,
          label: 'Dispense',
          onTap: onDispense,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _QuickAction(
          icon: Icons.qr_code_scanner,
          label: 'Scan',
          onTap: onScan,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _QuickAction(
          icon: Icons.add_box_outlined,
          label: 'Add Item',
          onTap: onAddItem,
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Icon(icon, size: 20),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onTap,
    required this.actionLabel,
    this.badge,
  });

  final String title;
  final String? badge;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
      TextButton(
        onPressed: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(actionLabel),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_forward, size: 16),
          ],
        ),
      ),
    ],
  );
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.threat, required this.onTap});

  final LowStockThreat threat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final out = threat.quantity <= 0;
    final accent = out ? const Color(0xFFB42318) : const Color(0xFF92400E);
    final background = out ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  out ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      threat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${threat.quantity} remaining · minimum ${threat.reorderLevel}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  out ? 'OUT' : 'LOW',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({required this.restocked, required this.dispensed});

  final int restocked;
  final int dispensed;

  @override
  Widget build(BuildContext context) {
    final maxValue = restocked > dispensed ? restocked : dispensed;
    final denominator = maxValue <= 0 ? 1 : maxValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent recorded movement',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _MovementLine(
              label: 'Restocked',
              value: restocked,
              fraction: restocked / denominator,
              positive: true,
            ),
            const SizedBox(height: 14),
            _MovementLine(
              label: 'Dispensed',
              value: dispensed,
              fraction: dispensed / denominator,
              positive: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementLine extends StatelessWidget {
  const _MovementLine({
    required this.label,
    required this.value,
    required this.fraction,
    required this.positive,
  });

  final String label;
  final int value;
  final double fraction;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive
        ? const Color(0xFF047857)
        : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${positive ? '+' : '-'}$value',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: fraction.clamp(0, 1),
            color: color,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
      ],
    );
  }
}

class _CategoryMixCard extends StatelessWidget {
  const _CategoryMixCard({required this.categories});

  final List<CategorySummary> categories;

  @override
  Widget build(BuildContext context) {
    final ranked = [...categories]..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(3).toList();
    final total = ranked.fold<double>(0, (sum, item) => sum + item.value);
    if (top.isEmpty) {
      return const _CalmStateCard(
        icon: Icons.donut_large_outlined,
        title: 'No inventory mix yet',
        message: 'Category value summaries appear after inventory is added.',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            for (var index = 0; index < top.length; index++) ...[
              _CategoryLine(
                category: top[index],
                fraction: total <= 0 ? 0 : top[index].value / total,
              ),
              if (index != top.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({required this.category, required this.fraction});

  final CategorySummary category;
  final double fraction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              category.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${category.quantity} units',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 7,
          value: fraction.clamp(0, 1),
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
    ],
  );
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.deltaQuantity > 0;
    final neutral = entry.deltaQuantity == 0;
    final color = neutral
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : positive
        ? const Color(0xFF047857)
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              positive
                  ? Icons.add
                  : neutral
                  ? Icons.edit_outlined
                  : Icons.remove,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activityLabel(entry),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.deltaQuantity != 0)
            Text(
              entry.changeText,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalmStateCard extends StatelessWidget {
  const _CalmStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

({int restocked, int dispensed}) _movement(List<LedgerEntry> entries) {
  var restocked = 0;
  var dispensed = 0;
  for (final entry in entries) {
    if (entry.changeType == 'RESTOCK' && entry.deltaQuantity > 0) {
      restocked += entry.deltaQuantity;
    }
    if (entry.changeType == 'DISPENSE' && entry.deltaQuantity < 0) {
      dispensed += entry.deltaQuantity.abs();
    }
  }
  return (restocked: restocked, dispensed: dispensed);
}

String _activityLabel(LedgerEntry entry) => switch (entry.changeType) {
  'RESTOCK' => 'Restocked',
  'DISPENSE' => 'Dispensed',
  'CREATE' => 'Item added',
  'MANUAL_EDIT' => 'Item updated',
  'DELETE' => 'Item deleted',
  'CSV_IMPORT' => 'Imported',
  _ => entry.changeType.replaceAll('_', ' ').toLowerCase(),
};
