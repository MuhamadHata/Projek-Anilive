import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anitrack/core/theme/app_tokens.dart';
import '../../../core/services/supabase_service.dart';

/// Bottom sheet yang muncul setelah login jika user belum mengisi tanggal lahir.
/// Setelah disimpan, data ditulis ke profiles dan AppUser diperbarui.
class BiodataScreen extends ConsumerStatefulWidget {
  final String userId;
  final VoidCallback onComplete;

  const BiodataScreen({
    super.key,
    required this.userId,
    required this.onComplete,
  });

  @override
  ConsumerState<BiodataScreen> createState() => _BiodataScreenState();
}

class _BiodataScreenState extends ConsumerState<BiodataScreen> {
  DateTime? _selectedDate;
  bool _loading = false;
  String? _error;

  int get _age {
    if (_selectedDate == null) return 0;
    return DateTime.now().difference(_selectedDate!).inDays ~/ 365;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
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
        _selectedDate = picked;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_selectedDate == null) {
      setState(() => _error = 'Pilih tanggal lahir dulu ya.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        await SupabaseService.client!
            .from('profiles')
            .update({
          'birth_date': _selectedDate!.toIso8601String().split('T').first,
        }).eq('id', widget.userId);
      }
      widget.onComplete();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Gagal menyimpan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppSpacing.xl * 2),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      // Header
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: const Icon(
                          Icons.cake_outlined,
                          size: 40,
                          color: AppColors.textOnAccent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Hei, selamat datang! 👋', style: AppTypography.display),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Sebelum mulai, lengkapi satu info penting agar kami bisa menyaring konten yang sesuai untukmu.',
                        style: AppTypography.body.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Date picker card
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: _selectedDate != null
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: _selectedDate != null
                                    ? AppColors.accent
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  _selectedDate == null
                                      ? 'Ketuk untuk pilih tanggal lahir'
                                      : _formatDate(_selectedDate!),
                                  style: _selectedDate == null
                                      ? AppTypography.bodyMuted
                                      : AppTypography.bodyStrong,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: AppIconSize.xs, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      ),

                      if (_selectedDate != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: _age >= 20
                                ? AppColors.success.withAlpha(20)
                                : AppColors.warning.withAlpha(20),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _age >= 20
                                  ? AppColors.success.withAlpha(80)
                                  : AppColors.warning.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _age >= 20 ? Icons.check_circle : Icons.info_outline,
                                size: AppIconSize.sm,
                                color: _age >= 20 ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  _age >= 20
                                      ? 'Usia $_age tahun · Akses penuh (termasuk 20+)'
                                      : 'Usia $_age tahun · Konten 20+ tidak tersedia',
                                  style: AppTypography.caption.copyWith(
                                    color: _age >= 20 ? AppColors.success : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _error!,
                          style: AppTypography.caption.copyWith(color: AppColors.dangerBright),
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),

                      // Tombol simpan
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.textOnAccent,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.textOnAccent,
                                  ),
                                )
                              : Text(
                                  'Simpan & Lanjutkan',
                                  style: AppTypography.bodyStrong.copyWith(
                                    color: AppColors.textOnAccent,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Skip option
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _loading ? null : widget.onComplete,
                          child: Text(
                            'Lewati untuk sekarang',
                            style: AppTypography.bodyMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
}
