import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/app_user.dart';
import 'login_screen.dart';
import 'pending_screen.dart';
import 'admin/admin_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import '../widgets/app_logo.dart';

/// Listens to Firebase auth state and routes to the correct screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Not logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Logged in — check role
        return _RoleRouter();
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    await AuthService().reloadUser();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

    final user = AuthService().currentUser;
    if (user == null) return const LoginScreen();

    switch (user.role) {
      case UserRole.admin:
        return const AdminHomeScreen();
      case UserRole.teacher:
        return const TeacherHomeScreen();
      case UserRole.pending:
        return const PendingScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF14532D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(size: 80),
            SizedBox(height: 16),
            Text(
              'SPTA Payment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}