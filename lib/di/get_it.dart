import 'package:get_it/get_it.dart';

import '../core/cubits/app_cubit.dart';
import '../core/widgets/big_winner_overlay.dart';
import '../data/local/secure_storage/secure_storage.dart';

final getIt = GetIt.instance;

Future<void> registerDI() async {
  getIt.registerSingleton<SecureStorage>(SecureStorage());
  getIt.registerSingleton<AppCubit>(AppCubit(await retrieveAppState()));
  getIt.registerLazySingleton<BigWinnerQueue>(() => BigWinnerQueue());
}

Future<AppState> retrieveAppState() async {
  return AppState();
}
