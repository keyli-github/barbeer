import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Feedback visual centrado con fondo opaco — reemplaza todos los SnackBar.
///
/// Uso:
///   AppFeedback.success(context, 'Venta registrada');
///   AppFeedback.error(context, 'No se pudo guardar');
class AppFeedback {
  AppFeedback._();

  static void success(
    BuildContext context,
    String message, {
    String? description,
  }) {
    HapticFeedback.mediumImpact();
    _show(
      context,
      message: message,
      description: description,
      type: _FType.success,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? description,
  }) {
    HapticFeedback.heavyImpact();
    _show(
      context,
      message: message,
      description: description,
      type: _FType.error,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    String? description,
    required _FType type,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FeedbackOverlay(
        message: message,
        description: description,
        type: type,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

enum _FType { success, error }

// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackOverlay extends StatefulWidget {
  final String message;
  final String? description;
  final _FType type;
  final VoidCallback onDone;

  const _FeedbackOverlay({
    required this.message,
    required this.type,
    required this.onDone,
    this.description,
  });

  @override
  State<_FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<_FeedbackOverlay>
    with TickerProviderStateMixin {
  // Controlador principal: backdrop + tarjeta
  late AnimationController _ctrl;
  late Animation<double> _backdropOpacity;
  late Animation<double> _cardScale;
  late Animation<double> _cardOpacity;

  // Controlador para el halo pulsante (se dispara una sola vez)
  late AnimationController _haloCtrl;
  late Animation<double> _haloScale;
  late Animation<double> _haloOpacity;

  // Controlador para dibujar el stroke del icono
  late AnimationController _strokeCtrl;
  late Animation<double> _stroke;
  Timer? _haloTimer;
  Timer? _strokeTimer;
  Timer? _dismissTimer;

  static const _inMs = Duration(milliseconds: 500);
  static const _holdMs = Duration(milliseconds: 1600);
  static const _outMs = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();

    // ── Entrada / salida ──────────────────────────────────────────────────
    _ctrl = AnimationController(vsync: this, duration: _inMs);

    _backdropOpacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _cardScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.10), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 0.97), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.00), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _cardOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _ctrl.forward();

    // ── Halo ──────────────────────────────────────────────────────────────
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _haloScale = Tween<double>(
      begin: 1.0,
      end: 2.1,
    ).animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeOut));
    _haloOpacity = Tween<double>(
      begin: 0.55,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeIn));

    _haloTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _haloCtrl.forward();
    });

    // ── Stroke del icono ──────────────────────────────────────────────────
    _strokeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _stroke = CurvedAnimation(parent: _strokeCtrl, curve: Curves.easeOut);
    _strokeTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _strokeCtrl.forward();
    });

    // ── Salida ────────────────────────────────────────────────────────────
    _dismissTimer = Timer(_holdMs, () {
      if (!mounted) return;
      _ctrl
          .animateTo(0, duration: _outMs, curve: Curves.easeIn)
          .then((_) => widget.onDone());
    });
  }

  @override
  void dispose() {
    _haloTimer?.cancel();
    _strokeTimer?.cancel();
    _dismissTimer?.cancel();
    _ctrl.dispose();
    _haloCtrl.dispose();
    _strokeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.type == _FType.success;
    // SUCCESS → naranja de marca   |   ERROR → rojo
    final accent = isSuccess ? AppColors.primary : AppColors.error;
    final ringColor = accent.withValues(alpha: 0.14);
    final ringBorder = accent.withValues(alpha: 0.32);
    final iconBg = accent.withValues(alpha: 0.20);
    final colors = context.colors;

    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _haloCtrl, _strokeCtrl]),
      builder: (_, __) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // ── Fondo semiopaco ──────────────────────────────────────
              Positioned.fill(
                child: Opacity(
                  opacity: _backdropOpacity.value,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: const BackdropFilter(
                      filter: ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.dstIn,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Contenido central ────────────────────────────────────
              Center(
                child: FadeTransition(
                  opacity: _cardOpacity,
                  child: ScaleTransition(
                    scale: _cardScale,
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusXL,
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.50),
                            blurRadius: 60,
                            offset: const Offset(0, 20),
                          ),
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 30,
                            offset: Offset.zero,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Halo + anillo + icono ────────────────────
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Halo pulsante
                                ScaleTransition(
                                  scale: _haloScale,
                                  child: Opacity(
                                    opacity: _haloOpacity.value,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accent,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Anillo
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ringColor,
                                    border: Border.all(
                                      color: ringBorder,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    // Icono interior con círculo
                                    child: Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: iconBg,
                                      ),
                                      child: Center(
                                        child: _AnimatedIcon(
                                          isSuccess: isSuccess,
                                          progress: _stroke.value,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ── Mensaje ──────────────────────────────────
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.description != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.description!,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Icono dibujado progresivamente (check o X) usando CustomPainter.
class _AnimatedIcon extends StatelessWidget {
  final bool isSuccess;
  final double progress; // 0..1
  final Color color;

  const _AnimatedIcon({
    required this.isSuccess,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: isSuccess
          ? _CheckPainter(progress: progress, color: color)
          : _XPainter(progress: progress, color: color),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Checkmark: (4,14) → (11,21) → (26,6)
    final path = Path()
      ..moveTo(4, 14)
      ..lineTo(11, 21)
      ..lineTo(26, 6);

    final metrics = path.computeMetrics().first;
    final len = metrics.length;
    final drawn = metrics.extractPath(0, len * progress.clamp(0.0, 1.0));
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

class _XPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _XPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Primera línea completa en la primera mitad del progress
    final p1 = (progress * 2).clamp(0.0, 1.0);
    // Segunda línea en la segunda mitad
    final p2 = ((progress - 0.5) * 2).clamp(0.0, 1.0);

    if (p1 > 0) {
      canvas.drawLine(Offset(5, 5), Offset(5 + 20 * p1, 5 + 20 * p1), paint);
    }
    if (p2 > 0) {
      canvas.drawLine(Offset(25, 5), Offset(25 - 20 * p2, 5 + 20 * p2), paint);
    }
  }

  @override
  bool shouldRepaint(_XPainter old) => old.progress != progress;
}
