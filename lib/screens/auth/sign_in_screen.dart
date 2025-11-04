import 'package:flutter/material.dart';
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
      await FirebaseService.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      // On success, FirebaseAuth state will update and the app will switch to main UI.
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    // Show a dialog to accept an email for password reset (user-friendly)
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final formKey = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset password'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? 'Enter email' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(context).pop(true);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (send != true) return;
    setState(() => _loading = true);
    try {
      await FirebaseService.sendPasswordResetEmail(emailCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent')));
    } catch (e) {
      setState(() => _error = 'Reset failed: $e');
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
                                      : const Text('Sign in', style: TextStyle(fontSize: 18)),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 16)),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                                    child: const Text('Create an account', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  ),
                                  TextButton(
                                    onPressed: _loading ? null : _forgotPassword,
                                    child: const Text('Forgot password?', style: TextStyle(color: Colors.white, fontSize: 16)),
                                  ),
                                ],
                              ),
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
