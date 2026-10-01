import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_udid/flutter_udid.dart';
import '../../../data/local/secure_storage/secure_storage.dart';
import '../../../data/remote/firebase/profile_services.dart';
import 'login_state.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit() : super(const LoginState());

  final secureStorage = GetIt.I<SecureStorage>();
  final _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  Future<void> _initializeGoogleSignIn() async {
    try {
      // serverClientId from google-services.json (Web client ID)
      await _googleSignIn.initialize(
        serverClientId: "993990672871-cbflbvibv8eglkathunk6vn2qb3nq5tj.apps.googleusercontent.com",
      );
      _isGoogleSignInInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Google Sign-In: $e');
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  Future<bool> _isDeviceBannedAndStore(String uid) async {
    try {
      String deviceId = await FlutterUdid.udid;
      final querySnapshot = await FirebaseFirestore.instance
          .collection('banned_devices')
          .where('deviceId', isEqualTo: deviceId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return true;
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'deviceId': deviceId,
      });
      return false;
    } catch (e) {
      debugPrint("Error checking device ban: $e");
      return false;
    }
  }

  Future<bool> _isEmailBanned(String? email) async {
    if (email == null || email.isEmpty) return false;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('banned_emails')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking email ban: $e");
      return false;
    }
  }

  Future<void> loginWithGoogle() async {
    emit(state.copyWith(status: LoginStatus.loading, method: LoginMethod.google));
    try {
      await _ensureGoogleSignInInitialized();

      // Authenticate with Google
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      if (googleUser == null) {
        emit(state.copyWith(status: LoginStatus.initial));
        return;
      }

      // Get ID Token (Synchronous in 7.0.0+)
      final String? idToken = googleUser.authentication.idToken;

      // Get Access Token (Asynchronous in 7.0.0+ via authorizationClient)
      final authorization = await googleUser.authorizationClient.authorizationForScopes(['email']);
      final String? accessToken = authorization?.accessToken;

      if (idToken == null) {
        throw Exception("Could not get ID Token from Google");
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      try {
        await ProfileService.syncUserProfile();
      } catch (profileError) {
        debugPrint("Error syncing user profile: $profileError");
      }

      // Fetch updated user document after balance update
      final updatedUserDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
      final updatedUserData = updatedUserDoc.data();

      if (updatedUserData?['isBlocked'] == true) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        emit(state.copyWith(status: LoginStatus.failure, error: 'Your account has been blocked by the admin.'));
        return;
      }

      bool isBanned = await _isDeviceBannedAndStore(userCredential.user!.uid);
      if (isBanned) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        emit(state.copyWith(status: LoginStatus.failure, error: 'This device is banned.'));
        return;
      }

      bool isEmailBanned = await _isEmailBanned(userCredential.user!.email);
      if (isEmailBanned) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        emit(state.copyWith(status: LoginStatus.failure, error: 'This email is banned.'));
        return;
      }

      final User user = User(
        id: userCredential.user!.uid,
        displayId: updatedUserData?['displayId'] ?? "",
        name: updatedUserData?['displayName'] ?? userCredential.user!.displayName ?? "Unknown",
        email: userCredential.user!.email!,
        avatar: updatedUserData?['photoUrl'] ?? userCredential.user!.photoURL,
      );

      secureStorage.setUser(user);
      emit(state.copyWith(status: LoginStatus.success, user: user));
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error during Google Sign-In: ${e.code} - ${e.message}');
      emit(state.copyWith(status: LoginStatus.failure, error: e.message ?? 'Google sign-in failed. Please try again.'));
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      emit(state.copyWith(status: LoginStatus.failure, error: 'Google sign-in failed: ${e.toString()}'));
    }
  }

  // Dummy API service simulation
  Future<void> _simulateApiCall() async {
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> loginWithPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      emit(state.copyWith(status: LoginStatus.failure, error: 'Please enter a valid phone number'));
      return;
    }

    emit(state.copyWith(status: LoginStatus.loading, method: LoginMethod.phone, phoneNumber: phoneNumber, error: ''));

    try {
      await _simulateApiCall();

      // Simulate successful login
      if (phoneNumber.contains('123')) {
        // final user = User(
        //   id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        //   name: 'Phone User',
        //   email: 'phone@example.com',
        //   phoneNumber: phoneNumber,
        //   avatar: 'https://via.placeholder.com/150',
        // );
        // await secureStorage.setUser(user);
        // emit(state.copyWith(status: LoginStatus.success, user: user));
      } else {
        emit(state.copyWith(status: LoginStatus.failure, error: 'Invalid phone number. Please try again.'));
      }
    } catch (e) {
      emit(state.copyWith(status: LoginStatus.failure, error: 'Network error. Please check your connection.'));
    }
  }

  Future<void> loginWithCredentials(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      emit(state.copyWith(status: LoginStatus.failure, error: 'Please fill in all fields'));
      return;
    }

    emit(
      state.copyWith(
        status: LoginStatus.loading,
        method: LoginMethod.credentials,
        userId: trimmedEmail,
        password: password,
      ),
    );

    try {
      // Authenticate with Firebase Email/Password
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Query Firestore for user document
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> userData = {};
      
      if (userDoc.exists && userDoc.data() != null) {
        userData = userDoc.data()!;
        
        if (userData['isBlocked'] == true) {
          await FirebaseAuth.instance.signOut();
          emit(state.copyWith(status: LoginStatus.failure, error: 'Your account has been blocked by the admin.'));
          return;
        }

        bool isBanned = await _isDeviceBannedAndStore(uid);
        if (isBanned) {
          await FirebaseAuth.instance.signOut();
          emit(state.copyWith(status: LoginStatus.failure, error: 'This device is banned.'));
          return;
        }

        bool isEmailBanned = await _isEmailBanned(userCredential.user!.email);
        if (isEmailBanned) {
          await FirebaseAuth.instance.signOut();
          emit(state.copyWith(status: LoginStatus.failure, error: 'This email is banned.'));
          return;
        }

        // Update last login
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        userData = {
          'email': userCredential.user!.email,
          'displayName': userCredential.user!.displayName ?? 'User',
          'photoUrl': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        };
        // Save the new user data to Firestore
        await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
      }

      // Create User object
      final user = User(
        id: uid,
        displayId: userData['displayId'] ?? '',
        name: userData['displayName'] ?? 'User',
        email: userData['email'] ?? userCredential.user!.email ?? '',
        avatar: userData['photoUrl'],
        phoneNumber: userData['phoneNumber'],
      );

      await secureStorage.setUser(user);
      emit(state.copyWith(status: LoginStatus.success, user: user));
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errorMessage = 'Invalid email or password.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is badly formatted.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }
      emit(state.copyWith(status: LoginStatus.failure, error: errorMessage));
    } catch (e) {
      debugPrint('Login error: $e');
      emit(state.copyWith(status: LoginStatus.failure, error: 'Login failed. Please try again.'));
    }
  }

  Future<void> loginWithFacebook() async {
    emit(state.copyWith(status: LoginStatus.loading, method: LoginMethod.facebook, error: ''));

    try {
      await _simulateApiCall();

      // Simulate successful Facebook login
      final user = User(
        id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Facebook User',
        email: 'facebook@facebook.com',
        avatar: 'https://via.placeholder.com/150',
      );

      emit(state.copyWith(status: LoginStatus.success, user: user));
    } catch (e) {
      emit(state.copyWith(status: LoginStatus.failure, error: 'Facebook sign-in failed. Please try again.'));
    }
  }

  void resetError() {
    emit(state.copyWith(error: ''));
  }

  void resetState() {
    emit(const LoginState());
  }

  void updatePhoneNumber(String phoneNumber) {
    emit(state.copyWith(phoneNumber: phoneNumber));
  }

  void updateUserId(String userId) {
    emit(state.copyWith(userId: userId));
  }

  void updatePassword(String password) {
    emit(state.copyWith(password: password));
  }
}
