import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  final bool isForced;
  const ChangePasswordScreen({super.key, this.isForced = false});
  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _len => _new.text.length >= 12;
  bool get _upper => _new.text.contains(RegExp(r'[A-Z]'));
  bool get _lower => _new.text.contains(RegExp(r'[a-z]'));
  bool get _digit => _new.text.contains(RegExp(r'[0-9]'));
  bool get _match => _new.text == _confirm.text && _confirm.text.isNotEmpty;
  bool get _allOk => _len && _upper && _lower && _digit && _match;

  @override
  void dispose() {
    _cur.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(current: _cur.text, newPwd: _new.text);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isForced
          ? null
          : AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Cambiar contraseña',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isForced) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.warningLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: AppColors.warning,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cambio de contrasena requerido',
                      style: AppTextStyles.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Por seguridad, debes cambiar tu contrasena antes de continuar.',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                  if (_error != null) ...[
                    _errBox(_error!),
                    const SizedBox(height: 16),
                  ],
                  AppTextField(
                    label: 'Contrasena actual',
                    hint: 'Ingresa tu contrasena actual',
                    controller: _cur,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Nueva contrasena',
                    hint: 'Minimo 12 caracteres',
                    controller: _new,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      if (v.length < 12) return 'Minimo 12 caracteres';
                      if (!v.contains(RegExp(r'[A-Z]')))
                        return 'Necesita mayuscula';
                      if (!v.contains(RegExp(r'[a-z]')))
                        return 'Necesita minuscula';
                      if (!v.contains(RegExp(r'[0-9]')))
                        return 'Necesita numero';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _requirements(),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Confirmar contrasena',
                    hint: 'Repite la nueva contrasena',
                    controller: _confirm,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_allOk) _submit();
                    },
                    validator: (v) =>
                        v != _new.text ? 'Las contrasenas no coinciden' : null,
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Cambiar contrasena',
                    onPressed: _allOk ? _submit : null,
                    isLoading: _loading,
                    icon: Icons.check_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _requirements() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      children: [
        _req('Al menos 12 caracteres', _len),
        _req('Al menos una mayuscula (A-Z)', _upper),
        _req('Al menos una minuscula (a-z)', _lower),
        _req('Al menos un numero (0-9)', _digit),
        _req('Las contrasenas coinciden', _match),
      ],
    ),
  );

  Widget _req(String text, bool met) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 16,
          color: met ? AppColors.success : AppColors.textTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: met ? AppColors.success : AppColors.textSecondary,
            fontWeight: met ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );

  Widget _errBox(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.errorLight,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(fontSize: 13, color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
