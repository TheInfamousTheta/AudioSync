import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_event.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';
import 'package:audio_sync/features/navigation/main_shell.dart';
import 'package:audio_sync/features/auth/screens/preferences_screen.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _usernameController.clear();
      _passwordController.clear();
      _formKey.currentState?.reset();
    });
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      if (_isLoginMode) {
        context.read<AuthBloc>().add(SubmitLoginEvent(username: username, password: password));
      } else {
        context.read<AuthBloc>().add(SubmitRegisterEvent(username: username, password: password));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    debugPrint('AuthScreen: BlocConsumer Listener received state: ${state.runtimeType}');
                    if (state is AuthFailureState) {
                      debugPrint('AuthScreen: AuthFailureState: ${state.errorMessage}');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          content: Text(
                            state.errorMessage,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    } else if (state is AuthAuthenticatedState) {
                      debugPrint('AuthScreen: AuthAuthenticatedState: Pushing MainShell');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MainShell()),
                      );
                    } else if (state is AuthNeedsOnboardingState) {
                      debugPrint('AuthScreen: AuthNeedsOnboardingState: Pushing PreferencesScreen');
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const PreferencesScreen()),
                      );
                    } else if (state is AuthUnauthenticatedState && state.message != null) {
                      debugPrint('AuthScreen: AuthUnauthenticatedState with message: ${state.message}');
                      setState(() {
                        _isLoginMode = true;
                      });
                      _usernameController.clear();
                      _passwordController.clear();
                      _formKey.currentState?.reset();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.primaryNeon.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          content: Text(
                            state.message!,
                            style: const TextStyle(color: AppColors.baseSurface, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    final isLoading = state is AuthLoadingState;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _AuthLogoHeader(isLoginMode: _isLoginMode),
                        const SizedBox(height: 36),
                        GlassContainer(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                          borderRadius: 24,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLoginMode ? 'Login' : 'Create Stage',
                                  style: const TextStyle(
                                    fontFamily: 'Plus Jakarta Sans',
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'USERNAME',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.subText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: !isLoading,
                                  style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                                  cursorColor: AppColors.primaryNeon,
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Username is required.';
                                    }
                                    if (val.trim().length < 3) {
                                      return 'Username must be at least 3 characters.';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'e.g. maestro',
                                    hintStyle: TextStyle(color: AppColors.subText.withValues(alpha: 0.5)),
                                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.subText, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.primaryNeon, width: 1.5),
                                    ),
                                    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'PASSWORD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.subText,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: !isLoading,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                                  cursorColor: AppColors.primaryNeon,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Password is required.';
                                    }
                                    if (val.length < 6) {
                                      return 'Password must be at least 6 characters.';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    hintStyle: TextStyle(color: AppColors.subText.withValues(alpha: 0.5)),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.subText, size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                        color: AppColors.subText,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: AppColors.primaryNeon, width: 1.5),
                                    ),
                                    errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                  ),
                                ),
                                const SizedBox(height: 36),
                                GestureDetector(
                                  onTap: isLoading ? null : _submitForm,
                                  child: Container(
                                    width: double.infinity,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.laserEtched,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryNeon.withValues(alpha: 0.2),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: AppColors.baseSurface,
                                                strokeWidth: 2.5,
                                              ),
                                            )
                                          : Text(
                                              _isLoginMode ? 'Enter Stage' : 'Initialize Studio',
                                              style: const TextStyle(
                                                color: AppColors.baseSurface,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: isLoading ? null : _toggleAuthMode,
                          child: RichText(
                            text: TextSpan(
                              text: _isLoginMode ? "Don't have a signature stage? " : "Already registered? ",
                              style: const TextStyle(color: AppColors.subText, fontSize: 13),
                              children: [
                                TextSpan(
                                  text: _isLoginMode ? 'Create New' : 'Login Here',
                                  style: const TextStyle(
                                    color: AppColors.primaryNeon,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky)),
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryNeon.withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xff8E2DE2).withValues(alpha: 0.04),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLogoHeader extends StatelessWidget {
  final bool isLoginMode;
  const _AuthLogoHeader({required this.isLoginMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.laserEtched,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNeon.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.audiotrack_rounded, color: AppColors.baseSurface, size: 36),
        ),
        const SizedBox(height: 24),
        const Text(
          'AUDIOSYNC',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isLoginMode
              ? 'Enter the atmospheric sound stage.'
              : 'Register your signature stage credentials.',
          style: const TextStyle(fontSize: 12, color: AppColors.subText),
        ),
      ],
    );
  }
}
