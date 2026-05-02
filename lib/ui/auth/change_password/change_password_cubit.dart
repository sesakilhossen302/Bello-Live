import 'package:bloc/bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/secure_storage/secure_storage.dart';

part 'change_password_state.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit() : super(ChangePasswordState.initial());

  final secureStorage = GetIt.I<SecureStorage>();

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
    emit(
      state.copyWith(
        passwordConfirmVisibility: !state.passwordConfirmVisibility,
      ),
    );
  }

  void reset() {
    emit(ChangePasswordState.initial());
  }

  Future<void> updatePassword() async {
    emit(state.copyWith(status: ChangePasswordStatus.loading));

    await Future.delayed(const Duration(seconds: 1));

    if (state.password != state.confirmPassword) {
      emit(
        state.copyWith(
          status: ChangePasswordStatus.failure,
          error: "Passwords do not match",
        ),
      );
      return;
    }

    emit(state.copyWith(status: ChangePasswordStatus.success));
  }
}
