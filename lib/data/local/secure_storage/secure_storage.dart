import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../ui/auth/login/login_state.dart';

class SecureStorage {
  late FlutterSecureStorage storage;

  SecureStorage() {
    const aOptions = AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
      preferencesKeyPrefix: "picture_",
      sharedPreferencesName: 'picture_preferences',
    );

    storage = const FlutterSecureStorage(aOptions: aOptions);
  }

  static const String userKey = 'current_user';
  static const String localeKey = 'app_locale';

  // Save user data - having a user implies being logged in
  Future<void> setUser(User user) async {
    final userJson = jsonEncode(user.toJson());
    return await storage.write(key: userKey, value: userJson);
  }

  // Get user data - if user exists, they are logged in
  Future<User?> getUser() async {
    final userJson = await storage.read(key: userKey);
    if (userJson != null) {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    }
    return null;
  }

  // Check if user is logged in by checking if user data exists
  Future<bool> get isLoggedIn async {
    return await getUser() != null;
  }

  // Logout by removing user data
  Future<void> logout() async {
    return await storage.delete(key: userKey);
  }

  // Save locale
  Future<void> setLocale(String languageCode) async {
    return await storage.write(key: localeKey, value: languageCode);
  }

  // Get locale
  Future<String?> getLocale() async {
    return await storage.read(key: localeKey);
  }
}