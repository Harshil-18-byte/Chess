import 'package:firebase_auth/firebase_auth.dart';

/// Service managing user authentication sessions.
class FirebaseAuthService {
  final FirebaseAuth? auth;

  FirebaseAuthService({this.auth});

  FirebaseAuth? get _safeInstance {
    if (auth != null) return auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Stream of user authentication state changes.
  Stream<User?> get authStateChanges =>
      _safeInstance?.authStateChanges() ?? const Stream.empty();

  /// Current authenticated Firebase user.
  User? get currentUser {
    if (auth != null) return auth!.currentUser;
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Current user ID or empty string if not signed in.
  String get currentUid => currentUser?.uid ?? '';

  /// Signs in the user anonymously if not already signed in.
  Future<UserCredential?> signInAnonymously() async {
    final instance = _safeInstance;
    if (instance == null) return null;
    return await instance.signInAnonymously();
  }

  /// Signs in with email and password.
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final instance = _safeInstance;
    if (instance == null) return null;
    return await instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Registers a new account with email and password.
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final instance = _safeInstance;
    if (instance == null) return null;
    return await instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Updates the display name of the current user.
  Future<void> updateDisplayName(String name) async {
    if (currentUser != null) {
      await currentUser!.updateDisplayName(name);
      await currentUser!.reload();
    }
  }

  /// Signs out the current session.
  Future<void> signOut() async {
    final instance = _safeInstance;
    if (instance != null) {
      await instance.signOut();
    }
  }
}
