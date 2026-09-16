import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class MyBottomNavBar extends StatefulWidget {
  final int selectedPosition;
  final Function(int) onItemTapped;

  const MyBottomNavBar({super.key, required this.selectedPosition, required this.onItemTapped});

  @override
  State<MyBottomNavBar> createState() => _MyBottomNavBarState();
}

class _MyBottomNavBarState extends State<MyBottomNavBar> {
  final List<NavBarItem> _navItems = [
    NavBarItem(icon: CupertinoIcons.house_fill, activeIcon: CupertinoIcons.house_fill, label: 'Home'),
    NavBarItem(icon: CupertinoIcons.compass, activeIcon: CupertinoIcons.compass, label: 'Explore'),
    NavBarItem(icon: Icons.add_rounded, activeIcon: Icons.add_rounded, label: 'Live', isCenter: true),
    NavBarItem(icon: CupertinoIcons.chat_bubble_fill, activeIcon: CupertinoIcons.chat_bubble_fill, label: 'Chats'),
    NavBarItem(icon: CupertinoIcons.person_solid, activeIcon: CupertinoIcons.person_solid, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFE2C55), // Solid primary color, completely flat
      child: SafeArea(
        top: false,
        bottom: true,
        maintainBottomViewPadding: true,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_navItems.length, (index) {
              return _buildNavItem(index, _navItems[index]);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, NavBarItem item) {
    final isSelected = widget.selectedPosition == index;
    final isCenter = item.isCenter;

    if (isCenter) {
      return GestureDetector(
        onTap: () => widget.onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 54,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              color: Color(0xFFFE2C55),
              size: 34,
            ),
          ),
        ),
      );
    }

    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withValues(alpha: 0.6);

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(top: isSelected ? 0 : 6),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: isSelected ? 28 : 26,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 6 : 0,
              height: isSelected ? 6 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.8),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem {
  final IconData? icon;
  final IconData? activeIcon;
  final String label;
  final bool isCenter;

  NavBarItem({
    this.icon,
    this.activeIcon,
    required this.label,
    this.isCenter = false,
  });
}
