part of 'change_password_cubit.dart';

enum ChangePasswordStatus { initial, loading, success, failure }

class ChangePasswordState {
  final String password;
  final String confirmPassword;
  final bool passwordVisibility;
  final bool passwordConfirmVisibility;
  final ChangePasswordStatus status;
  final String? error;

  const ChangePasswordState({
    required this.password,
    required this.confirmPassword,
    required this.passwordVisibility,
    required this.passwordConfirmVisibility,
    required this.status,
    this.error,
  });

  factory ChangePasswordState.initial() {
    return const ChangePasswordState(
      password: '',
      confirmPassword: '',
      passwordVisibility: false,
      passwordConfirmVisibility: false,
      status: ChangePasswordStatus.initial,
      error: null,
    );
  }

  ChangePasswordState copyWith({
    String? password,
    String? confirmPassword,
    ChangePasswordStatus? status,
    String? error,
    bool? passwordVisibility,
    bool? passwordConfirmVisibility,
  }) {
    return ChangePasswordState(
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      status: status ?? this.status,
      passwordVisibility: passwordVisibility ?? this.passwordVisibility,
      passwordConfirmVisibility:
          passwordConfirmVisibility ?? this.passwordConfirmVisibility,
      error: error,
    );
  }
}
