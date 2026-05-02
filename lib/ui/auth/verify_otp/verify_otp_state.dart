part of 'verify_otp_cubit.dart';

enum VerifyOTPStatus { initial, loading, success, failure }

class VerifyOTPState {
  final String otp;
  final VerifyOTPStatus status;
  final String? error;

  const VerifyOTPState({required this.otp, required this.status, this.error});

  factory VerifyOTPState.initial() {
    return const VerifyOTPState(
      otp: '',
      status: VerifyOTPStatus.initial,
      error: null,
    );
  }

  VerifyOTPState copyWith({
    String? otp,
    VerifyOTPStatus? status,
    String? error,
  }) {
    return VerifyOTPState(
      otp: otp ?? this.otp,
      status: status ?? this.status,
      error: error,
    );
  }
}
