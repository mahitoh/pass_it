import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_config.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _statusMessage;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const Map<String, String> _institutionByDomain = {
    'ubuea.cm': 'University of Buea',
    'uy1.uninet.cm': 'University of Yaounde I',
    'univ-douala.com': 'University of Douala',
    'univ-dschang.org': 'University of Dschang',
    'univ-bamenda.org': 'University of Bamenda',
    'enspy-yaounde.cm': 'ENSP Yaounde',
    'polytechnique.cm': 'Polytech Yaounde',
    'ictuniversity.org': 'ICT University',
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
      _statusMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
        _statusMessage = null;
      });

      final client = Supabase.instance.client;
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      try {
        if (_isLogin) {
          await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } else {
          final fullName = _fullNameController.text.trim();
          await client.auth.signUp(
            email: email,
            password: password,
            emailRedirectTo: supabaseEmailRedirectTo,
            data: {
              'full_name': fullName,
              'institution': _inferInstitution(email),
              'user_type': 'student',
            },
          );

          setState(() {
            _statusMessage =
                'Account created. If email confirmation is enabled, check your inbox first.';
          });
        }
      } on AuthException catch (error) {
        setState(() {
          _statusMessage = error.message;
        });
      } catch (error) {
        setState(() {
          _statusMessage = 'Authentication failed: $error';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() {
        _statusMessage = 'Enter a valid email first, then tap Forgot Password.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseEmailRedirectTo,
      );
      setState(() {
        _statusMessage = 'Password reset link sent to $email';
      });
    } on AuthException catch (error) {
      setState(() {
        _statusMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Could not send reset email: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _inferInstitution(String email) {
    final domain = email.contains('@') ? email.split('@').last : '';
    if (_institutionByDomain.containsKey(domain)) {
      return _institutionByDomain[domain];
    }

    if (domain.endsWith('.edu') ||
        domain.endsWith('.ac') ||
        domain.endsWith('.edu.cm')) {
      return domain;
    }

    return null;
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 80,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Logo & Header
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: 80,
                              height: 80,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isLogin ? 'Welcome back' : 'Create an account',
                              style: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Enter your details to access your past papers.'
                                  : 'Join the community of top achieving students.',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _statusMessage!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color:
                                      _statusMessage!.toLowerCase().contains(
                                            'sent',
                                          ) ||
                                          _statusMessage!
                                              .toLowerCase()
                                              .contains('created')
                                      ? Colors.green
                                      : cs.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Form
                      Expanded(
                        flex: 3,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isLogin) ...[
                                _AuthTextField(
                                  label: 'Full Name',
                                  hint: 'John Doe',
                                  icon: Icons.person_outline_rounded,
                                  controller: _fullNameController,
                                  validator: (value) {
                                    if (_isLogin) {
                                      return null;
                                    }

                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your full name';
                                    }

                                    if (value.trim().length < 2) {
                                      return 'Name is too short';
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                              _AuthTextField(
                                label: 'Email',
                                hint: 'john@student.edu',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                controller: _emailController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email';
                                  }

                                  if (!_isValidEmail(value.trim())) {
                                    return 'Please enter a valid email address';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _AuthTextField(
                                label: 'Password',
                                hint: '••••••••',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                controller: _passwordController,
                                onTogglePassword: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }

                                  if (!_isLogin && value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }

                                  return null;
                                },
                              ),
                              if (_isLogin) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : _forgotPassword,
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.primary,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    _isSubmitting
                                        ? 'Please wait...'
                                        : (_isLogin ? 'Log In' : 'Sign Up'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isLogin
                                      ? "Don't have an account? "
                                      : "Already have an account? ",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _toggleAuthMode,
                                  child: Text(
                                    _isLogin ? 'Sign Up' : 'Log In',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
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
            );
          },
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onTogglePassword;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;

  const _AuthTextField({
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.obscureText = false,
    this.onTogglePassword,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(fontSize: 15, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: cs.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
          validator:
              validator ??
              (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your $label';
                }
                return null;
              },
        ),
      ],
    );
  }
}
