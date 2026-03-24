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
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: expanded ? 240 : 64,
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo header
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 0),
              child: expanded
                  ? Row(
                      children: [
                        _LogoMark(),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SafeTrace',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'ADMIN CONSOLE',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w400,
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.38),
                                letterSpacing: 2.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Center(child: _LogoMark()),
            ),
          ),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                if (expanded) const _SectionLabel('OVERVIEW'),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  expanded: expanded,
                  onTap: () => onItemSelected(0),
                ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  const _SectionLabel('MANAGE'),
                ],
                _NavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people_rounded,
                  label: 'Users',
                  isSelected: selectedIndex == 1,
                  expanded: expanded,
                  onTap: () => onItemSelected(1),
                ),
                _NavItem(
                  icon: Icons.warning_amber_outlined,
                  activeIcon: Icons.warning_amber_rounded,
                  label: 'Incidents',
                  isSelected: selectedIndex == 2,
                  expanded: expanded,
                  onTap: () => onItemSelected(2),
                ),
                _NavItem(
                  icon: Icons.category_outlined,
                  activeIcon: Icons.category_rounded,
                  label: 'Categories',
                  isSelected: selectedIndex == 3,
                  expanded: expanded,
                  onTap: () => onItemSelected(3),
                ),
                _NavItem(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups_rounded,
                  label: 'Communities',
                  isSelected: selectedIndex == 4,
                  expanded: expanded,
                  onTap: () => onItemSelected(4),
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag_rounded,
                  label: 'Flags',
                  isSelected: selectedIndex == 5,
                  expanded: expanded,
                  badgeCount: pendingCount,
                  onTap: () => onItemSelected(5),
                ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  const _SectionLabel('INSIGHTS'),
                ],
                _NavItem(
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Analytics',
                  isSelected: selectedIndex == 6,
                  expanded: expanded,
                  onTap: () => onItemSelected(6),
                ),
                if (expanded) ...[
                  const SizedBox(height: 10),
                  const _SectionLabel('SYSTEM'),
                ],
                _NavItem(
                  icon: Icons.tune_outlined,
                  activeIcon: Icons.tune_rounded,
                  label: 'System Config',
                  isSelected: selectedIndex == 7,
                  expanded: expanded,
                  onTap: () => onItemSelected(7),
                ),
              ],
            ),
          ),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // Collapse toggle
          InkWell(
            onTap: onToggleExpanded,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      expanded
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.shield, color: Colors.white, size: 17),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4, top: 2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: Colors.white.withValues(alpha: 0.26),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool expanded;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.expanded,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? AppTheme.primaryRed : Colors.transparent,
              width: 3,
            ),
          ),
          color: isSelected
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.transparent,
        ),
        // left padding compensates for 3px border so icon stays aligned
        padding: EdgeInsets.only(
          left: expanded ? 17 : 0,
          right: expanded ? 12 : 0,
        ),
        alignment: expanded ? Alignment.centerLeft : Alignment.center,
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 19,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.42),
                ),
                if (badgeCount != null && badgeCount! > 0 && !expanded)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount! > 9 ? '9+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
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
                    fontSize: 13,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeCount! > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
