part of 'register_cubit.dart';

enum RegisterStatus { initial, loading, success, failure }

class RegisterState {
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String address;
  final String presentAddress;
  final String password;
  final String confirmPassword;
  final bool passwordVisibility;
  final bool confirmPasswordVisibility;
  final bool acceptedTerms;
  final RegisterStatus status;
  final String? error;

  const RegisterState({
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.address,
    required this.presentAddress,
    required this.password,
    required this.confirmPassword,
    required this.passwordVisibility,
    required this.confirmPasswordVisibility,
    required this.acceptedTerms,
    required this.status,
    this.error,
  });

  factory RegisterState.initial() {
    return const RegisterState(
      fullName: '',
      username: '',
      email: '',
      phone: '',
      address: '',
      presentAddress: '',
      password: '',
      confirmPassword: '',
      passwordVisibility: false,
      confirmPasswordVisibility: false,
      acceptedTerms: false,
      status: RegisterStatus.initial,
      error: null,
    );
  }

  RegisterState copyWith({
    String? fullName,
    String? username,
    String? email,
    String? phone,
    String? address,
    String? presentAddress,
    String? password,
    String? confirmPassword,
    bool? passwordVisibility,
    bool? confirmPasswordVisibility,
    bool? acceptedTerms,
    RegisterStatus? status,
    String? error,
  }) {
    return RegisterState(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      presentAddress: presentAddress ?? this.presentAddress,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      passwordVisibility: passwordVisibility ?? this.passwordVisibility,
      confirmPasswordVisibility: confirmPasswordVisibility ?? this.confirmPasswordVisibility,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      status: status ?? this.status,
      error: error,
    );
  }
}