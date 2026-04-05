import '../../../core/models/user_model.dart';

class UserRepository {
  Future<UserModel> fetchProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return const UserModel(
      uid: 'demo-user',
      email: 'scholar@university.edu',
      displayName: 'Jordan Scholar',
      university: 'Pass IT University',
      scholarPoints: 1240,
      rank: 12,
      photoUrl: null,
      bookmarkedPapers: [],
      uploadedPapers: [],
    );
  }
}
