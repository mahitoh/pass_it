import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/animated_background.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _allowedDomains = const ['university.edu', 'passit.edu'];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _controller.forward();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBackground(
                colors: [AppColors.primary, Color(0xFF1B1B2F), Color(0xFF0F0E17)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.bookOpen, size: 64, color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        'Pass IT',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your campus knowledge, shared.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 48),
                      AnimatedLabelField(
                        controller: _emailController,
                        label: 'University Email',
                        icon: LucideIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AnimatedLabelField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: LucideIcons.lock,
                        obscureText: true,
                        validator: (value) => value == null || value.isEmpty ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isSubmitting || !_canSubmit ? null : _handleEmailSignIn,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Continue with University Email'),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(LucideIcons.globe, size: 18),
                        label: const Text('Sign in with Google'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.goNamed('dashboard'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          textStyle: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Skip for now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    final domain = value.split('@').last.toLowerCase();
    if (!_allowedDomains.contains(domain)) {
      return 'Use your university email';
    }
    return null;
  }

  bool get _canSubmit => _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  Future<void> _handleEmailSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    context.goNamed('dashboard');
  }
}

class AnimatedLabelField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AnimatedLabelField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  State<AnimatedLabelField> createState() => _AnimatedLabelFieldState();
}

class _AnimatedLabelFieldState extends State<AnimatedLabelField> {
  late FocusNode _focusNode;

  bool get _isActive => _focusNode.hasFocus || widget.controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.removeListener(_onChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 15 / 255),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            top: _isActive ? 4 : 18,
            left: 40,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: GoogleFonts.dmSans(
                fontSize: _isActive ? 11 : 14,
                fontWeight: FontWeight.w600,
                color: _isActive ? Colors.white60 : Colors.white38,
              ),
              child: Text(widget.label),
            ),
          ),
          TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            validator: widget.validator,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(left: 40, top: 20, bottom: 8, right: 12),
              prefixIcon: Icon(widget.icon, size: 18, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }
}
