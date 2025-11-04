import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseService.signUp(_emailCtrl.text.trim(), _passCtrl.text);
      // Send email verification if possible
      try {
        await FirebaseService.sendEmailVerification();
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Verify your email'),
              content: const Text('A verification email was sent. Please check your inbox and verify your email before continuing.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
          );
        }
      } catch (_) {
        // ignore verification send errors
      }
      // On success, pop back to sign in
      // create a minimal profile document so we can show names/avatars later
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final display = _emailCtrl.text.split('@').first;
          await FirebaseService.createUserProfile(user.uid, displayName: display);
        }
      } catch (_) {}
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('ui/ui3.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Semi-transparent overlay for readability
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Name
                        const Text(
                          'BookSwap',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                obscureText: true,
                                validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Create account', style: TextStyle(fontSize: 18)),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
