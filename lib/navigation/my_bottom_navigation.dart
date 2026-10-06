import 'package:flutter/material.dart';

class MyBottomNavBar extends StatefulWidget {
  final int selectedPosition;
  final Function(int) onItemTapped;

  const MyBottomNavBar({
    super.key,
    required this.selectedPosition,
    required this.onItemTapped,
  });

  @override
  State<MyBottomNavBar> createState() => _MyBottomNavBarState();
}

class _MyBottomNavBarState extends State<MyBottomNavBar> {
  final List<NavBarItem> _navItems = [
    NavBarItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    NavBarItem(
      icon: Icons.mic_none_rounded,
      activeIcon: Icons.mic_rounded,
      label: 'Audio',
    ),
    NavBarItem(
      icon: Icons.videocam_rounded,
      activeIcon: Icons.videocam_rounded,
      label: '',
      isCenter: true,
    ),
    NavBarItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Chats',
    ),
    NavBarItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: true,
        maintainBottomViewPadding: true,
        child: SizedBox(
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Bottom Bar Background
              Container(
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFF090614),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border.all(
                    color: const Color(0xFF23163E),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(_navItems.length, (index) {
                    if (_navItems[index].isCenter) {
                      return const Expanded(child: SizedBox()); // space for floating center button
                    }
                    return Expanded(
                      child: _buildNavItem(index, _navItems[index]),
                    );
                  }),
                ),
              ),

              // Center Floating Action Video Button
              Positioned(
                top: -14,
                child: GestureDetector(
                  onTap: () => widget.onItemTapped(2),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF2A8D),
                          Color(0xFF9D4EDD),
                          Color(0xFF7209B7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2A8D).withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3.5),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF140727),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, NavBarItem item) {
    final isSelected = widget.selectedPosition == index;
    const activeColor = Color(0xFFFF2A8D);
    const inactiveColor = Color(0xFF8E87A2);

    return InkWell(
      onTap: () => widget.onItemTapped(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? item.activeIcon : item.icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 24,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.8),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class NavBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCenter;

  NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCenter = false,
  });
}
