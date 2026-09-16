import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';

import '../../core/cubits/app_cubit.dart';
import '../../core/localization/app_localizations.dart';
import '../../theme/app_theme.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);
    
    final languages = [
      {'name': 'English', 'code': 'en', 'native': 'English'},
      {'name': 'Bengali', 'code': 'bn', 'native': 'বাংলা'},
      {'name': 'Hindi', 'code': 'hi', 'native': 'हिन्दी'},
      {'name': 'Urdu', 'code': 'ur', 'native': 'اردو'},
      {'name': 'Spanish', 'code': 'es', 'native': 'Español'},
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).selectLanguage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balancing the back button
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Language List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = currentLocale.languageCode == lang['code'];

                    return GestureDetector(
                      onTap: () {
                        context.read<AppCubit>().changeLocale(Locale(lang['code']!));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: isSelected 
                            ? Colors.black.withValues(alpha: 0.5) 
                            : Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                              child: Row(
                                children: [
                                  // Icon or Flag placeholder
                                  Container(
                                    width: 45,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected 
                                        ? Colors.white.withValues(alpha: 0.15) 
                                        : Colors.white.withValues(alpha: 0.1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        lang['code']!.toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  // Language Names
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lang['native']!,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                            fontSize: 18,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          lang['name']!,
                                          style: TextStyle(
                                            color: isSelected 
                                              ? Colors.white70 
                                              : Colors.white.withValues(alpha: 0.5),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Checkmark
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
