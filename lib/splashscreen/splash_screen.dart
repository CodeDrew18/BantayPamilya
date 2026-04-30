import 'package:another_flutter_splash_screen/another_flutter_splash_screen.dart';
import 'package:bantay_pamilya/auth/register_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FlutterSplashScreen.gif(
          backgroundColor: Color(0xFFF5F6F0),
          useImmersiveMode: true,
          gifPath: 'assets/splashscreen.gif',
          gifWidth: 900,
          gifHeight: 900,
          nextScreen: const RegisterScreen(),
          duration: const Duration(seconds: 7),
        ),
      ),
    );
  }
}
