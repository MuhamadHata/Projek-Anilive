import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/auth_provider.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.dark_mode, color: AppColors.accent),
              title: const Text('Tema'),
              subtitle: const Text('Anilive menggunakan tema gelap'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.security, color: AppColors.accent),
              title: const Text('Kebijakan Privasi & Komunitas'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text('Tentang Anilive'),
              subtitle: const Text('v1.0.0'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Anilive',
                  applicationVersion: 'v1.0.0',
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Image.asset(
                      'assets/images/anilive_logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.live_tv,
                        size: 48,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  children: const [
                    Text('Aplikasi review dan komunitas anime modern.'),
                  ],
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.dangerBright),
              title: Text(
                'Keluar Akun',
                style: AppTypography.body.copyWith(color: AppColors.dangerBright),
              ),
              onTap: () async {
                await ref.read(authNotifierProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
