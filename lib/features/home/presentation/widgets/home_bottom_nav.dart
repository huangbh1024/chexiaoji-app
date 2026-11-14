import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../app/theme/app_typography.dart';

class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onFab,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFab;

  static const _items = <({String label, IconData icon, IconData activeIcon})>[
    (label: '首页', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    (
      label: '账单',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    (
      label: '统计',
      icon: Icons.pie_chart_outline_rounded,
      activeIcon: Icons.pie_chart_rounded,
    ),
    (
      label: '我的',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tokens = context.tokens;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final navHeight = tokens.navHeight;
    final radius = BorderRadius.vertical(
      top: Radius.circular(tokens.radiusCard),
    );

    return SizedBox(
      height: 84 + bottomInset,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: navHeight + bottomInset,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: tokens.navShadow,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: palette.navBar.withValues(alpha: 0.92),
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 8,
                      top: 6,
                      bottom: bottomInset + 4,
                    ),
                    child: Row(
                      children: [
                        for (var index = 0; index < _items.length; index++)
                          Expanded(
                            child: _NavItem(
                              item: _items[index],
                              active: index == selectedIndex,
                              onTap: () => onTap(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 0, child: _Fab(onTap: onFab)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final ({String label, IconData icon, IconData activeIcon}) item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.primary : palette.outline;
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(active ? item.activeIcon : item.icon, size: 24, color: color),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 16,
            height: 3,
            decoration: BoxDecoration(
              color: active ? palette.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [palette.primary, const Color(0xFF3FDFA5)],
          ),
          border: Border.all(color: palette.background, width: 4),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
      ),
    );
  }
}
