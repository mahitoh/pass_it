import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/models/user_model.dart';
import '../features/profile/data/user_repository.dart';

part 'profile_providers.g.dart';

@riverpod
UserRepository userRepository(Ref ref) {
  return UserRepository();
}

@riverpod
Future<UserModel> userProfile(Ref ref) {
  return ref.watch(userRepositoryProvider).fetchProfile();
}
