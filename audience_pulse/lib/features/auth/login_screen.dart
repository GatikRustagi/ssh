import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../services/supabase_service.dart';

/// Login screen with email/password and Google OAuth.
/// Minimal, dark-themed, single-screen auth flow.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  bool _isLoading  = false;
  bool _isSignUp   = false;
  bool _obscure    = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      if (_isSignUp) {
        await SupabaseService.instance.signUpWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Check your email to confirm your account.')),
          );
        }
      } else {
        await SupabaseService.instance.signInWithEmail(
          _emailCtrl.text.trim(), _passCtrl.text.trim(),
        );
        if (mounted) context.go(AppConstants.routeDashboard);
      }
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('AuthException: ', ''); });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await SupabaseService.instance.signInWithGoogle();
      // GoRouter redirect handles navigation after OAuth callback
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo / Branding ──────────────────────────────────────
                _buildLogo(),
                const SizedBox(height: 40),

                // ── Form Card ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isSignUp ? 'Create account' : 'Sign in',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSignUp
                              ? 'Start analyzing social intelligence'
                              : 'Welcome back to AudiencePulse',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),

                        // Email
                        TextFormField(
                          key: const Key('email_field'),
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined, size: 18),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          key: const Key('password_field'),
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined, size: 18),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'At least 6 characters' : null,
                        ),

                        // Error
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0x1AEF4444),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0x4DEF4444)),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Submit button
                        ElevatedButton(
                          key: const Key('submit_button'),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isSignUp ? 'Create Account' : 'Sign In'),
                        ),

                        const SizedBox(height: 16),

                        // Divider
                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or', style: Theme.of(context).textTheme.bodySmall),
                          ),
                          const Expanded(child: Divider()),
                        ]),

                        const SizedBox(height: 16),

                        // Google OAuth
                        OutlinedButton.icon(
                          key: const Key('google_signin_button'),
                          onPressed: _isLoading ? null : _googleSignIn,
                          icon: const Text('G', style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF4285F4),
                          )),
                          label: const Text('Continue with Google'),
                        ),

                        const SizedBox(height: 20),

                        // Toggle sign-in / sign-up
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isSignUp = !_isSignUp;
                                _error = null;
                              }),
                              child: Text(
                                _isSignUp ? 'Sign In' : 'Sign Up',
                                style: const TextStyle(
                                  color: AppTheme.accentLight,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentGlow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          'AudiencePulse',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI-Driven Social Media Intelligence',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
