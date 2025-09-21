import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mechlink/firebase_options.dart';
import 'package:mechlink/screens/splash_screen.dart';
import 'package:mechlink/screens/login_screen.dart';
import 'package:mechlink/screens/dashboard_screen.dart';
import 'package:mechlink/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Setup FCM background message handling
  await FCMService.setupBackgroundMessageHandling();

  runApp(const MechLinkApp());
}

class MechLinkApp extends StatelessWidget {
  const MechLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MechLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },

      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }
}

/// App Configuration Class
/// This class contains app-wide configuration settings
class AppConfig {
  // Firebase settings
  static const bool useFirestoreEmulator = false;
  static const String firestoreEmulatorHost = 'localhost';
  static const int firestoreEmulatorPort = 8080;

  // Data loading settings
  static const int batchSize = 500; // Firestore batch limit
  static const Duration dataLoadingTimeout = Duration(minutes: 5);

  // Debug settings
  static const bool debugMode = true;

  /// Logs configuration info (for debugging)
  static void logConfiguration() {
    if (debugMode) {
      print('=== MechLink App Configuration ===');
      print('Debug Mode: $debugMode');
      print('Use Firestore Emulator: $useFirestoreEmulator');
      print('==================================');
    }
  }
}
