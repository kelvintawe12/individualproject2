import 'dart:ui' as ui;
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

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  // ── Animations ───────────────────────────────────────────────────────
  late final AnimationController _logoCtrl;
  late final AnimationController _tagCtrl;
  late final AnimationController _cardCtrl;
  late final AnimationController _btnCtrl;
  late final AnimationController _bgCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _btnScale;
  late final Animation<Color?> _bgColor1;
  late final Animation<Color?> _bgColor2;

  @override
  void initState() {
    super.initState();

    // Logo (bookOpen.png)
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward();
    // Logo fade (tied to logo controller)
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    // Tagline fade
    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _tagFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _tagCtrl, curve: const Interval(0.3, 1, curve: Curves.easeOut)));

    // Form slide‑up
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut));

    // Button press
    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _btnScale = Tween<double>(begin: 1, end: 0.94).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    // Subtle animated gradient background
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _bgColor1 = ColorTween(begin: const Color(0xFF0A0E21), end: const Color(0xFF1A1F3A))
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));
    _bgColor2 = ColorTween(begin: const Color(0xFF1A1F3A), end: const Color(0xFF0A0E21))
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));

    // Staggered start (guarded to avoid calling controllers after dispose)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _tagCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _logoCtrl.dispose();
    _tagCtrl.dispose();
    _cardCtrl.dispose();
    _btnCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── Sign‑in ─────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _error = null;

    try {
      await FirebaseService.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) {
        final name = _emailCtrl.text.split('@').first;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome back, $name!')));
      }
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? e.code;
      if (kDebugMode) debugPrint('Sign‑in error: $msg');
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Forgot password ─────────────────────────────────────────────────────
  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _emailCtrl.text);
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetDialog(emailCtrl: ctrl, formKey: key),
    );
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await FirebaseService.sendPasswordResetEmail(ctrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset email sent!')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Reset failed');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_bgColor1.value!, _bgColor2.value!],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Subtle Lottie accent
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

                // Main column
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // ── Logo + Tagline ───────────────────────
                      FadeTransition(
                        opacity: _logoFade,
                        child: Column(
                          children: [
                            // **YOUR bookOpen.png**
                            Image.asset('assets/bookOpen.png', width: 110),
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

                      // ── Form Card ─────────────────────────────
                      SlideTransition(
                        position: _cardSlide,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.09),
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
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _glassInput('Email', Icons.email_outlined),
                                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Password
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscurePass,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: _glassInput('Password', Icons.lock_outline).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePass ? Icons.visibility_off : Icons.visibility,
                                            color: Colors.white70,
                                          ),
                                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                        ),
                                      ),
                                      validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 chars' : null,
                                    ),
                                    const SizedBox(height: 24),

                                    // Sign‑In Button
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
                                              : const Text('Sign In',
                                                  style: TextStyle(
                                                      fontSize: 18, fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ),

                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
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
                                          child: const Text('Create an account',
                                              style: TextStyle(color: Color(0xFFFED428))),
                                        ),
                                        TextButton(
                                          onPressed: _loading ? null : _forgotPassword,
                                          child: const Text('Forgot password?',
                                              style: TextStyle(color: Color(0xFFFED428))),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Glass input decoration ─────────────────────────────────────
  InputDecoration _glassInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFFED428), width: 2),
      ),
    );
  }
}

// ── Reset password dialog ─────────────────────────────────────
class _ResetDialog extends StatelessWidget {
  final TextEditingController emailCtrl;
  final GlobalKey<FormState> formKey;
  const _ResetDialog({required this.emailCtrl, required this.formKey});

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
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
          validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFED428)),
          onPressed: () => formKey.currentState!.validate() ? Navigator.of(context).pop(true) : null,
          child: const Text('Send', style: TextStyle(color: Colors.black87)),
        ),
      ],
    );
  }
}