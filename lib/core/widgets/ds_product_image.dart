import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/api_constants.dart';
import '../theme/app_colors.dart';

/// Componente unificado de imagen de producto
/// Maneja: URL remota, caché, loading shimmer, error placeholder, productos sin imagen
class DSProductImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final String? productName; // Para el placeholder con inicial

  const DSProductImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
    this.productName,
  });

  /// Construye la URL completa si es relativa
  String? _buildUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    // URL relativa — prefijamos con la base del API sin /api
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api$'), '');
    return '$base/$url';
  }

  @override
  Widget build(BuildContext context) {
    final url = _buildUrl(imageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: fit,
                width: width,
                height: height,
                placeholder: (_, _) => _skeleton(context),
                errorWidget: (_, _, _) => _placeholder(context),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _skeleton(BuildContext context) => Container(
    color: context.colors.surfaceAlt,
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(context.colors.textTertiary),
        ),
      ),
    ),
  );

  Widget _placeholder(BuildContext context) {
    final name = productName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    // Color único por nombre del producto
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFF10B981),
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFF0EA5E9),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    final color = name.isNotEmpty
        ? colors[name.hashCode.abs() % colors.length]
        : AppColors.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 64 || constraints.maxHeight < 64;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: Center(
            child: compact
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_bar_rounded,
                        size: 32,
                        color: color.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Versión cuadrada para grids
class DSProductImageSquare extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double radius;
  final String? productName;

  const DSProductImageSquare({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.radius = 10,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    return DSProductImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      radius: radius,
      productName: productName,
    );
  }
}

/// Avatar de usuario con inicial
class DSUserAvatar extends StatelessWidget {
  final String username;
  final double size;

  const DSUserAvatar({super.key, required this.username, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.avatarColor(username);
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
