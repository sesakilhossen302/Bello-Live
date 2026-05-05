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
    setState(() {
      _selectedPosition = index;
    });

    switch (index) {
      case 0:
        context.push(Routes.home.path);
        break;
      case 1:
        context.push(Routes.status.path);
        break;
      case 2:
        context.go(Routes.hostPage.path);
        break;
      case 3:
        context.push(Routes.inbox.path);
        break;
      case 4:
        context.push(Routes.profile.path);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        return Scaffold(
          extendBody: true,
          bottomNavigationBar: MyBottomNavBar(selectedPosition: _selectedPosition, onItemTapped: _onItemTapped),
          body: widget.child,
        );
      },
    );
  }
}
