import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:talklynk_sdk/talklynk_sdk.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize TalkLynk SDK
  final sdk = await TalkLynkSDK.initialize(
    baseUrl: 'https://sdk.talklynk.com/backend',
    wsUrl: 'wss://ws.sdk.talklynk.com',
    apiKey: 'sk_pXoWTnw0QeqSpUHS19Jm6f9CToimZb7h',
    pusherAppKey: 'ed25e2b7fc96a889c7a8',
    enableLogs: true, // Enable for development
  );

  runApp(MyApp(sdk: sdk));
}

class MyApp extends StatelessWidget {
  final TalkLynkSDK sdk;

  const MyApp({Key? key, required this.sdk}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return sdk.wrapApp(
      MaterialApp(
        title: 'TalkLynk Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
