import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isTeacher => _currentUser?.isTeacher ?? false;

  // ── Sign In ──────────────────────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.cancelled();

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return AuthResult.error('Sign in failed');

      // Check if user exists in Firestore
      final doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      if (!doc.exists) {
        // First ever user = admin, rest = pending
        final isFirstUser = await _isFirstUser();
        final role = isFirstUser ? UserRole.admin : UserRole.pending;

        final newUser = AppUser(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName ?? '',
          email: firebaseUser.email ?? '',
          photoUrl: firebaseUser.photoURL ?? '',
          role: role,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap());

        _currentUser = newUser;
      } else {
        _currentUser = AppUser.fromMap(doc.data()!);
      }

      return AuthResult.success(_currentUser!);
    } catch (e) {
      return AuthResult.error(e.toString());
    }
  }

  Future<bool> _isFirstUser() async {
    final snapshot = await _firestore.collection('users').limit(1).get();
    return snapshot.docs.isEmpty;
  }

  // ── Reload current user from Firestore ───────────────────────────────────

  Future<void> reloadUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    final doc = await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (doc.exists) {
      _currentUser = AppUser.fromMap(doc.data()!);
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _currentUser = null;
  }

  // ── Stream for auth state changes ────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

// ── Result wrapper ───────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final AppUser? user;

  AuthResult._({
    required this.success,
    required this.cancelled,
    this.error,
    this.user,
  });

  factory AuthResult.success(AppUser user) =>
      AuthResult._(success: true, cancelled: false, user: user);

  factory AuthResult.cancelled() =>
      AuthResult._(success: false, cancelled: true);

  factory AuthResult.error(String message) =>
      AuthResult._(success: false, cancelled: false, error: message);
}