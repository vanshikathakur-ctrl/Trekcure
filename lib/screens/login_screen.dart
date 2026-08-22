import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/fcm_service.dart';
import '../theme/app_theme.dart';
import 'home_dashboard_screen.dart';
import 'registration_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  StreamSubscription<AuthState>? _authSubscription;

  bool _openedResetScreen = false;

  static const String _passwordResetRedirect =
      'io.supabase.trekcure://reset-password';

  @override
  void initState() {
    super.initState();
    _listenForPasswordRecovery();
  }

  // ============================================================
  // PASSWORD RECOVERY LISTENER
  // ============================================================

  void _listenForPasswordRecovery() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(
      (AuthState data) {
        debugPrint(
          'SUPABASE AUTH EVENT: ${data.event}',
        );

        if (data.event == AuthChangeEvent.passwordRecovery) {
          _openResetPasswordScreen();
        }
      },
    );
  }

  // ============================================================
  // OPEN RESET PASSWORD SCREEN
  // ============================================================

  void _openResetPasswordScreen() {
    if (!mounted) return;

    if (_openedResetScreen) return;

    _openedResetScreen = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ResetPasswordScreen(),
        ),
      ).then((_) {
        _openedResetScreen = false;
      });
    });
  }

  // ============================================================
  // CONTINUE AS GUEST
  // ============================================================

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeDashboardScreen(),
      ),
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _loginUser() async {
    final String email = _idController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    if (password.isEmpty) {
      _showMessage(
        'Please enter your password.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response =
          await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        _showMessage(
          'Login failed. Please check your details.',
        );
        return;
      }

      final Session? session =
          Supabase.instance.client.auth.currentSession;

      if (session == null) {
        _showMessage(
          'Could not create a login session.',
        );
        return;
      }

      debugPrint(
        'LOGIN SUCCESS: ${response.user!.id}',
      );

      // ========================================================
      // FCM
      // ========================================================

      try {
        debugPrint('About to call FCM');

        await initializeFcm();

        debugPrint('FCM call finished');
      } catch (e) {
        debugPrint(
          'FCM INITIALIZATION ERROR: $e',
        );
      }

      if (!mounted) return;

      _showMessage('Login successful!');

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeDashboardScreen(),
        ),
      );
    } on AuthException catch (e) {
      debugPrint(
        'SUPABASE LOGIN ERROR: ${e.message}',
      );

      if (!mounted) return;

      _showMessage(e.message);
    } catch (e) {
      debugPrint(
        'LOGIN ERROR: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to login. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();

    _idController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ==================================================
              // TREKCURE LOGO
              // ==================================================

              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  children: [
                    TextSpan(
                      text: 'Trek',
                    ),
                    TextSpan(
                      text: 'Cure',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // WELCOME
              // ==================================================

              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Login to continue your journey',
                style: TextStyle(
                  color: AppColors.textGrey,
                ),
              ),

              const SizedBox(height: 32),

              // ==================================================
              // TREKKING IMAGE
              // ==================================================

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 160,
                  child: Image.asset(
                    'asset/images/login_travel.jpeg',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      debugPrint(
                        'LOGIN IMAGE ERROR: $error',
                      );

                      return Container(
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons
                                  .image_not_supported_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Image could not be loaded',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // EMAIL
              // ==================================================

              TextField(
                controller: _idController,
                keyboardType:
                    TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Email / Mobile Number',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // PASSWORD
              // ==================================================

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword =
                            !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),

              // ==================================================
              // FORGOT PASSWORD
              // ==================================================

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // LOGIN
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _loginUser,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'OR',
                style: TextStyle(
                  color: AppColors.textGrey,
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // CREATE ACCOUNT
              // ==================================================

              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const RegistrationPage(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(52),
                  side: const BorderSide(
                    color: AppColors.primaryGreen,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create New Account',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // GUEST
              // ==================================================

              TextButton(
                onPressed: _goHome,
                child: const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    color: AppColors.textGrey,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// FORGOT PASSWORD SCREEN
// ==================================================================

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  bool _loading = false;

  // ============================================================
  // SEND RESET LINK
  // ============================================================

  Future<void> _sendResetEmail() async {
    final String email =
        _emailController.text.trim();

    if (email.isEmpty) {
      _message(
        'Please enter your email address.',
      );
      return;
    }

    if (!email.contains('@')) {
      _message(
        'Please enter a valid email address.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      debugPrint(
        'REQUESTING PASSWORD RESET FOR: $email',
      );

      await Supabase.instance.client.auth
          .resetPasswordForEmail(
        email,
        redirectTo:
            _LoginScreenState
                ._passwordResetRedirect,
      );

      debugPrint(
        'PASSWORD RESET REQUEST SENT',
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Check your email',
                  ),
                ),
              ],
            ),
            content: Text(
              'A password reset link has been sent to $email.\n\nOpen the email and tap the reset link. TrekCure will open and allow you to create a new password.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthException catch (e) {
      debugPrint(
        'PASSWORD RESET AUTH ERROR: ${e.message}',
      );

      if (!mounted) return;

      _message(e.message);
    } catch (e) {
      debugPrint(
        'PASSWORD RESET ERROR: $e',
      );

      if (!mounted) return;

      _message(
        'Could not send the password reset email. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),

          const CircleAvatar(
            radius: 38,
            backgroundColor:
                AppColors.lightGreenBg,
            child: Icon(
              Icons.lock_reset_rounded,
              size: 42,
              color:
                  AppColors.primaryGreen,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Reset your password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Enter the email address associated with your TrekCure account. We will send you a secure password reset link.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textGrey,
            ),
          ),

          const SizedBox(height: 30),

          TextField(
            controller:
                _emailController,
            keyboardType:
                TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText:
                  'Email Address',
              hintText:
                  'Enter your account email',
              prefixIcon:
                  Icon(
                Icons.email_outlined,
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _sendResetEmail,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        color:
                            Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'After opening the reset link from your email, TrekCure will open the password-change screen.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color:
                  AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// RESET PASSWORD SCREEN
// ==================================================================

class ResetPasswordScreen
    extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
  });

  @override
  State<ResetPasswordScreen>
      createState() =>
          _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final TextEditingController
      _newPasswordController =
      TextEditingController();

  final TextEditingController
      _confirmPasswordController =
      TextEditingController();

  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;
  bool _loading = false;

  // ============================================================
  // UPDATE PASSWORD
  // ============================================================

  Future<void> _updatePassword() async {
    final String newPassword =
        _newPasswordController.text;

    final String confirmPassword =
        _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      _message(
        'Please enter a new password.',
      );
      return;
    }

    if (newPassword.length < 6) {
      _message(
        'Password must be at least 6 characters.',
      );
      return;
    }

    if (newPassword !=
        confirmPassword) {
      _message(
        'Passwords do not match.',
      );
      return;
    }

    final Session? session =
        Supabase.instance.client.auth
            .currentSession;

    if (session == null) {
      _message(
        'Your password reset session has expired. Please request a new reset link.',
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      debugPrint(
        'UPDATING PASSWORD...',
      );

      await Supabase.instance.client.auth
          .updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      debugPrint(
        'PASSWORD UPDATE SUCCESSFUL',
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color:
                      AppColors.primaryGreen,
                ),
                SizedBox(width: 10),
                Expanded(
                  child:
                      Text('Password changed'),
                ),
              ],
            ),
            content: const Text(
              'Your TrekCure password has been changed successfully. You can now log in with your new password.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      await Supabase.instance.client.auth
          .signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      debugPrint(
        'PASSWORD UPDATE AUTH ERROR: ${e.message}',
      );

      if (!mounted) return;

      _message(e.message);
    } catch (e) {
      debugPrint(
        'PASSWORD UPDATE ERROR: $e',
      );

      if (!mounted) return;

      _message(
        'Unable to change your password. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration:
            InputDecoration(
          labelText: label,
          prefixIcon:
              const Icon(
            Icons.lock_outline,
          ),
          suffixIcon:
              IconButton(
            icon: Icon(
              obscure
                  ? Icons
                      .visibility_off_outlined
                  : Icons
                      .visibility_outlined,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create New Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(24),
        children: [
          const SizedBox(
            height: 30,
          ),

          const CircleAvatar(
            radius: 38,
            backgroundColor:
                AppColors.lightGreenBg,
            child: Icon(
              Icons.lock_reset_rounded,
              size: 42,
              color:
                  AppColors.primaryGreen,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          const Text(
            'Create a new password',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          const Text(
            'Choose a new password for your TrekCure account.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.textGrey,
            ),
          ),

          const SizedBox(
            height: 30,
          ),

          _passwordField(
            controller:
                _newPasswordController,
            label:
                'New Password',
            obscure:
                _hideNewPassword,
            onToggle: () {
              setState(() {
                _hideNewPassword =
                    !_hideNewPassword;
              });
            },
          ),

          _passwordField(
            controller:
                _confirmPasswordController,
            label:
                'Confirm New Password',
            obscure:
                _hideConfirmPassword,
            onToggle: () {
              setState(() {
                _hideConfirmPassword =
                    !_hideConfirmPassword;
              });
            },
          ),

          const SizedBox(
            height: 10,
          ),

          const Text(
            'Password must contain at least 6 characters.',
            style: TextStyle(
              fontSize: 12,
              color:
                  AppColors.textGrey,
            ),
          ),

          const SizedBox(
            height: 22,
          ),

          SizedBox(
            width: double.infinity,
            height: 52,
            child:
                ElevatedButton(
              onPressed:
                  _loading
                      ? null
                      : _updatePassword,
              child:
                  _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Change Password',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}