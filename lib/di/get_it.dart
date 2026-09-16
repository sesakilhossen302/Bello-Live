import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../core/cubits/app_cubit.dart';

import '../data/local/secure_storage/secure_storage.dart';

final getIt = GetIt.instance;

Future<void> registerDI() async {
  getIt.registerSingleton<SecureStorage>(SecureStorage());
  getIt.registerSingleton<AppCubit>(AppCubit(await retrieveAppState()));

}

Future<AppState> retrieveAppState() async {
  final secureStorage = GetIt.I<SecureStorage>();
  final user = await secureStorage.getUser();
  final localeCode = await secureStorage.getLocale();
  
  return AppState(
    user: user,
    locale: localeCode != null ? Locale(localeCode) : const Locale('en'),
  );
}
