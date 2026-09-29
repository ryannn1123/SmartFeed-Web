import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _supabase = Supabase.instance.client;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // SmartFeed colors
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      debugPrint('====================================');
      debugPrint('SMARTFEED REGISTRATION');
      debugPrint('Email: $email');
      debugPrint('Sending registration request...');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      debugPrint('Registration request completed.');
      debugPrint('User ID: ${response.user?.id}');
      debugPrint('User Email: ${response.user?.email}');
      debugPrint('Session: ${response.session}');
      debugPrint('====================================');

      if (!mounted) return;

      // ========================================================
      // USER CREATED
      // ========================================================

      if (response.user != null) {
        // ------------------------------------------------------
        // Confirm Email is OFF
        // ------------------------------------------------------
        if (response.session != null) {
          _showMessage(
            'Account created successfully!',
            isError: false,
          );

          await Future.delayed(
            const Duration(milliseconds: 1000),
          );

          if (!mounted) return;

          // Sign out so the user can login normally.
          await _supabase.auth.signOut();

          if (!mounted) return;

          Navigator.pop(context);
        }

        // ------------------------------------------------------
        // Confirm Email is ON
        // ------------------------------------------------------
        else {
          _showMessage(
            'Account created. Please check your email to confirm your account.',
            isError: false,
          );

          await Future.delayed(
            const Duration(milliseconds: 1500),
          );

          if (!mounted) return;

          Navigator.pop(context);
        }
      }

      // ========================================================
      // NO USER RETURNED
      // ========================================================

      else {
        _showMessage(
          'Registration failed: Supabase did not return a user.',
          isError: true,
        );
      }
    }

    // ==========================================================
    // SUPABASE AUTH ERROR
    // ==========================================================

    on AuthException catch (e) {
      debugPrint('====================================');
      debugPrint('SUPABASE AUTH ERROR');
      debugPrint('Message: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');
      debugPrint('====================================');

      if (!mounted) return;

      _showMessage(
        e.message,
        isError: true,
      );
    }

    // ==========================================================
    // OTHER ERROR
    // ==========================================================

    catch (e) {
      debugPrint('====================================');
      debugPrint('REGISTRATION ERROR');
      debugPrint('$e');
      debugPrint('====================================');

      if (!mounted) return;

      _showMessage(
        'Something went wrong: $e',
        isError: true,
      );
    }

    // ==========================================================
    // STOP LOADING
    // ==========================================================

    finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? brownSoft : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: brownSoft,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      labelStyle: GoogleFonts.dmSans(
        color: brownSoft.withOpacity(0.8),
      ),
      hintStyle: GoogleFonts.dmSans(
        color: brown.withOpacity(0.35),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: blush.withOpacity(0.8),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: salmon,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 2,
        ),
      ),
      errorStyle: GoogleFonts.dmSans(
        color: Colors.redAccent,
        fontSize: 12,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Stack(
          children: [
            // ==================================================
            // DECORATIVE CIRCLE - TOP RIGHT
            // ==================================================

            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: peach.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ==================================================
            // DECORATIVE CIRCLE - BOTTOM LEFT
            // ==================================================

            Positioned(
              bottom: -100,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: blush.withOpacity(0.55),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // ==================================================
                        // BACK BUTTON
                        // ==================================================

                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed: _loading
                                ? null
                                : () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: brown,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ==================================================
                        // LOGO
                        // ==================================================

                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [salmon, peach],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: salmon.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.pets_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ==================================================
                        // TITLE
                        // ==================================================

                        Text(
                          'Create Account',
                          style: GoogleFonts.fraunces(
                            fontSize: 29,
                            fontWeight: FontWeight.w700,
                            color: brown,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Create your SmartFeed account',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: brown.withOpacity(0.65),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ==================================================
                        // EMAIL
                        // ==================================================

                        TextFormField(
                          controller: _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_loading,
                          style: GoogleFonts.dmSans(
                            color: brown,
                            fontSize: 15,
                          ),
                          decoration: _inputDecoration(
                            label: 'Email',
                            hint: 'Enter your email',
                            icon: Icons.email_outlined,
                          ),
                          validator: (value) {
                            final email =
                                value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Please enter your email';
                            }

                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );

                            if (!emailRegex.hasMatch(email)) {
                              return 'Please enter a valid email';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // PASSWORD
                        // ==================================================

                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction:
                              TextInputAction.next,
                          enabled: !_loading,
                          style: GoogleFonts.dmSans(
                            color: brown,
                            fontSize: 15,
                          ),
                          decoration: _inputDecoration(
                            label: 'Password',
                            hint: 'Create a password',
                            icon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons
                                        .visibility_off_outlined
                                    : Icons
                                        .visibility_outlined,
                                color: brownSoft,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password =
                                value ?? '';

                            if (password.isEmpty) {
                              return 'Please enter a password';
                            }

                            if (password.length < 6) {
                              return 'Password must be at least 6 characters';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // CONFIRM PASSWORD
                        // ==================================================

                        TextFormField(
                          controller:
                              _confirmPasswordController,
                          obscureText:
                              _obscureConfirmPassword,
                          textInputAction:
                              TextInputAction.done,
                          enabled: !_loading,
                          style: GoogleFonts.dmSans(
                            color: brown,
                            fontSize: 15,
                          ),
                          onFieldSubmitted: (_) {
                            if (!_loading) {
                              _register();
                            }
                          },
                          decoration: _inputDecoration(
                            label: 'Confirm Password',
                            hint: 'Re-enter your password',
                            icon:
                                Icons.lock_reset_outlined,
                            suffixIcon: IconButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons
                                        .visibility_off_outlined
                                    : Icons
                                        .visibility_outlined,
                                color: brownSoft,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Please confirm your password';
                            }

                            if (value !=
                                _passwordController.text) {
                              return 'Passwords do not match';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // PASSWORD INFO
                        // ==================================================

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Password must contain at least 6 characters.',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color:
                                  brown.withOpacity(0.55),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // REGISTER BUTTON
                        // ==================================================

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _loading
                                    ? [
                                        salmon.withOpacity(0.55),
                                        peach.withOpacity(0.55),
                                      ]
                                    : const [salmon, peach],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: salmon.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed:
                                  _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.transparent,
                                disabledBackgroundColor:
                                    Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      children: [
                                        const Icon(
                                          Icons
                                              .person_add_alt_1_rounded,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Create Account',
                                          style: GoogleFonts.dmSans(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // LOGIN
                        // ==================================================

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: GoogleFonts.dmSans(
                                color:
                                    brown.withOpacity(0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () =>
                                      Navigator.pop(context),
                              child: Text(
                                'Login',
                                style: GoogleFonts.dmSans(
                                  color: brownSoft,
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        // ==================================================
                        // SMARTFEED BRANDING
                        // ==================================================

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pets_rounded,
                              size: 16,
                              color:
                                  brown.withOpacity(0.4),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'SmartFeed',
                              style: GoogleFonts.dmSans(
                                color:
                                    brown.withOpacity(0.4),
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}