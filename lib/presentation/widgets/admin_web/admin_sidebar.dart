import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../providers/flag_provider.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final flagProvider = context.watch<FlagProvider>();
    final pendingCount = flagProvider.pendingCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: expanded ? 240 : 64,
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
      ),
      child: Column(
        children: [
          // Header with logo
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shield,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SafeTrace',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: AppTheme.darkCardBorder, height: 1),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  expanded: expanded,
                  onTap: () => onItemSelected(0),
                ),
                _NavItem(
                  icon: Icons.people_outline,
                  label: 'Users',
                  isSelected: selectedIndex == 1,
                  expanded: expanded,
                  onTap: () => onItemSelected(1),
                ),
                _NavItem(
                  icon: Icons.warning_amber_outlined,
                  label: 'Incidents',
                  isSelected: selectedIndex == 2,
                  expanded: expanded,
                  onTap: () => onItemSelected(2),
                ),
                _NavItem(
                  icon: Icons.category_outlined,
                  label: 'Categories',
                  isSelected: selectedIndex == 3,
                  expanded: expanded,
                  onTap: () => onItemSelected(3),
                ),
                _NavItem(
                  icon: Icons.groups_outlined,
                  label: 'Communities',
                  isSelected: selectedIndex == 4,
                  expanded: expanded,
                  onTap: () => onItemSelected(4),
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  label: 'Flags',
                  isSelected: selectedIndex == 5,
                  expanded: expanded,
                  badgeCount: pendingCount,
                  onTap: () => onItemSelected(5),
                ),
                _NavItem(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  isSelected: selectedIndex == 6,
                  expanded: expanded,
                  onTap: () => onItemSelected(6),
                ),
              ],
            ),
          ),

          // Collapse toggle
          const Divider(color: AppTheme.darkCardBorder, height: 1),
          InkWell(
            onTap: onToggleExpanded,
            child: Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 12),
              child: Row(
                mainAxisAlignment: expanded ? MainAxisAlignment.end : MainAxisAlignment.center,
                children: [
                  Icon(
                    expanded ? Icons.chevron_left : Icons.chevron_right,
                    color: AppTheme.darkTextSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool expanded;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.expanded,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryRed.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? AppTheme.primaryRed : AppTheme.darkTextSecondary,
                      size: 22,
                    ),
                    if (badgeCount != null && badgeCount! > 0 && !expanded)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryRed,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount! > 99 ? '99+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                        color: isSelected ? Colors.white : AppTheme.darkTextSecondary,
                      ),
                    ),
                  ),
                  if (badgeCount != null && badgeCount! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount! > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
