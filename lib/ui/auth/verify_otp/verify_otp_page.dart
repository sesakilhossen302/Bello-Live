import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:picture_live/core/widgets/primary_button.dart';
import '../../../navigation/routes.dart';
import '../../../theme/app_theme.dart';
import 'verify_otp_cubit.dart';

class VerifyOTPPage extends StatelessWidget {
  const VerifyOTPPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VerifyOTPCubit(),
      child: const _VerifyOTPView(),
    );
  }
}

class _VerifyOTPView extends StatelessWidget {
  const _VerifyOTPView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyOTPCubit>();

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
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
                      padding: const EdgeInsets.only(
                        top: 12,
                        bottom: 12,
                        right: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset("assets/icons/back.svg"),
                          SizedBox(width: 4),
                          Text(
                            "Forget password",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Don't worry, we can help you get back in. Enter the email address associated with your account",
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          "Enter the OTP sent to your email ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Email
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 330,
                          child: PinCodeTextField(
                            appContext: context,
                            length: 6,
                            onChanged: (value) {
                              cubit.otpChanged(value);
                            },
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(8),
                              fieldHeight: 40,
                              fieldWidth: 40,
                              activeFillColor: AppColors.primaryLight,
                              inactiveFillColor: AppColors.primaryLight,
                              selectedFillColor: AppColors.primaryLight,
                              activeColor: Colors.transparent,
                              inactiveColor: Colors.transparent,
                              selectedColor: AppColors.primary,
                            ),
                            keyboardType: TextInputType.number,
                            boxShadows: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                            enableActiveFill: true,
                          ),
                        ),
                        const SizedBox(height: 26),
                        BlocConsumer<VerifyOTPCubit, VerifyOTPState>(
                          listener: (context, state) {
                            if (state.status == VerifyOTPStatus.failure) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    state.error ?? 'VerifyOTP failed',
                                  ),
                                ),
                              );
                              cubit.reset();
                            } else if (state.status ==
                                VerifyOTPStatus.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('OTP verification successful.'),
                                ),
                              );
                              context.pushReplacement(
                                Routes.changePassword.path,
                              );
                            }
                          },
                          builder: (context, state) {
                            return PrimaryButton(
                              text: "Verify OTP",
                              onPressed: () {
                                cubit.verifyOTP();
                              },
                              isLoading:
                                  state.status == VerifyOTPStatus.loading,
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
