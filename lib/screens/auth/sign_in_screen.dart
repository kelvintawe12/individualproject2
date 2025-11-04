import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import '../../services/firebase_service.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
 State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  // Animations
  late final AnimationController _logoCtrl;
  late final AnimationController _tagCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _btnCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward();

    // Logo fade (tied to logo controller)
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _tagFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _tagCtrl, curve: const Interval(0.3, 1, curve: Curves.easeOut)));

    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut));

    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _btnScale = Tween<double>(begin: 1, end: 0.94).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 200), () => _tagCtrl.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _cardCtrl.forward());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _logoCtrl.dispose();
    _tagCtrl.dispose();
    _cardCtrl.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  // Show a dialog with the raw FirebaseAuthException details to aid debugging.
  void _showRawFirebaseErrorDialog(FirebaseAuthException e) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Firebase error: ${e.code}'),
        content: SingleChildScrollView(
          child: SelectableText(e.message ?? e.toString()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    _error = null;

    try {
      await FirebaseService.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      // Success: let auth state listener handle navigation
    } on FirebaseAuthException catch (e, st) {
      final msg = e.message ?? e.code;
      if (kDebugMode) {
        debugPrint('Sign-in FirebaseAuthException: code=${e.code}, message=${e.message}');
        debugPrintStack(stackTrace: st);
      }
      _showRawFirebaseErrorDialog(e);
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final formKey = GlobalKey<FormState>();

    final send = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(emailCtrl: emailCtrl, formKey: formKey),
    );

    if (send != true) return;

    setState(() => _loading = true);
    try {
      await FirebaseService.sendPasswordResetEmail(emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Reset failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background Lottie
            Positioned(
              bottom: -80,
              right: -80,
              child: Opacity(
                opacity: 0.12,
                child: Lottie.network(
                  'https://assets4.lottiefiles.com/packages/lf20_jcikwtux.json',
                  width: 300,
                  controller: _logoCtrl,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                  const Spacer(flex: 2),

                  // Logo + Title
                  FadeTransition(
                    opacity: _logoFade,
                    child: Column(
                      children: [
                        // Local asset removed / missing — use a simple icon fallback
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: const Icon(Icons.book_outlined, size: 110, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'BookSwap',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  FadeTransition(
                    opacity: _tagFade,
                    child: const Text(
                      'Swap Your Books\nWith Other Students',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Form Card
                  SlideTransition(
                    position: _cardSlide,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isDark ? 0.09 : 0.13),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                                  ),
                                  validator: (v) => v?.isEmpty ?? true ? 'Enter your email' : null,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscurePass,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                                        color: Colors.white70,
                                      ),
                                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                    ),
                                  ),
                                  validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                                ),
                                const SizedBox(height: 24),

                                // Sign In Button
                                ScaleTransition(
                                  scale: _btnScale,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              _btnCtrl.forward().then((_) => _btnCtrl.reverse());
                                              _submit();
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFED428),
                                        foregroundColor: Colors.black87,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: Colors.black54,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.redAccent),
                                    textAlign: TextAlign.center,
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Links
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                                      ),
                                      child: const Text(
                                        'Create an account',
                                        style: TextStyle(color: Color(0xFFFED428), fontSize: 15),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _loading ? null : _forgotPassword,
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(color: Color(0xFFFED428), fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                      ],
                    ), // Column
                  ), // IntrinsicHeight
                ), // ConstrainedBox
              ), // SingleChildScrollView
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Reset Password Dialog ─────────────────────────────────────
class _ResetPasswordDialog extends StatelessWidget {
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;

  const _ResetPasswordDialog({required this.emailCtrl, required this.formKey});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Reset Password'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) => v?.isEmpty ?? true ? 'Enter email' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFED428)),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Send', style: TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }
}