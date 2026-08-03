import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action, leading;
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.leading,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      0,
    ),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTextStyles.bodyMedium),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class AppPagination extends StatelessWidget {
  final int page, totalPages, total;
  final ValueChanged<int> onPageChange;
  const AppPagination({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPageChange,
  });
  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '$total resultado${total != 1 ? "s" : ""}',
            style: AppTextStyles.bodySmall,
          ),
          const Spacer(),
          _PBtn(
            icon: Icons.chevron_left_rounded,
            enabled: page > 1,
            onTap: () => onPageChange(page - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$page / $totalPages',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _PBtn(
            icon: Icons.chevron_right_rounded,
            enabled: page < totalPages,
            onTap: () => onPageChange(page + 1),
          ),
        ],
      ),
    );
  }
}

class _PBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PBtn({required this.icon, required this.enabled, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: enabled ? AppColors.primarySurface : AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: enabled ? AppColors.primaryBorder : AppColors.border,
      ),
    ),
    child: IconButton(
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 18,
        color: enabled ? AppColors.primary : AppColors.textTertiary,
      ),
      onPressed: enabled ? onTap : null,
    ),
  );
}

class AppSearchBar extends StatelessWidget {
  final String? hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const AppSearchBar({
    super.key,
    this.hint,
    required this.onChanged,
    this.controller,
  });
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: AppTextStyles.bodyMedium,
    decoration: InputDecoration(
      hintText: hint ?? 'Buscar...',
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textTertiary,
        size: 20,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
