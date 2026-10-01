import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:picture_live/theme/app_theme.dart';
import 'core/cubits/app_cubit.dart';
import 'core/localization/app_localizations.dart';
import 'data/remote/firebase/notification_service.dart';
import 'data/remote/firebase/level_service.dart';
import 'data/remote/firebase/app_services.dart';
import 'di/get_it.dart';
import 'firebase_options.dart';
import 'navigation/my_router.dart';
import 'ui/widgets/floating_minimized_room.dart';

import 'ui/widgets/user_block_listener.dart';
import 'core/services/home_banner_cache_service.dart';
import 'ui/widgets/force_update_screen.dart';
import 'ui/widgets/global_device_ban_listener.dart';
import 'ui/widgets/global_gift_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerDI();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Prefetch LiveKit & RTC endpoints from Firestore
    unawaited(AppServices.getLiveKitConfig());
    // Pre-cache banners and agencies from disk and start background sync
    unawaited(HomeBannerCacheService.init());
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  await LevelService.init();
  NotificationService.initialize();

  GetIt.I<AppCubit>().checkAppVersion();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => GetIt.I<AppCubit>())],
      child: BlocBuilder<AppCubit, AppState>(
        builder: (context, state) {
          return MaterialApp.router(
            routerConfig: MyRouter.router,
            debugShowCheckedModeBanner: false,
            title: 'Pigo Live',
            locale: state.locale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('bn'),
              Locale('hi'),
              Locale('ur'),
              Locale('es'),
            ],
            themeMode: ThemeMode.light,
            theme: AppTheme.themeData(),
            builder: (context, child) {
              return StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  final isLoggedIn = snapshot.hasData && snapshot.data != null;
                  return Stack(
                    children: [
                      // Global Premium Background
                      const GlobalAppBackground(),
                      if (child != null) child,
                      if (isLoggedIn) const FloatingMinimizedRoom(),
                      if (isLoggedIn) const GlobalGiftBanner(),

                      if (isLoggedIn) const UserBlockListener(),
                      if (state.isUpdateRequired) 
                        ForceUpdateScreen(updateUrl: state.updateUrl),
                      const GlobalDeviceBanListener(),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
