import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final username = user?.username ?? '';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                120,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile card
                  AppCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppColors.avatarColor(username),
                              child: Text(
                                FormatUtils.initials(username),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: AppTextStyles.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  RoleBadge(role: user?.rol ?? ''),
                                  if (user?.sede != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.store_rounded,
                                          size: 12,
                                          color: context.colors.textTertiary,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            user!.sedeName,
                                            style: AppTextStyles.labelSmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _QuickAction(
                              icon: Icons.lock_reset_rounded,
                              label: 'Cambiar\ncontrasena',
                              onTap: () => context.push(
                                '/cambiar-password?forced=false',
                              ),
                            ),
                            _QuickAction(
                              icon: Icons.logout_rounded,
                              label: 'Cerrar\nsesion',
                              color: AppColors.error,
                              onTap: () => _logout(context, ref),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account info
                  _SectionHeader(title: 'Informacion de cuenta'),
                  const SizedBox(height: 8),
                  AppCard(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Usuario', value: username),
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Rol',
                          value: FormatUtils.roleName(user?.rol ?? ''),
                        ),
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Sede',
                          value: user?.sede == null
                              ? 'Todas las sedes'
                              : user!.sedeName,
                        ),
                        if (user?.createdAt != null &&
                            user!.createdAt.isNotEmpty) ...[
                          const Divider(height: 1),
                          _InfoRow(
                            label: 'Miembro desde',
                            value: user.createdAt.substring(0, 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Branding (solo SUPERADMIN)
                  if (user?.isSuperAdmin == true) ...[
                    _SectionHeader(title: 'Personalización del sistema'),
                    const SizedBox(height: 8),
                    const _BrandingSection(),
                    const SizedBox(height: 20),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Cerrar sesion',
      description: 'Se cerrara tu sesion actual.',
      confirmLabel: 'Cerrar sesion',
      isDanger: true,
    );
    if (ok && context.mounted) await ref.read(authProvider.notifier).logout();
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: c, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      title.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        letterSpacing: 0.8,
        color: context.colors.textTertiary,
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Branding section (SUPERADMIN only) ──────────────────────────────────────

class _BrandingSection extends ConsumerWidget {
  const _BrandingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingProvider);

    return AppCard(
      child: Column(
        children: [
          _BrandingItem(
            label: 'Logo del sistema',
            description: 'JPEG/PNG/WebP · máx. 5 MB',
            icon: Icons.image_rounded,
            imageUrl: branding.logoUrl,
            mutating: branding.mutating,
            onPick: (bytes, filename) async {
              await ref
                  .read(brandingProvider.notifier)
                  .setLogo(bytes, filename);
              if (context.mounted)
                AppFeedback.success(context, 'Logo actualizado');
            },
            onRemove: () async {
              await ref.read(brandingProvider.notifier).removeLogo();
              if (context.mounted)
                AppFeedback.success(context, 'Logo restaurado al original');
            },
          ),
          const Divider(height: 24),
          _BrandingItem(
            label: 'Portada del login',
            description: 'JPEG/PNG/WebP · máx. 5 MB',
            icon: Icons.wallpaper_rounded,
            imageUrl: branding.coverUrl,
            mutating: branding.mutating,
            onPick: (bytes, filename) async {
              await ref
                  .read(brandingProvider.notifier)
                  .setCover(bytes, filename);
              if (context.mounted)
                AppFeedback.success(context, 'Portada actualizada');
            },
            onRemove: () async {
              await ref.read(brandingProvider.notifier).removeCover();
              if (context.mounted)
                AppFeedback.success(context, 'Portada restaurada al original');
            },
          ),
        ],
      ),
    );
  }
}

class _BrandingItem extends StatefulWidget {
  final String label;
  final String description;
  final IconData icon;
  final String? imageUrl;
  final bool mutating;
  // bytes + filename → the backend needs multipart with a real filename
  final Future<void> Function(Uint8List bytes, String filename) onPick;
  final Future<void> Function() onRemove;

  const _BrandingItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.imageUrl,
    required this.mutating,
    required this.onPick,
    required this.onRemove,
  });

  @override
  State<_BrandingItem> createState() => _BrandingItemState();
}

class _BrandingItemState extends State<_BrandingItem> {
  static const _maxBytes = 5 * 1024 * 1024; // 5 MB

  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      if (file.bytes!.length > _maxBytes) {
        if (mounted)
          AppFeedback.error(context, 'Archivo demasiado grande (máx. 5 MB)');
        return;
      }
      final filename = file.name.isNotEmpty ? file.name : 'image.jpg';
      await widget.onPick(file.bytes!, filename);
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error: $e');
    }
  }

  Future<void> _remove() async {
    try {
      await widget.onRemove();
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = widget.imageUrl != null;
    final loading = widget.mutating;

    return Row(
      children: [
        // Preview
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: context.colors.backgroundAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.borderLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasCustom
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    widget.icon,
                    color: context.colors.textTertiary,
                    size: 26,
                  ),
                )
              : Icon(widget.icon, color: context.colors.textTertiary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              Text(widget.description, style: AppTextStyles.labelSmall),
              if (hasCustom)
                Text(
                  'Personalizado',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Column(
            children: [
              GestureDetector(
                onTap: _pick,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.colors.primaryBorder),
                  ),
                  child: const Text(
                    'Cambiar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              if (hasCustom) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _remove,
                  child: Text(
                    'Restaurar',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.error,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
