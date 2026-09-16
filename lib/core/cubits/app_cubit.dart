import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:version/version.dart';

import '../../data/local/secure_storage/secure_storage.dart';
import '../../ui/auth/login/login_state.dart';


part 'app_state.dart';

class AppCubit extends Cubit<AppState> {
  final secureStorage = GetIt.I<SecureStorage>();

  AppCubit(super.appState);

  logout() {
    secureStorage.logout();

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

  Future<void> checkAppVersion() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('appSettings').doc('app_version').get();
      if (doc.exists) {
        final data = doc.data()!;
        final minVersionStr = data['minimum_version'] as String?;
        final updateUrl = data['update_url'] as String?;

        if (minVersionStr != null && minVersionStr.isNotEmpty) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersionStr = packageInfo.version;

          final minVersion = Version.parse(minVersionStr);
          final currentVersion = Version.parse(currentVersionStr);

          if (currentVersion < minVersion) {
            emit(state.copyWith(
              isUpdateRequired: true,
              updateUrl: updateUrl ?? '',
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
    }
  }
}
