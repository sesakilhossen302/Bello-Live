import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:picture_live/theme/app_theme.dart';
import 'core/cubits/app_cubit.dart';
import 'core/localization/app_localizations.dart';
import 'data/remote/firebase/notification_service.dart';
import 'di/get_it.dart';
import 'firebase_options.dart';
import 'navigation/my_router.dart';
import 'ui/widgets/floating_minimized_room.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerDI();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
  NotificationService.initialize();

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
            title: 'MP LIVE',
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
              return Stack(
                children: [
                  if (child != null) child,
                  const FloatingMinimizedRoom(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
