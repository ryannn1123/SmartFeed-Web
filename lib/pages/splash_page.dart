import 'package:flutter/material.dart';
import '../main.dart';
import 'login_page.dart';
import 'home_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  late final AnimationController _floatController;
  late final Animation<double> _floatAnim;

  final List<_SplashData> _pages = const [
    _SplashData(
      title: 'Smart\nPet Care',
      subtitle: 'Keep your furry friend happy, healthy, and well-fed.',
      emoji: '🐱',
      icon: Icons.pets_rounded,
      bgColor: Color(0xFFFFF3E8),
      accentColor: Color(0xFFFF914D),
      gradientStart: Color(0xFFFFF8EF),
      gradientEnd: Color(0xFFFFD9B8),
    ),
    _SplashData(
      title: 'Auto\nFeeding',
      subtitle: 'Schedule meals, manage portions, and never miss feeding time.',
      emoji: '🥣',
      icon: Icons.restaurant_rounded,
      bgColor: Color(0xFFEFFFF4),
      accentColor: Color(0xFF4CAF7D),
      gradientStart: Color(0xFFF6FFF8),
      gradientEnd: Color(0xFFCFF2DA),
    ),
    _SplashData(
      title: 'Ask\nPetBot',
      subtitle: 'Get quick pet care tips for nutrition, habits, and wellness.',
      emoji: '🐾',
      icon: Icons.chat_bubble_rounded,
      bgColor: Color(0xFFEFF6FF),
      accentColor: Color(0xFF5B9DF5),
      gradientStart: Color(0xFFF6FAFF),
      gradientEnd: Color(0xFFCFE4FF),
    
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final session = supabase.auth.currentSession;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            session != null ? const HomePage() : const LoginPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 550),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _proceed();
    }
  }

  void _skip() {
    _proceed();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final data = _pages[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              data.gradientStart,
              data.bgColor,
              data.gradientEnd,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            
child: Stack(
  children: [
    ..._buildPetBubbles(size, data),

    // Page content
    PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
      },
      itemBuilder: (context, index) {
        return _SplashContent(
          data: _pages[index],
          size: size,
          floatAnim: _floatAnim,
        );
      },
    ),

    // TOP BAR - placed AFTER PageView so Skip receives taps
    Positioned(
      top: 18,
      left: 22,
      right: 22,
      child: _TopBar(
        accentColor: data.accentColor,
        onSkip: _skip,
      ),
    ),

    // Bottom card
    Positioned(
      left: 22,
      right: 22,
      bottom: 24,
      child: _BottomPetCard(
        data: data,
        currentPage: _currentPage,
        totalPages: _pages.length,
        onNext: _nextPage,
      ),
    ),
  ],
),


          ),
        ),
      ),
    );
  }

  List<Widget> _buildPetBubbles(Size size, _SplashData data) {
    return [
      _Bubble(
        top: size.height * 0.13,
        right: -42,
        size: 150,
        color: data.accentColor.withOpacity(0.13),
      ),
      _Bubble(
        top: size.height * 0.35,
        left: -55,
        size: 190,
        color: Colors.white.withOpacity(0.35),
      ),
      _Bubble(
        bottom: size.height * 0.28,
        right: 24,
        size: 88,
        color: data.accentColor.withOpacity(0.15),
      ),
      Positioned(
        top: size.height * 0.19, 
        left: 30,
        child: Icon(
          Icons.pets_rounded,
          color: data.accentColor.withOpacity(0.18),
          size: 42,
        ),
      ),
      Positioned(
        top: size.height * 0.47,
        right: 34,
        child: Icon(
          Icons.favorite_rounded,
          color: data.accentColor.withOpacity(0.16),
          size: 34,
        ),
      ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onSkip;

  const _TopBar({
    required this.accentColor,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.75)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.pets_rounded, color: accentColor, size: 22),
              const SizedBox(width: 8),
              const Text(
                'SmartFeed',
                style: TextStyle(
                  color: Color(0xFF201A2B),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onSkip,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF201A2B).withOpacity(0.62),
          ),
          child: const Text(
            'Skip',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  final _SplashData data;
  final Size size;
  final Animation<double> floatAnim;

  const _SplashContent({
    required this.data,
    required this.size,
    required this.floatAnim,
  });

  @override
  Widget build(BuildContext context) {
    final heroSize = size.width * 0.68;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.14),
          AnimatedBuilder(
            animation: floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, floatAnim.value),
                child: child,
              );
            },
            child: Container(
              width: heroSize,
              height: heroSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.48),
                border: Border.all(
                  color: Colors.white.withOpacity(0.85),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: data.accentColor.withOpacity(0.28),
                    blurRadius: 42,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: heroSize * 0.72,
                    height: heroSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: data.accentColor.withOpacity(0.14),
                    ),
                  ),
                  Text(
                    data.emoji,
                    style: TextStyle(
                      fontSize: size.height * 0.145,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 26,
                    bottom: 34,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: data.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: data.accentColor.withOpacity(0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        data.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  index.isEven ? Icons.pets_rounded : Icons.favorite_rounded,
                  color: data.accentColor.withOpacity(0.18 + index * 0.04),
                  size: 16 + index.toDouble(),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BottomPetCard extends StatelessWidget {
  final _SplashData data;
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  const _BottomPetCard({
    required this.data,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == totalPages - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.16),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              data.title,
              key: ValueKey(data.title),
              style: const TextStyle(
                fontSize: 43,
                height: 1.05,
                letterSpacing: -0.8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF201A2B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              data.subtitle,
              key: ValueKey(data.subtitle),
              style: TextStyle(
                fontSize: 16,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF201A2B).withOpacity(0.62),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Row(
            children: [
              Row(
                children: List.generate(totalPages, (index) {
                  final selected = index == currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.only(right: 8),
                    width: selected ? 30 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: selected
                          ? data.accentColor
                          : data.accentColor.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNext,
                  borderRadius: BorderRadius.circular(32),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          data.accentColor,
                          Color.lerp(data.accentColor, Colors.black, 0.18)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: data.accentColor.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 9),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLast
                              ? Icons.pets_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;

  const _Bubble({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _SplashData {
  final String title;
  final String subtitle;
  final String emoji;
  final IconData icon;
  final Color bgColor;
  final Color accentColor;
  final Color gradientStart;
  final Color gradientEnd;

  const _SplashData({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.icon,
    required this.bgColor,
    required this.accentColor,
    required this.gradientStart,
    required this.gradientEnd,
  });
}