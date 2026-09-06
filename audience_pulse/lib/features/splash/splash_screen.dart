import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

/// Animated splash screen shown on first app load.
/// Navigates automatically to [AppConstants.routeDashboard] (which redirects
/// to login if the user is not authenticated) after the animation completes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _progressController;
  late final AnimationController _pulseController;

  // ── Logo animations ──────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // ── Text animations ──────────────────────────────────────────────────────
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _taglineOpacity;

  // ── Progress bar ─────────────────────────────────────────────────────────
  late final Animation<double> _progressValue;

  // ── Pulse glow ───────────────────────────────────────────────────────────
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();

    // Logo: scales from 0.4 → 1.0 and fades in, duration 700ms
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Text: slides up from +20px and fades in, starts after 400ms
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Progress bar: sweeps 0→1 over 2.2s
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _progressValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Pulse glow behind the logo: repeats
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.25, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // 1. Logo pops in
    await _logoController.forward();

    // 2. Text slides up simultaneously with progress bar
    _textController.forward();
    _progressController.forward();

    // 3. Wait for progress to finish, then navigate
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      context.go(AppConstants.routeDashboard);
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Subtle radial gradient backdrop ──────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.08),
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),

          // ── Grid lines (decorative) ───────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // ── Center content ────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing glow + logo icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow ring
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseScale.value,
                        child: Opacity(
                          opacity: _pulseOpacity.value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accent
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Logo box
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (_, __) => FadeTransition(
                        opacity: _logoOpacity,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.accent,
                                  Color(0xFF5B21B6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accent.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // App name + tagline
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        // "AudiencePulse"
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFF2F2F7),
                              AppTheme.accentLight,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Audie',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Tagline fades in slightly later
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: const Text(
                            'AI-Powered Social Intelligence',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Progress bar at the bottom ────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (_, __) => LinearProgressIndicator(
                value: _progressValue.value,
                minHeight: 3,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentLight,
                ),
              ),
            ),
          ),

          // ── Version tag ───────────────────────────────────────────────────
          Positioned(
            bottom: 16,
            right: 20,
            child: FadeTransition(
              opacity: _textOpacity,
              child: const Text(
                'v1.0 · BETA',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a subtle dot-grid on the background for depth.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withValues(alpha: 0.4)
      ..strokeWidth = 1;

    const spacing = 40.0;
    const dotRadius = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
