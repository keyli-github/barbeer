// Pantallas de precuadre y cierre de caja.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:barbeer/core/navigation/app_nav.dart';
import 'package:barbeer/core/theme/app_colors.dart';
import 'package:barbeer/core/widgets/app_button.dart';
import 'package:barbeer/core/widgets/app_feedback.dart';
import 'package:barbeer/core/widgets/app_text_field.dart';
import 'package:barbeer/core/widgets/responsive_form.dart';
import '../../data/caja_repository.dart';
import '../providers/caja_provider.dart';

String _money(double v) => 'S/ ${v.toStringAsFixed(2)}';

void showPrecuadreSheet(
  BuildContext context, {
  required VoidCallback onSuccess,
  Map<double, int> initialCounts = const {},
}) {
  ResponsiveForm.showPage<void>(
    context: context,
    dialogWidth: 640,
    dialogHeight: 760,
    page: _PrecuadreSheet(onSuccess: onSuccess, initialCounts: initialCounts),
  );
}

class _PrecuadreSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final Map<double, int> initialCounts;

  const _PrecuadreSheet({required this.onSuccess, required this.initialCounts});

  @override
  ConsumerState<_PrecuadreSheet> createState() => _PrecuadreSheetState();
}

class _PrecuadreSheetState extends ConsumerState<_PrecuadreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<double, TextEditingController> _controllers = {
    for (final value in cajaDenominaciones)
      value: TextEditingController(
        text: widget.initialCounts[value]?.toString() ?? '',
      ),
  };
  bool _loading = false;

  double get _expected =>
      ref.read(cajaProvider).actual?.resumen?.efectivoEsperado ?? 0;
  Map<double, int> get _counts => {
    for (final item in _controllers.entries)
      item.key: int.tryParse(item.value.text) ?? 0,
  };
  double get _declared => cajaDenominacionesTotal(_counts);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: 'Registrar precuadre',
        subtitle: 'Compara el efectivo contado con el saldo esperado',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _TotalBand(label: 'Saldo esperado', value: _expected),
              const SizedBox(height: 14),
              _DenominationFields(
                controllers: _controllers,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _TotalBand(label: 'Total contado', value: _declared),
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
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(cajaProvider.notifier).precuadre(_counts);
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

/// Sheet de cierre de caja (conteo + observaciones + cierre forzado opcional).

void showCierreSheet(
  BuildContext context, {
  required bool canForzar,
  Map<double, int> initialCounts = const {},
  required VoidCallback onSuccess,
}) {
  ResponsiveForm.showPage<void>(
    context: context,
    dialogWidth: 680,
    dialogHeight: 800,
    page: _CierreSheet(
      canForzar: canForzar,
      initialCounts: initialCounts,
      onSuccess: onSuccess,
    ),
  );
}

class _CierreSheet extends ConsumerStatefulWidget {
  final bool canForzar;
  final Map<double, int> initialCounts;
  final VoidCallback onSuccess;

  const _CierreSheet({
    required this.canForzar,
    required this.initialCounts,
    required this.onSuccess,
  });

  @override
  ConsumerState<_CierreSheet> createState() => _CierreSheetState();
}

class _CierreSheetState extends ConsumerState<_CierreSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<double, TextEditingController> _controllers = {
    for (final value in cajaDenominaciones)
      value: TextEditingController(
        text: widget.initialCounts.containsKey(value)
            ? widget.initialCounts[value].toString()
            : '',
      ),
  };
  final _motivoDiferenciaController = TextEditingController();
  final _motivoController = TextEditingController();
  bool _forzar = false;
  bool _loading = false;

  double get _expected =>
      ref.read(cajaProvider).actual?.resumen?.efectivoEsperado ?? 0;
  Map<double, int> get _counts => {
    for (final item in _controllers.entries)
      item.key: int.tryParse(item.value.text) ?? 0,
  };
  double get _declared => cajaDenominacionesTotal(_counts);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _motivoDiferenciaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: 'Cerrar caja',
        subtitle: 'El cierre es definitivo para este turno',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _TotalBand(label: 'Saldo esperado', value: _expected),
              const SizedBox(height: 14),
              _DenominationFields(
                controllers: _controllers,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _TotalBand(label: 'Total contado', value: _declared),
              const SizedBox(height: 10),
              _DifferenceRow(value: _declared - _expected),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Motivo de diferencia',
                hint: 'Explica la diferencia entre lo contado y lo esperado',
                controller: _motivoDiferenciaController,
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
      final motDif = _motivoDiferenciaController.text.trim();
      await ref
          .read(cajaProvider.notifier)
          .cerrar(
            _counts,
            motivoDiferencia: motDif.isNotEmpty ? motDif : null,
            forzarPendientes: _forzar,
            motivoForzado: _forzar ? _motivoController.text.trim() : null,
          );
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

class _DenominationFields extends StatelessWidget {
  final Map<double, TextEditingController> controllers;
  final VoidCallback onChanged;

  const _DenominationFields({
    required this.controllers,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Cantidad por denominación',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
      ),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: MediaQuery.sizeOf(context).width < 380 ? 1.9 : 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        children: [
          for (final value in cajaDenominaciones)
            TextFormField(
              key: ValueKey('caja-denominacion-$value'),
              controller: controllers[value],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              onChanged: (_) => onChanged(),
              validator: (text) {
                final cantidad = int.tryParse(
                  text?.isEmpty ?? true ? '0' : text!,
                );
                return cantidad == null || cantidad > 999999
                    ? 'Cantidad inválida'
                    : null;
              },
              decoration: InputDecoration(
                labelText: 'S/ ${_denomination(value)}',
                hintText: '0',
                counterText: '',
                prefixIcon: const Icon(Icons.payments_outlined, size: 18),
              ),
            ),
        ],
      ),
    ],
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
      color: context.colors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.colors.primaryBorder),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _money(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
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
        Text(
          'Diferencia estimada',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
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
      color: context.colors.warningLight,
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
            maxLength: 500,
          ),
        ],
      ],
    ),
  );
}

void _showError(BuildContext context, Object error) {
  AppFeedback.error(context, error.toString());
}

String _denomination(double value) =>
    value >= 1 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
