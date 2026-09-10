import 'app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get onAuthStateChanged;
  Future<AppUser?> loginWithEmail(String email, String password);
  Future<AppUser?> registerWithEmail({
    required String username,
    required String email,
    required String password,
  });
  Future<AppUser?> loginWithGoogle();
  Future<void> logout();
  Future<void> resetPassword(String email);
  Future<void> updateBirthDate(DateTime birthDate);
  Future<void> updateProfile({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    DateTime? birthDate,
  });
  AppUser? get currentUser;
}
