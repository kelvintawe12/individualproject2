import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../services/firebase_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePass = true;

  // ── Animations ────────────────────────────────────────────────────────
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

    // Logo (Lottie) – plays once
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward();

    // Logo fade (tied to logo controller)
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut),
    );

    // Tagline fade‑in
    _tagCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _tagFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _tagCtrl, curve: const Interval(0.3, 1, curve: Curves.easeOut)));

    // Card slide‑up + fade
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut));

    // Button press scale
    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _btnScale = Tween<double>(begin: 1, end: 0.94).animate(
        CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    // Staggered start
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

  // ── Sign‑up logic ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    _error = null;

    try {
      await FirebaseService.signUp(_emailCtrl.text.trim(), _passCtrl.text);

      // Email verification
      try {
        await FirebaseService.sendEmailVerification();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => const _VerificationDialog(),
        );
      } catch (_) {}

      // Minimal profile
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final display = _emailCtrl.text.split('@').first;
        await FirebaseService.createUserProfile(user.uid, displayName: display);
      }

      if (!mounted) return;
  // Success animation (show briefly) then close
  await Future.delayed(const Duration(milliseconds: 300));
  Navigator.of(context).pop();
    } on FirebaseAuthException catch (e, st) {
      if (kDebugMode) {
        debugPrint('FirebaseAuthException during sign-up: code=${e.code}, message=${e.message}');
        debugPrintStack(stackTrace: st);
      }
      _showRawFirebaseErrorDialog(e);
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // same deep navy as the screenshot
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background Lottie (subtle) ───────────────────────────────
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

            // ── Main column ───────────────────────────────────────────────
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

                  // ── Logo + Tagline ───────────────────────────────────────
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

                  // ── Form Card ───────────────────────────────────────────────
                  SlideTransition(
                    position: _cardSlide,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                                  validator: (v) =>
                                      (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                                ),
                                const SizedBox(height: 24),

                                // Submit button
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
                                        backgroundColor: const Color(0xFFFED428), // exact yellow
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
                                              'Create account',
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Bottom “Sign In” link (same style as screenshot) ───────
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Color(0xFFFED428),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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

// ── Verification dialog (re‑usable) ─────────────────────────────────────
class _VerificationDialog extends StatelessWidget {
  const _VerificationDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Verify your email'),
      content: const Text(
          'A verification email was sent. Please check your inbox and verify before continuing.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK', style: TextStyle(color: Color(0xFFFED428))),
        ),
      ],
    );
  }
}