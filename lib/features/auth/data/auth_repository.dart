import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

class OfflineAuthRepository {
  Stream<User?> authStateChanges() => const Stream.empty();
  User? get currentUser => null;

  Future<void> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}
