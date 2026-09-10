import 'package:anitrack/features/auth/data/auth_repository_impl.dart';
import 'package:anitrack/features/auth/domain/app_user.dart';
import 'package:anitrack/features/auth/presentation/auth_provider.dart';
import 'package:anitrack/features/auth/presentation/biodata_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Auth & Biodata Persistence Tests', () {
    test('AppUser serialization correctly preserves birthDate', () {
      final date = DateTime(2001, 5, 20);
      final user = AppUser(
        id: 'u_101',
        email: 'user@test.com',
        username: 'OtakuUser',
        displayName: 'Otaku Sensei',
        avatarUrl: 'https://example.com/avatar.png',
        bio: 'Anime lover',
        birthDate: date,
      );

      final map = user.toMap();
      final restored = AppUser.fromMap(map);

      expect(restored.id, 'u_101');
      expect(restored.email, 'user@test.com');
      expect(restored.username, 'OtakuUser');
      expect(restored.birthDate, date);
      expect(restored.isAdult, true);
      expect(restored.needsBiodataSetup, false);
    });

    test('Registering with birthDate stores it immediately and bypasses biodata setup', () async {
      final repo = AuthRepositoryImpl();
      final birthDate = DateTime(1999, 8, 15);

      final user = await repo.registerWithEmail(
        username: 'NewOtaku',
        email: 'new_otaku@anilive.app',
        password: 'password123',
        birthDate: birthDate,
      );

      expect(user, isNotNull);
      expect(user?.birthDate, birthDate);
      expect(user?.needsBiodataSetup, false);
    });

    test('Logging in with existing email immediately resolves birthDate and never prompts biodata setup', () async {
      final repo = AuthRepositoryImpl();
      final birthDate = DateTime(1998, 12, 1);

      // Register first with birthDate
      await repo.registerWithEmail(
        username: 'ExistingUser',
        email: 'existing@anilive.app',
        password: 'password123',
        birthDate: birthDate,
      );

      // Logout
      await repo.logout();
      expect(repo.currentUser, isNull);

      // Login again with the same email
      final loggedInUser = await repo.loginWithEmail('existing@anilive.app', 'password123');
      expect(loggedInUser, isNotNull);
      expect(loggedInUser?.birthDate, birthDate);
      expect(loggedInUser?.needsBiodataSetup, false);

      // Verify persistent session can be restored by a brand new repository instance
      final reloadedRepo = AuthRepositoryImpl();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(reloadedRepo.currentUser?.birthDate, birthDate);
      expect(reloadedRepo.currentUser?.needsBiodataSetup, false);
    });

    testWidgets('BiodataScreen updates birthDate and triggers onComplete without stuck loading', (tester) async {
      bool onCompleteCalled = false;
      final repo = AuthRepositoryImpl();
      await repo.loginWithEmail('user@test.com', 'pass12345');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: BiodataScreen(
              userId: 'mock_uid_123',
              onComplete: () {
                onCompleteCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Hei, selamat datang! 👋'), findsOneWidget);
      expect(find.text('Simpan & Lanjutkan'), findsOneWidget);

      // Tap skip button
      await tester.tap(find.text('Lewati untuk sekarang'));
      await tester.pumpAndSettle();

      expect(onCompleteCalled, true);
      expect(repo.currentUser?.birthDate, isNotNull);
      expect(repo.currentUser?.needsBiodataSetup, false);
    });
  });
}
