// Sheet de precuadre de caja (solo monto declarado).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barbeer/core/theme/app_colors.dart';
import 'package:barbeer/core/widgets/app_button.dart';
import 'package:barbeer/core/widgets/app_text_field.dart';
import '../providers/caja_provider.dart';

String _money(double v) => 'S/ ${v.toStringAsFixed(2)}';

void showPrecuadreSheet(
  BuildContext context, {
  required VoidCallback onSuccess,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PrecuadreSheet(onSuccess: onSuccess),
  );
}

class _PrecuadreSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _PrecuadreSheet({required this.onSuccess});

  @override
  ConsumerState<_PrecuadreSheet> createState() => _PrecuadreSheetState();
}

class _PrecuadreSheetState extends ConsumerState<_PrecuadreSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _loading = false;

  double get _expected =>
      ref.read(cajaProvider).actual?.resumen?.efectivoEsperado ?? 0;
  double get _declared => double.tryParse(_amountController.text) ?? 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Registrar precuadre',
      subtitle: 'Compara el efectivo contado con el saldo esperado',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TotalBand(label: 'Saldo esperado', value: _expected),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Monto declarado (S/)',
              hint: '0.00',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 0 ? 'Monto inválido' : null;
              },
            ),
            const SizedBox(height: 10),
            _DifferenceRow(value: _declared - _expected),
            const SizedBox(height: 20),
            AppButton(
              label: 'Guardar precuadre',
              isFullWidth: true,
              isLoading: _loading,
              variant: AppButtonVariant.primary,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(cajaProvider.notifier)
          .precuadre(double.parse(_amountController.text));
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Sheet de cierre de caja (monto + observaciones + cierre forzado opcional).

void showCierreSheet(
  BuildContext context, {
  required bool canForzar,
  required VoidCallback onSuccess,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CierreSheet(canForzar: canForzar, onSuccess: onSuccess),
  );
}

class _CierreSheet extends ConsumerStatefulWidget {
  final bool canForzar;
  final VoidCallback onSuccess;

  const _CierreSheet({required this.canForzar, required this.onSuccess});

  @override
  ConsumerState<_CierreSheet> createState() => _CierreSheetState();
}

class _CierreSheetState extends ConsumerState<_CierreSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _motivoController = TextEditingController();
  bool _forzar = false;
  bool _loading = false;

  double get _expected =>
      ref.read(cajaProvider).actual?.resumen?.efectivoEsperado ?? 0;
  double get _declared => double.tryParse(_amountController.text) ?? 0;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Cerrar caja',
      subtitle: 'El cierre es definitivo para este turno',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TotalBand(label: 'Saldo esperado', value: _expected),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Monto declarado (S/)',
              hint: '0.00',
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null || n < 0 ? 'Monto inválido' : null;
              },
            ),
            const SizedBox(height: 10),
            _DifferenceRow(value: _declared - _expected),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Observaciones (opcional)',
              hint: 'Detalle del arqueo',
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
            ),
            if (widget.canForzar) ...[
              const SizedBox(height: 12),
              _ForzarSection(
                forzar: _forzar,
                motivoController: _motivoController,
                onChanged: (v) => setState(() => _forzar = v),
              ),
            ],
            const SizedBox(height: 20),
            AppButton(
              label: 'Confirmar cierre',
              isFullWidth: true,
              isLoading: _loading,
              variant: AppButtonVariant.danger,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_forzar && _motivoController.text.trim().isEmpty) {
      _showError(context, 'Indica el motivo del cierre forzado.');
      return;
    }
    setState(() => _loading = true);
    try {
      final amount = double.parse(_amountController.text);
      final notes = _notesController.text;
      if (_forzar) {
        await ref
            .read(cajaProvider.notifier)
            .cerrarForzado(
              amount,
              motivoForzado: _motivoController.text.trim(),
              observaciones: notes.isNotEmpty ? notes : null,
            );
      } else {
        await ref
            .read(cajaProvider.notifier)
            .cerrar(amount, notes.isNotEmpty ? notes : null);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Widgets privados compartidos ─────────────────────────────────────────────

class _SheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ],
    ),
  );
}

class _TotalBand extends StatelessWidget {
  final String label;
  final double value;

  const _TotalBand({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryBorder),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(
          _money(value),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _DifferenceRow extends StatelessWidget {
  final double value;

  const _DifferenceRow({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value == 0
        ? AppColors.success
        : value < 0
        ? AppColors.error
        : AppColors.warning;
    return Row(
      children: [
        const Text(
          'Diferencia estimada',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ForzarSection extends StatelessWidget {
  final bool forzar;
  final TextEditingController motivoController;
  final ValueChanged<bool> onChanged;

  const _ForzarSection({
    required this.forzar,
    required this.motivoController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: forzar,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.warning,
            ),
            const Expanded(
              child: Text(
                'Forzar cierre con ventas pendientes',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        if (forzar) ...[
          const SizedBox(height: 8),
          AppTextField(
            label: 'Motivo del cierre forzado *',
            hint: 'Explica por qué cierras con ventas pendientes…',
            controller: motivoController,
            maxLength: 300,
          ),
        ],
      ],
    ),
  );
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString()),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
