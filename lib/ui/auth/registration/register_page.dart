import 'package:picture_live/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/primary_text_field.dart';
import '../../../navigation/routes.dart';
import '../../../theme/app_theme.dart';
import 'register_cubit.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RegisterCubit(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegisterCubit>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Header
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Create Account",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start your digital wallet journey',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // Registration Form Container
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
                        CustomTextField(
                          label: "Full Name",
                          hintText: "Enter your full name",
                          prefixIcon: Icons.person_outline,
                          onChanged: cubit.fullNameChanged,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Username",
                          hintText: "Choose a username",
                          prefixIcon: Icons.alternate_email_outlined,
                          onChanged: cubit.usernameChanged,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Email",
                          hintText: "Enter your email",
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: cubit.emailChanged,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Phone Number",
                          hintText: "Enter your phone number",
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          onChanged: cubit.phoneChanged,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Address",
                          hintText: "Enter your address",
                          prefixIcon: Icons.location_on_outlined,
                          onChanged: cubit.addressChanged,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: "Present Address",
                          hintText: "Enter your present address",
                          prefixIcon: Icons.home_outlined,
                          onChanged: cubit.presentAddressChanged,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        BlocBuilder<RegisterCubit, RegisterState>(
                          builder: (context, state) {
                            return CustomTextField(
                              label: "Password",
                              hintText: "Create a strong password",
                              prefixIcon: Icons.lock_outline,
                              obscureText: !state.passwordVisibility,
                              suffixIcon: state.passwordVisibility
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: cubit.togglePasswordVisibility,
                              onChanged: cubit.passwordChanged,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        BlocBuilder<RegisterCubit, RegisterState>(
                          builder: (context, state) {
                            return CustomTextField(
                              label: "Confirm Password",
                              hintText: "Confirm your password",
                              prefixIcon: Icons.lock_outline,
                              obscureText: !state.confirmPasswordVisibility,
                              suffixIcon: state.confirmPasswordVisibility
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap:
                                  cubit.toggleConfirmPasswordVisibility,
                              onChanged: cubit.confirmPasswordChanged,
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Terms and Conditions
                        BlocBuilder<RegisterCubit, RegisterState>(
                          builder: (context, state) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: state.acceptedTerms,
                                  onChanged: (_) => cubit.toggleAcceptTerms(),
                                  activeColor: AppColors.primary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                      "I agree to the Terms of Service and Privacy Policy",
                                      style: TextStyle(
                                        color: AppColors.textLight,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Register Button
                        BlocConsumer<RegisterCubit, RegisterState>(
                          listener: (context, state) {
                            if (state.status == RegisterStatus.failure) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    state.error ?? 'Registration failed',
                                  ),
                                ),
                              );
                              cubit.reset();
                            } else if (state.status == RegisterStatus.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Account created successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            return PrimaryButton(
                              text: "Create Account",
                              onPressed: state.status == RegisterStatus.loading
                                  ? null
                                  : () {
                                      cubit.register();
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                "or",
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/icons/google.png",
                                  height: 22,
                                  width: 22,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Sign up with Google",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Facebook Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  "assets/icons/fb.png",
                                  height: 22,
                                  width: 22,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Login with Facebook",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login Link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push(Routes.login.path),
                                child: Text(
                                  "Sign In",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
