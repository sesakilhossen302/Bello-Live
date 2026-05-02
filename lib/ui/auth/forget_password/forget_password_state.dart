part of 'forget_password_cubit.dart';

enum ForgetPasswordStatus { initial, loading, success, failure }

class ForgetPasswordState {
  final String email;
  final ForgetPasswordStatus status;
  final String? error;

  const ForgetPasswordState({
    required this.email,
    required this.status,
    this.error,
  });

  factory ForgetPasswordState.initial() {
    return const ForgetPasswordState(
      email: 'user@example.com',
      status: ForgetPasswordStatus.initial,
      error: null,
    );
  }

  ForgetPasswordState copyWith({
    String? email,
    String? password,
    ForgetPasswordStatus? status,
    String? error,
    bool? passwordVisibility,
  }) {
    return ForgetPasswordState(
      email: email ?? this.email,
      status: status ?? this.status,
      error: error,
    );
  }
}
