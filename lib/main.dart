import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'src/screens/auth/login_screen.dart';
import 'src/screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBJGl7s9UOqEI8b8rgBjmj_Wj-CaYkwvf8",
      authDomain: "upstyles-pro.firebaseapp.com",
      projectId: "upstyles-pro",
      storageBucket: "upstyles-pro.firebasestorage.app",
      messagingSenderId: "406281226815",
      appId: "1:406281226815:web:2c5aa0ab9d6e19d0e9c9d6",
    ),
  );

  runApp(const UpStylesAdminApp());
}

class UpStylesAdminApp extends StatelessWidget {
  const UpStylesAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Add providers here
      ],
      child: MaterialApp.router(
        title: 'UpStyles Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B4CE6),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
        ),
        routerConfig: _router,
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
