import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/secure_storage/secure_storage.dart';

part 'verify_otp_state.dart';

class VerifyOTPCubit extends Cubit<VerifyOTPState> {
  VerifyOTPCubit() : super(VerifyOTPState.initial());

  final secureStorage = GetIt.I<SecureStorage>();

  void otpChanged(String value) {
    emit(state.copyWith(otp: value));
  }

  void reset() {
    emit(VerifyOTPState.initial());
  }

  Future<void> verifyOTP() async {
    emit(state.copyWith(status: VerifyOTPStatus.loading));

    await Future.delayed(const Duration(seconds: 1));

    if (state.otp.length < 6) {
      emit(state.copyWith(status: VerifyOTPStatus.failure, error: "OTP must be at least 6 characters long"));
      return;
    }

    emit(state.copyWith(status: VerifyOTPStatus.success));
  }
}
