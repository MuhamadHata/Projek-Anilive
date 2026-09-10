import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'package:anitrack/core/theme/app_tokens.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  DateTime? _selectedBirthDate;
  bool _isRegister = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ??
          DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: DateTime(now.year - 5),
      helpText: 'Pilih tanggal lahir kamu',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.textOnAccent,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  String _getReadableErrorMessage(Object? error) {
    if (error == null) return 'Terjadi kesalahan tidak dikenal.';
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        return 'Email atau password salah.';
      }
      if (msg.contains('already registered') ||
          msg.contains('user already exists')) {
        return 'Email ini sudah terdaftar. Silakan masuk.';
      }
      if (msg.contains('weak') ||
          msg.contains('at least 6') ||
          msg.contains('at least 8')) {
        return 'Password terlalu lemah (minimal 8 karakter).';
      }
      return error.message;
    }
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final msg = (error.message ?? '').toLowerCase();
      if (code == 'sign_in_canceled' || msg.contains('cancel')) {
        return 'Masuk dengan Google dibatalkan.';
      }
      if (code == 'sign_in_failed' ||
          msg.contains('10') ||
          msg.contains('12500')) {
        return 'Masuk dengan Google gagal: periksa konfigurasi Google Cloud Console.';
      }
      if (code == 'network_error') {
        return 'Koneksi jaringan bermasalah saat menghubungkan ke Google.';
      }
      return 'Gagal masuk Google: ${error.message ?? error.code}';
    }
    final str = error.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length);
    }
    return str;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (_isRegister) {
      ref
          .read(authNotifierProvider.notifier)
          .register(
            username,
            email,
            password,
            birthDate: _selectedBirthDate,
          );
    } else {
      ref.read(authNotifierProvider.notifier).login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AsyncValue<dynamic>>(authNotifierProvider, (previous, next) {
      if (next is AsyncError) {
        final message = _getReadableErrorMessage(next.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            backgroundColor: AppColors.surfaceAlt,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/anilive_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.live_tv,
                          size: 64,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'Anilive',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isRegister
                        ? 'Buat akun barumu'
                        : 'Masuk untuk bergabung komunitas',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMuted,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Username wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email wajib diisi';
                      if (!v.contains('@')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Password minimal 8 karakter'
                        : null,
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: AppSpacing.lg),
                    GestureDetector(
                      onTap: _pickBirthDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: _selectedBirthDate != null
                                ? AppColors.accent
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              size: AppIconSize.md,
                              color: _selectedBirthDate != null
                                  ? AppColors.accent
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tanggal Lahir (Disimpan saat akun dibuat)',
                                    style: AppTypography.micro.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _selectedBirthDate == null
                                        ? 'Ketuk untuk memilih tanggal lahir'
                                        : '${_selectedBirthDate!.day.toString().padLeft(2, '0')} / ${_selectedBirthDate!.month.toString().padLeft(2, '0')} / ${_selectedBirthDate!.year}',
                                    style: _selectedBirthDate == null
                                        ? AppTypography.bodyMuted
                                        : AppTypography.bodyStrong,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: AppIconSize.sm,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.textOnAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(_isRegister ? 'Daftar' : 'Masuk'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref
                            .read(authNotifierProvider.notifier)
                            .loginGoogle(),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Masuk dengan Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Masuk di sini'
                          : 'Belum punya akun? Daftar gratis',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.dangerBright,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
