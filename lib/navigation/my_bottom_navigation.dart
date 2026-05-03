import 'package:flutter/material.dart';
import 'dart:ui';
import '../core/localization/app_localizations.dart';
import '../theme/app_theme.dart';

class MyBottomNavBar extends StatefulWidget {
  final int selectedPosition;
  final Function(int) onItemTapped;

  const MyBottomNavBar({super.key, required this.selectedPosition, required this.onItemTapped});

  @override
  State<MyBottomNavBar> createState() => _MyBottomNavBarState();
}

class _MyBottomNavBarState extends State<MyBottomNavBar> with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;

  final List<NavBarItem> _navItems = [
    NavBarItem(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home'),
    NavBarItem(icon: Icons.play_circle_outline, activeIcon: Icons.play_circle_filled, label: 'Social'),
    NavBarItem(icon: Icons.videocam, activeIcon: Icons.videocam, label: 'Create', isCenter: true),
    NavBarItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Inbox'),
    NavBarItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Me'),
  ];

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      _navItems.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300), // Slightly longer duration
        vsync: this,
      ),
    );

    _scaleAnimations = _animationControllers
        .map(
          (controller) =>
              Tween<double>(
                begin: 1.0,
                end: 1.5, // Increased from 1.1 to 1.25 for more noticeable zoom
              ).animate(
                CurvedAnimation(
                  parent: controller,
                  curve: Curves.easeOutBack, // Changed to easeOutBack for bouncy effect
                ),
              ),
        )
        .toList();

    if (widget.selectedPosition < _animationControllers.length) {
      _animationControllers[widget.selectedPosition].forward();
    }
  }

  @override
  void didUpdateWidget(MyBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPosition != widget.selectedPosition) {
      for (var controller in _animationControllers) {
        controller.reset();
      }
      if (widget.selectedPosition < _animationControllers.length) {
        _animationControllers[widget.selectedPosition].forward();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Bottom Navigation Bar
        Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.barColor,
            border: Border(top: BorderSide(color: AppColors.pink.withValues(alpha: 0.2), width: 1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -5)),
              BoxShadow(color: AppColors.pink.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 0)),
            ],
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_navItems.length, (index) {
                    return _buildNavItem(index, _navItems[index]);
                  }),
                ),
              ),
            ),
          ),
        ),

        // Elevated Center Button
        Positioned(bottom: 20, child: _buildCenterButton()),
      ],
    );
  }

  Widget _buildCenterButton() {
    final isSelected = widget.selectedPosition == 2;
    final gradientColors = [AppColors.pink400, AppColors.pink, AppColors.pink600];

    return GestureDetector(
      onTap: () {
        widget.onItemTapped(2);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimations[2],
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimations[2].value,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 3,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppColors.pink600.withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isSelected ? Icons.videocam : Icons.videocam,
                color: Colors.white,
                size: 30,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, NavBarItem item) {
    final isSelected = widget.selectedPosition == index;
    final isCenter = item.isCenter;

    if (isCenter) {
      return Expanded(child: SizedBox());
    }

    return Expanded(
      child: AnimatedBuilder(
        animation: _scaleAnimations[index],
        builder: (context, child) {
          return GestureDetector(
            onTap: () {
              widget.onItemTapped(index);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.pinkLight.withValues(alpha: 0.3), AppColors.pinkDark.withValues(alpha: 0.2)],
                              )
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.pink.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                            : null,
                      ),
                      child: Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                        size: 26,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                  Text(
                    _getLocalizedLabel(context, index),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getLocalizedLabel(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context);
    switch (index) {
      case 0:
        return l10n.navHome;
      case 1:
        return l10n.navSocial;
      case 2:
        return l10n.liveNow;
      case 3:
        return l10n.navInbox;
      case 4:
        return l10n.navMe;
      default:
        return "";
    }
  }
}

class NavBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCenter;

  NavBarItem({required this.icon, required this.activeIcon, required this.label, this.isCenter = false});
}
