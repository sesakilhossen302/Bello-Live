import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/secure_storage/secure_storage.dart';

part 'forget_password_state.dart';

class ForgetPasswordCubit extends Cubit<ForgetPasswordState> {
  ForgetPasswordCubit() : super(ForgetPasswordState.initial());

  final secureStorage = GetIt.I<SecureStorage>();

  void emailChanged(String value) {
    emit(state.copyWith(email: value));
  }

  void reset() {
    emit(ForgetPasswordState.initial());
  }

  Future<void> sendOTP() async {
    emit(state.copyWith(status: ForgetPasswordStatus.loading));

    await Future.delayed(const Duration(seconds: 1));

    emit(state.copyWith(status: ForgetPasswordStatus.success));
  }
}
