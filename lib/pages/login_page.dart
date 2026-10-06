import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'home_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'terms_page.dart';

// =========================
// SHARED PALETTE
// =========================

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);
  static const Color honey = Color(0xFFE0A438);
  static const Color leaf = Color(0xFF6FAE7C);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _logoController;
  late final Animation<double> _logoAnim;
  late final AnimationController _pawController;
  late final AnimationController _floatController;
  late final AnimationController _sparkleController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;

  // Custom color palette
  static const Color primaryOrange = _Palette.peach;
  static const Color secondaryPeach = _Palette.blush;
  static const Color tertiaryCream = _Palette.cream;
  static const Color darkBrown = _Palette.brownSoft;
  static const Color deepBlue = _Palette.brown;

  @override
  void initState() {
    super.initState();

    // Listen for OAuth login such as Google
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        _onLoginSuccess();
      }
    });

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoAnim = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _pawController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _logoController.repeat(reverse: true);
    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _logoController.dispose();
    _pawController.dispose();
    _floatController.dispose();
    _sparkleController.dispose();
    _entranceController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOGIN SUCCESS
  // ============================================================

  Future<void> _onLoginSuccess() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final userId = currentUser.id;

      final existing = await supabase
          .from('servo')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('servo').insert({
          'user_id': userId,
          'angle': 0,
          'last_confirmed': 0,
        });
      }
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // ============================================================
  // EMAIL + PASSWORD LOGIN
  // ============================================================

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (response.session != null) {
        await _onLoginSuccess();
      } else {
        setState(() {
          _error = 'Login failed. Please check your email and password.';
        });
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = e.message;

      if (message.toLowerCase().contains('email not confirmed')) {
        message = 'Please verify your email address before logging in.';
      } else if (message.toLowerCase().contains('invalid login credentials')) {
        message = 'Incorrect email or password.';
      }

      setState(() => _error = message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // GOOGLE LOGIN
  // ============================================================

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'smartfeed://login-callback',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Google sign-in failed. Please try again.';
        _loading = false;
      });
    }
  }

  // ============================================================
  // FIELD DECORATION
  // ============================================================

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(
        color: _Palette.muted,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: GoogleFonts.dmSans(
        color: _Palette.salmon,
        fontWeight: FontWeight.w800,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 16,
      ),
      prefixIcon: Icon(icon, color: _Palette.salmon, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.95),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.9),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _Palette.salmon,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 380;
    final isShort = size.height < 690;

    final double gap = isShort ? 8 : 12;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _Palette.salmon,
              primaryOrange,
              secondaryPeach,
              tertiaryCream,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // ====================================================
            // DECORATIVE BLOBS
            // ====================================================

            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.cream.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ====================================================
            // FLOATING CIRCLES
            // ====================================================

            for (int i = 0; i < 6; i++)
              Positioned(
                top: [
                  size.height * 0.02,
                  size.height * 0.15,
                  size.height * 0.4,
                  size.height * 0.65,
                  size.height * 0.85,
                  size.height * 0.1,
                ][i],
                left: [
                  -30.0,
                  size.width * 0.82,
                  -20.0,
                  size.width * 0.88,
                  size.width * 0.15,
                  size.width * 0.65,
                ][i],
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(seconds: 5 + i * 2),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(
                        15 * math.sin(value * math.pi * 2 + i * 1.5),
                        20 * math.cos(value * math.pi * 2 + i * 1.5),
                      ),
                      child: Container(
                        width: [80.0, 120.0, 60.0, 140.0, 90.0, 70.0][i],
                        height: [80.0, 120.0, 60.0, 140.0, 90.0, 70.0][i],
                        decoration: BoxDecoration(
                          color: [
                            primaryOrange.withOpacity(0.15),
                            secondaryPeach.withOpacity(0.15),
                            tertiaryCream.withOpacity(0.2),
                            primaryOrange.withOpacity(0.1),
                            secondaryPeach.withOpacity(0.12),
                            tertiaryCream.withOpacity(0.18),
                          ][i],
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ====================================================
            // FLOATING PAW PRINTS
            // ====================================================

            for (int i = 0; i < 8; i++)
              Positioned(
                top: (i * 130.0 + 40) % size.height,
                left: i % 2 == 0 ? 15.0 : size.width - 45.0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(seconds: 3 + i % 3),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity:
                          0.15 + 0.1 * math.sin(value * math.pi * 2),
                      child: Transform.rotate(
                        angle: value * math.pi * 2 + i * 0.5,
                        child: Icon(
                          Icons.pets,
                          size: 30,
                          color: darkBrown.withOpacity(0.15),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // ====================================================
            // SPARKLES
            // ====================================================

            for (int i = 0; i < 5; i++)
              Positioned(
                top: [60.0, 200.0, 350.0, 500.0, 700.0][i],
                left: [40.0, 300.0, 50.0, 280.0, 100.0][i],
                child: RotationTransition(
                  turns: _sparkleController,
                  child: Icon(
                    Icons.star,
                    size: [12.0, 8.0, 10.0, 14.0, 9.0][i],
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),

            // ====================================================
            // MAIN CONTENT
            // ====================================================

            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ==================================================
                            // LOGO
                            // ==================================================

                            ScaleTransition(
                              scale: _logoAnim,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.97),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _Palette.salmon.withOpacity(0.4),
                                      blurRadius: 24,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 10),
                                    ),
                                    BoxShadow(
                                      color: _Palette.brownSoft.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/smartfeed_logo.png',
                                      height: isSmallScreen ? 34 : 42,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pets,
                                          size: 9,
                                          color: darkBrown.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "PREMIUM PET CARE",
                                          style: GoogleFonts.dmSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: darkBrown,
                                            letterSpacing: 1.8,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.pets,
                                          size: 9,
                                          color: darkBrown.withOpacity(0.7),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: gap + 4),

                            // ==================================================
                            // SUBTITLE
                            // ==================================================

                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 800),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 10 * (1 - value)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.7),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        "Your Smart Companion For Happy Pets",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.fraunces(
                                          fontSize: isSmallScreen ? 11.5 : 13,
                                          color: darkBrown,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: gap + 4),

                            // ==================================================
                            // FEATURES
                            // ==================================================

                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1000),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 15,
                                        sigmaY: 15,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.65),
                                          borderRadius:
                                              BorderRadius.circular(26),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.85),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _Palette.brownSoft
                                                  .withOpacity(0.1),
                                              blurRadius: 22,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                          // Kini upat ka picture sa una z
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              child: _PetFeatureBadge(
                                                icon: Icons.schedule_rounded,
                                                title: "Schedule",
                                                color: Color.fromARGB(255, 223, 62, 62),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: _PetFeatureBadge(
                                                icon: Icons.tune_rounded,
                                                title: "Feed Control",
                                                color: Color.fromARGB(255, 245, 130, 101),
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: _PetFeatureBadge(
                                                icon: Icons.smart_toy_rounded,
                                                title: "AI Assistant",
                                                color: _Palette.honey,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: _PetFeatureBadge(
                                                icon: Icons.camera_alt_rounded,
                                                title: "Watch Live",
                                                color: _Palette.leaf,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            SizedBox(height: gap + 6),

                            // ==================================================
                            // WELCOME BACK CARD (contains inputs)
                            // ==================================================

                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                18,
                                16,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _Palette.brownSoft.withOpacity(0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: _Palette.salmon.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.waving_hand_rounded,
                                          size: 14,
                                          color: _Palette.salmon,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Welcome Back!',
                                        style: GoogleFonts.fraunces(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          color: darkBrown,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // ==================================================
                                  // ERROR MESSAGE
                                  // ==================================================

                                  if (_error != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(11),
                                      margin: EdgeInsets.only(bottom: gap + 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.08),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.error_outline_rounded,
                                              color: Colors.red.shade400,
                                              size: 15,
                                            ),
                                          ),
                                          const SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: GoogleFonts.dmSans(
                                                color: Colors.red.shade700,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // ==================================================
                                  // EMAIL
                                  // ==================================================

                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    enabled: !_loading,
                                    style: GoogleFonts.dmSans(
                                      color: _Palette.brown,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Email',
                                      icon: Icons.email_outlined,
                                    ),
                                  ),

                                  SizedBox(height: gap),

                                  // ==================================================
                                  // PASSWORD
                                  // ==================================================

                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    //obscuringCharacter: 'R',
                                    textInputAction: TextInputAction.done,
                                    enabled: !_loading,
                                    onSubmitted: (_) {
                                      if (!_loading) _signInWithEmail();
                                    },
                                    style: GoogleFonts.dmSans(
                                      color: _Palette.brown,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Password',
                                      icon: Icons.lock_outline,
                                      suffix: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: _Palette.brownSoft,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ==================================================
                                  // FORGOT PASSWORD
                                  // ==================================================

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ForgotPasswordPage(),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: _Palette.salmon,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // ==================================================
                                  // EMAIL LOGIN BUTTON
                                  // ==================================================

                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            _Palette.salmon,
                                            _Palette.peach,
                                          ],
                                        ),
                                        boxShadow: _loading
                                            ? []
                                            : [
                                                BoxShadow(
                                                  color: _Palette.salmon
                                                      .withOpacity(0.45),
                                                  blurRadius: 18,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed:
                                            _loading ? null : _signInWithEmail,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          disabledBackgroundColor:
                                              Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(27),
                                          ),
                                        ),
                                        child: _loading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.6,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.pets,
                                                    size: 18,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Log In',
                                                    style:
                                                        GoogleFonts.dmSans(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: gap + 4),

                            // ==================================================
                            // OR DIVIDER
                            // ==================================================

                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.1),
                                          Colors.white.withOpacity(0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'OR',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: darkBrown.withOpacity(0.8),
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.2,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.8),
                                          Colors.white.withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: gap + 2),

                            // ==================================================
                            // GOOGLE
                            // ==================================================

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _signInWithGoogle,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: deepBlue,
                                  elevation: 4,
                                  shadowColor:
                                      const Color.fromARGB(255, 10, 2, 2).withOpacity(0.25),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.9),
                                      width: 1.2,
                                    ),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          color: _Palette.salmon,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.network(
                                            'https://developers.google.com/identity/images/g-logo.png',
                                            width: 22,
                                            height: 22,
                                            errorBuilder: (_, __, ___) {
                                              return SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CustomPaint(
                                                  painter:
                                                      _GoogleLogoPainter(),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Continue with Google',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: deepBlue,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // ==================================================
                            // CREATE ACCOUNT
                            // ==================================================

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: GoogleFonts.dmSans(
                                    color: darkBrown.withOpacity(0.8),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterPage(),
                                            ),
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Create Account',
                                    style: GoogleFonts.dmSans(
                                      color: darkBrown,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      decoration: TextDecoration.underline,
                                      decorationColor: darkBrown,
                                      decorationThickness: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // ==================================================
                            // TERMS
                            // ==================================================

                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 1600),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.favorite,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.75),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            style: GoogleFonts.dmSans(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  darkBrown.withOpacity(0.75),
                                              letterSpacing: 0.1,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'By continuing, you agree to our ',
                                              ),
                                              TextSpan(
                                                text: 'pet-friendly terms',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: darkBrown,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  letterSpacing: 0.1,
                                                ),
                                                recognizer:
                                                    TapGestureRecognizer()
                                                      ..onTap = () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                const TermsPage(),
                                                          ),
                                                        );
                                                      },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.favorite,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.75),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================
// Pet Feature Badge
// ================================================

class _PetFeatureBadge extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _PetFeatureBadge({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: _Palette.brown,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ================================================
// Google "G" Logo Painter
// ================================================

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final cx = w / 2;
    final cy = h / 2;

    final outerR = w / 2;
    final innerR = outerR * 0.6;
    final strokeW = outerR - innerR;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: (outerR + innerR) / 2,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 2.214, 2.670, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 1.571, 0.644, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, -0.524, 2.094, false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.571, 1.047, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        cx,
        cy - strokeW / 2,
        outerR - strokeW * 0.1,
        strokeW,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}