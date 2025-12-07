import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'src/screens/auth/login_screen.dart';
import 'src/screens/dashboard/dashboard_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDcK7J9zXTTg52W4t-BSEAMvuP2QEZqJ2s",
      authDomain: "upstyles-admin-pro.firebaseapp.com",
      projectId: "upstyles-admin-pro",
      storageBucket: "upstyles-admin-pro.firebasestorage.app",
      messagingSenderId: "438705648122",
      appId: "1:438705648122:web:d5e4b0392930ba17faf443",
    ),
  );

  runApp(const UpStylesAdminApp());
}

class UpStylesAdminApp extends StatelessWidget {
  const UpStylesAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'UpStyles Admin',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
  ],
);
