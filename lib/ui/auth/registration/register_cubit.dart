import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/secure_storage/secure_storage.dart';
import '../login/login_state.dart';

part 'register_state.dart';

class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit() : super(RegisterState.initial());

  final secureStorage = GetIt.I<SecureStorage>();

  void fullNameChanged(String value) {
    emit(state.copyWith(fullName: value));
  }

  void usernameChanged(String value) {
    emit(state.copyWith(username: value));
  }

  void emailChanged(String value) {
    emit(state.copyWith(email: value));
  }

  void phoneChanged(String value) {
    emit(state.copyWith(phone: value));
  }

  void addressChanged(String value) {
    emit(state.copyWith(address: value));
  }

  void presentAddressChanged(String value) {
    emit(state.copyWith(presentAddress: value));
  }

  void passwordChanged(String value) {
    emit(state.copyWith(password: value));
  }

  void confirmPasswordChanged(String value) {
    emit(state.copyWith(confirmPassword: value));
  }

  void togglePasswordVisibility() {
    emit(state.copyWith(passwordVisibility: !state.passwordVisibility));
  }

  void toggleConfirmPasswordVisibility() {
    emit(state.copyWith(confirmPasswordVisibility: !state.confirmPasswordVisibility));
  }

  void toggleAcceptTerms() {
    emit(state.copyWith(acceptedTerms: !state.acceptedTerms));
  }

  void reset() {
    emit(RegisterState.initial());
  }

  String? _validateForm() {
    if (state.fullName.trim().isEmpty) {
      return 'Full name is required';
    }
    if (state.username.trim().isEmpty) {
      return 'Username is required';
    }
    if (state.username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (state.email.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(state.email)) {
      return 'Please enter a valid email address';
    }
    if (state.phone.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (state.phone.length < 10) {
      return 'Please enter a valid phone number';
    }
    if (state.address.trim().isEmpty) {
      return 'Address is required';
    }
    if (state.presentAddress.trim().isEmpty) {
      return 'Present address is required';
    }
    if (state.password.isEmpty) {
      return 'Password is required';
    }
    if (state.password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (state.confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (state.password != state.confirmPassword) {
      return 'Passwords do not match';
    }
    if (!state.acceptedTerms) {
      return 'Please accept the terms and conditions';
    }
    return null;
  }

  Future<void> register() async {
    final validationError = _validateForm();
    if (validationError != null) {
      emit(state.copyWith(status: RegisterStatus.failure, error: validationError));
      return;
    }

    emit(state.copyWith(status: RegisterStatus.loading));

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Here you would normally make an API call to register the user
      // For now, we'll simulate a successful registration

      // Save user data to secure storage
      await secureStorage.setUser(
        User(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Phone User',
          email: 'phone@example.com',
          phoneNumber: "01712345678",
          avatar: 'https://via.placeholder.com/150',
        ),
      );
      // You can save other user data as needed

      emit(state.copyWith(status: RegisterStatus.success));
    } catch (e) {
      emit(state.copyWith(status: RegisterStatus.failure, error: 'Registration failed. Please try again.'));
    }
  }
}
