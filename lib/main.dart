import 'package:bantay_pamilya/firebase_options.dart';
import 'package:bantay_pamilya/screens/device_qr_screen.dart';
import 'package:bantay_pamilya/screens/dashboard_screen.dart';
import 'package:bantay_pamilya/screens/child_launcher_screen.dart';
import 'package:bantay_pamilya/screens/child_mode_screen.dart';
import 'package:bantay_pamilya/screens/map_screen.dart';
import 'package:bantay_pamilya/screens/parental_control_screen.dart';
import 'package:bantay_pamilya/screens/profile_management_screen.dart';
import 'package:bantay_pamilya/screens/qr_scan_screen.dart';
import 'package:bantay_pamilya/splashscreen/splash_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bantay_pamilya/auth/login_screen.dart';
import 'package:bantay_pamilya/auth/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Main());
}

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/map': (context) => const MapScreen(),
        '/scan': (context) => const QrScanScreen(),
        '/device-qr': (context) => const DeviceQrScreen(),
        '/profile': (context) => const ProfileManagementScreen(),
        '/parental-control': (context) => const ParentalControlScreen(),
        '/child-mode': (context) => const ChildModeScreen(),
        '/child-launcher': (context) => const ChildLauncherScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        return const SplashScreen();
      },
    );
  }
}
