import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../data/caja_repository.dart';
import '../providers/caja_provider.dart';

bool cashMovementCanBeAnnulled({
  required CajaMovimiento movement,
  required bool hasCajaReadPermission,
  required String? sessionVersion,
}) =>
    hasCajaReadPermission &&
    movement.anulable &&
    movement.id.isNotEmpty &&
    movement.cajaSesionId.isNotEmpty &&
    (sessionVersion == null || sessionVersion == 'V2');

class CashMovementAnnulmentAction extends ConsumerStatefulWidget {
  final CajaMovimiento movement;
  final bool hasCajaReadPermission;
  final bool isSuperAdmin;
  final String? sessionVersion;
  final Future<void> Function() onRefresh;
  final bool compact;

  const CashMovementAnnulmentAction({
    super.key,
    required this.movement,
    required this.hasCajaReadPermission,
    required this.isSuperAdmin,
    required this.sessionVersion,
    required this.onRefresh,
    this.compact = false,
  });

  @override
  ConsumerState<CashMovementAnnulmentAction> createState() =>
      _CashMovementAnnulmentActionState();
}

class _CashMovementAnnulmentActionState
    extends ConsumerState<CashMovementAnnulmentAction> {
  String? _verifiedSessionVersion;
  bool _checkingSession = false;
  bool _requiresRefresh = false;

  String? get _sessionVersion =>
      widget.sessionVersion ?? _verifiedSessionVersion;

  String? get _disabledReason {
    if (_requiresRefresh) {
      return 'Actualiza los movimientos antes de intentar otra anulación.';
    }
    if (_checkingSession) return 'Verificando la versión de la caja.';
    if (!widget.hasCajaReadPermission) {
      return 'Se requiere el permiso de lectura de caja.';
    }
    if (!widget.movement.anulable) {
      return 'El backend no habilita la anulación para este movimiento.';
    }
    if (widget.movement.id.isEmpty || widget.movement.cajaSesionId.isEmpty) {
      return 'No se pudo identificar el movimiento y su caja.';
    }
    if (_sessionVersion != null && _sessionVersion != 'V2') {
      return 'Las sesiones V1 son de solo lectura.';
    }
    return null;
  }

  Future<void> _open() async {
    if (_disabledReason != null) return;
    var version = _sessionVersion;
    if (version == null) {
      setState(() => _checkingSession = true);
      try {
        final session = await ref
            .read(cajaRepositoryProvider)
            .detalle(widget.movement.cajaSesionId);
        version = session.version;
        if (mounted) setState(() => _verifiedSessionVersion = version);
      } catch (_) {
        if (mounted) {
          AppFeedback.error(
            context,
            'No se pudo verificar la versión de la caja. No se envió la anulación.',
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _checkingSession = false);
      }
    }
    if (!mounted) return;
    if (version != 'V2') {
      AppFeedback.error(context, 'Las sesiones V1 son de solo lectura.');
      return;
    }

    final result = await showDialog<_CashMovementAnnulmentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CashMovementAnnulmentDialog(
        movement: widget.movement,
        isSuperAdmin: widget.isSuperAdmin,
      ),
    );
    if (!mounted || result == null) return;

    if (result == _CashMovementAnnulmentResult.annulled) {
      setState(() => _requiresRefresh = true);
      AppFeedback.success(context, 'Movimiento anulado.');
      try {
        await widget.onRefresh();
      } catch (_) {
        if (mounted) {
          AppFeedback.error(
            context,
            'El movimiento se anuló, pero no se pudo actualizar la lista.',
          );
        }
      }
      return;
    }

    setState(() => _requiresRefresh = true);
    AppFeedback.error(
      context,
      result == _CashMovementAnnulmentResult.outcomeUnknown
          ? 'No se pudo confirmar el resultado. Se actualizarán los movimientos; no repitas el envío.'
          : 'El movimiento cambió desde la última consulta. Se actualizarán los movimientos.',
    );
    try {
      await widget.onRefresh();
    } catch (_) {
      // Keep this action disabled until a later successful list refresh rebuilds it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabledReason = _disabledReason;
    final enabled = disabledReason == null;
    final tooltip = disabledReason ?? 'Anular movimiento';
    if (widget.compact) {
      return Tooltip(
        message: tooltip,
        child: IconButton(
          key: ValueKey('cash-movement-annul-${widget.movement.id}'),
          tooltip: tooltip,
          onPressed: enabled ? _open : null,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: _checkingSession
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cancel_outlined),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: OutlinedButton.icon(
        key: ValueKey('cash-movement-annul-${widget.movement.id}'),
        onPressed: enabled ? _open : null,
        icon: _checkingSession
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cancel_outlined, size: 18),
        label: Text(_checkingSession ? 'Verificando caja' : 'Anular'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }
}

enum _CashMovementAnnulmentResult { annulled, refreshRequired, outcomeUnknown }

class _CashMovementAnnulmentDialog extends ConsumerStatefulWidget {
  final CajaMovimiento movement;
  final bool isSuperAdmin;

  const _CashMovementAnnulmentDialog({
    required this.movement,
    required this.isSuperAdmin,
  });

  @override
  ConsumerState<_CashMovementAnnulmentDialog> createState() =>
      _CashMovementAnnulmentDialogState();
}

class _CashMovementAnnulmentDialogState
    extends ConsumerState<_CashMovementAnnulmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _pinController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(cajaRepositoryProvider)
          .anularMovimiento(
            cajaSesionId: widget.movement.cajaSesionId,
            movimientoId: widget.movement.id,
            motivo: _reasonController.text.trim(),
            superadminPin: widget.isSuperAdmin ? null : _pinController.text,
          );
      if (mounted) {
        Navigator.of(context).pop(_CashMovementAnnulmentResult.annulled);
      }
    } catch (error) {
      if (!mounted) return;
      _pinController.clear();
      if (_requiresRefresh(error)) {
        Navigator.of(context).pop(
          error is AppException && error.statusCode == 409
              ? _CashMovementAnnulmentResult.refreshRequired
              : _CashMovementAnnulmentResult.outcomeUnknown,
        );
      } else {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      _pinController.clear();
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _requiresRefresh(Object error) {
    if (error is NetworkException) return true;
    if (error is AppException) {
      final statusCode = error.statusCode;
      return statusCode == null || statusCode == 409 || statusCode >= 500;
    }
    return true;
  }

  String _errorMessage(Object error) => error is AppException
      ? error.message
      : 'No se pudo anular el movimiento.';

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Anular movimiento'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.movement.concepto} · S/ ${widget.movement.monto.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Se registrará una reversión financiera y quedará en auditoría. El movimiento original se conservará.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('cash-annul-reason'),
                controller: _reasonController,
                autofocus: true,
                maxLength: 500,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Ingresa el motivo de la anulación.',
              ),
              if (!widget.isSuperAdmin) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('cash-annul-pin'),
                  controller: _pinController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Clave de SUPERADMIN (4 dígitos)',
                    helperText:
                        'Se envía solo para autorizar esta solicitud; no se guarda en el dispositivo.',
                  ),
                  validator: (value) => RegExp(r'^\d{4}$').hasMatch(value ?? '')
                      ? null
                      : 'Ingresa una clave de SUPERADMIN de 4 dígitos.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    key: const ValueKey('cash-annul-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('cash-annul-confirm'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Anulando…' : 'Confirmar anulación'),
        ),
      ],
    ),
  );
}
