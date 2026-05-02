import 'package:flutter/material.dart';

class MyAppBar extends AppBar {
  MyAppBar({
    super.key,
    required String title,
    disableBackButton = false,
    required String selectedLanguage,
    ThemeMode themeMode = ThemeMode.light,
    VoidCallback? onPressed,
    super.toolbarHeight = 56,
    super.flexibleSpace,
  }) : super(
         leading: disableBackButton ? null : Icon(Icons.arrow_back),
         title: Container(
           alignment: Alignment.center,
           margin: const EdgeInsets.only(right: 8),
           child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
         ),
         titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
         backgroundColor: Colors.white,
         elevation: 0,
         actions: [
           IconButton(
             icon: const Icon(Icons.settings),
             onPressed: onPressed,
             tooltip: 'Settings',
           ),
         ],
       );
}
