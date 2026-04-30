import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

final formKey = GlobalKey<FormState>();
final emailController = TextEditingController();
final passwordController = TextEditingController();
final confirmPasswordController = TextEditingController();

void registerUser(BuildContext context, String email, String password) async {
  try {
    await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    QuickAlert.show(
      context: context,
      type: QuickAlertType.success,
      title: 'Success',
      text: 'Your account has been created successfully',
    );
  } catch (e) {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.error,
      title: 'Error',
      text: e.toString(),
    );
  }
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _imageFade;
  late final Animation<Offset> _imageSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    final imageCurve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    final subtitleCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
    );
    final cardCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.9, curve: Curves.easeOutCubic),
    );
    final buttonCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
    );

    _imageFade = Tween<double>(begin: 0, end: 1).animate(imageCurve);
    _imageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(imageCurve);
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(subtitleCurve);
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(subtitleCurve);
    _cardFade = Tween<double>(begin: 0, end: 1).animate(cardCurve);
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(cardCurve);
    _buttonFade = Tween<double>(begin: 0, end: 1).animate(buttonCurve);
    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(buttonCurve);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandDark = Color(0xFF0E2A47);
    const brandGreen = Color(0xFF2E8B6B);
    const brandAccent = Color(0xFF1F6F8B);
    const brandMuted = Color(0xFF5A6B85);
    const inputFill = Color(0xFFF2F6FB);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF1F6FF), Color(0xFFE6F3EE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _imageFade,
                    child: SlideTransition(
                      position: _imageSlide,
                      child: SizedBox(
                        height: 500,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Positioned(
                              top: 24,
                              child: Container(
                                width: 260,
                                height: 260,
                                decoration: const BoxDecoration(
                                  color: Color(0x1A1F6F8B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/register.png',
                                height: 500,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const Text(
                              "Bantay Pamilya",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: brandDark,
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: const Text(
                        "Create your account to get started",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: brandMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x140F2A43)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0F2A43),
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: brandDark,
                                  ),
                                  labelText: 'Email',
                                  filled: true,
                                  fillColor: inputFill,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: brandAccent,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (EmailValidator.validate(value) == false) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: brandDark,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: brandMuted,
                                    ),
                                  ),
                                  labelText: 'Password',
                                  filled: true,
                                  fillColor: inputFill,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: brandAccent,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: brandDark,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: brandMuted,
                                    ),
                                  ),
                                  labelText: 'Confirm Password',
                                  filled: true,
                                  fillColor: inputFill,
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: brandAccent,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: _buttonFade,
                    child: SlideTransition(
                      position: _buttonSlide,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              registerUser(
                                context,
                                emailController.text,
                                passwordController.text,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGreen,
                            foregroundColor: Colors.white,
                            shadowColor: const Color(0x332E8B6B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
