import 'package:picture_live/core/widgets/primary_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:picture_live/core/widgets/primary_button.dart';
import '../../../navigation/routes.dart';
import '../../../theme/app_theme.dart';
import 'change_password_cubit.dart';

class ChangePasswordPage extends StatelessWidget {
  const ChangePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => ChangePasswordCubit(), child: const _ChangePasswordView());
  }
}

class _ChangePasswordView extends StatelessWidget {
  const _ChangePasswordView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChangePasswordCubit>();

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      context.pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 12, right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset("assets/icons/back.svg"),
                          SizedBox(width: 4),
                          Text("Change password", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), spreadRadius: 0, blurRadius: 20, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      children: [
                        BlocBuilder<ChangePasswordCubit, ChangePasswordState>(
                          builder: (context, state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomTextField(
                                  label: "New password",
                                  hintText: "enter a new password",
                                  obscureText: !state.passwordVisibility,
                                  prefixIcon: Icons.password,
                                  suffixIcon: state.passwordVisibility ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  onSuffixTap: () {
                                    cubit.togglePasswordVisibility();
                                  },
                                ),
                                SizedBox(height: 12),
                                CustomTextField(
                                  label: "Confirm password",
                                  hintText: "re-enter password",
                                  obscureText: !state.passwordConfirmVisibility,
                                  prefixIcon: Icons.password,
                                  suffixIcon: state.passwordConfirmVisibility ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  onSuffixTap: () {
                                    cubit.toggleConfirmPasswordVisibility();
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
                          listener: (context, state) {
                            if (state.status == ChangePasswordStatus.failure) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error ?? 'ChangePassword failed')));
                              cubit.reset();
                            } else if (state.status == ChangePasswordStatus.success) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password updated successfully!")));
                              context.go(Routes.login.path);
                            }
                          },
                          builder: (context, state) {
                            return PrimaryButton(
                              text: "Update",
                              onPressed: () {
                                cubit.updatePassword();
                              },
                              isLoading: state.status == ChangePasswordStatus.loading,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
