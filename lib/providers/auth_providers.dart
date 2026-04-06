import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/auth/data/auth_repository.dart';

part 'auth_providers.g.dart';

@riverpod
OfflineAuthRepository authRepository(Ref ref) {
  // Firebase auth (disabled for offline dev)
  // return AuthRepository(FirebaseAuth.instance);
  return OfflineAuthRepository();
}

@riverpod
Stream<User?> authStateChanges(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}
