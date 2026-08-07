import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Widget reutilizable para mostrar imágenes con estados de carga, error y placeholder
class AppImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color backgroundColor;

  const AppImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor = AppColors.backgroundAlt,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostrar placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ?? _buildLoadingPlaceholder(),
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildErrorPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: (width != null && height != null)
              ? (width! < height! ? width! * 0.4 : height! * 0.4)
              : AppSpacing.iconLG,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: backgroundColor,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: (width != null && height != null)
              ? (width! < height! ? width! * 0.4 : height! * 0.4)
              : AppSpacing.iconLG,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

/// Variante circular para avatares
class AppCircleImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final Widget? placeholder;
  final Color backgroundColor;

  const AppCircleImage({
    super.key,
    this.imageUrl,
    this.size = AppSpacing.avatarMD,
    this.placeholder,
    this.backgroundColor = AppColors.backgroundAlt,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: size / 2,
      fit: BoxFit.cover,
      backgroundColor: backgroundColor,
      placeholder: placeholder,
    );
  }
}
