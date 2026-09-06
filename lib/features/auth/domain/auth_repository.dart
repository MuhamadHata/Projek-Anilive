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
  AppUser? get currentUser;
}
