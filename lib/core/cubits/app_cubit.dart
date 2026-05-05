import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../data/local/secure_storage/secure_storage.dart';
import '../../ui/auth/login/login_state.dart';
import '../widgets/big_winner_overlay.dart';

part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final secureStorage = GetIt.I<SecureStorage>();

  AppCubit(super.appState);

  logout() {
    secureStorage.logout();
    GetIt.I<BigWinnerQueue>().clearAndStop();
    emit(state.removeUser());
  }

  void changeLocale(Locale locale) {
    secureStorage.setLocale(locale.languageCode);
    emit(state.copyWith(locale: locale));
  }

  void minimizeRoom(MinimizedRoomData data) {
    emit(state.copyWith(minimizedRoom: data));
  }

  void closeMinimizedRoom() {
    emit(state.copyWith(clearMinimizedRoom: true));
  }
}
