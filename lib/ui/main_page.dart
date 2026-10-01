import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/cubits/app_cubit.dart';
import '../navigation/my_bottom_navigation.dart';
import '../navigation/routes.dart';

class MainPage extends StatefulWidget {
  final Widget child;
  final int? selectedPageNo;

  const MainPage({super.key, required this.child, this.selectedPageNo});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late int _selectedPosition;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.selectedPageNo ?? 0;
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      context.push(Routes.hostPage.path);
      return; // Do not update _selectedPosition for the center button
    }

    setState(() {
      _selectedPosition = index;
    });

    switch (index) {
      case 0:
        context.go(Routes.home.path); // Use go to switch tabs without pushing a new stack
        break;
      case 1:
        context.go(Routes.status.path);
        break;
      case 3:
        context.go(Routes.inbox.path);
        break;
      case 4:
        context.go(Routes.profile.path);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A052A),
          extendBody: true,
          bottomNavigationBar: MyBottomNavBar(
            selectedPosition: _selectedPosition,
            onItemTapped: _onItemTapped,
          ),
          body: widget.child,
        );
      },
    );
  }
}
