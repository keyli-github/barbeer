import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _rememberMe = false, _loading = false;
  String? _error;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(duration: const Duration(milliseconds: 600), vsync: this)..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); _anim.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
          username: _userCtrl.text.trim(),
          password: _passCtrl.text,
          rememberMe: _rememberMe);
    } catch (e) {
      String msg = e.toString()
          .replaceAll('AppException: ', '')
          .replaceAll('Exception: ', '')
          .trim();
      if (msg.isEmpty || msg == 'Exception') {
        msg = 'No se pudo conectar al servidor. Verifica tu red.';
      }
      // Solo actualizar estado si el widget sigue montado (puede haberse
      // desmontado si hubo navegación antes de que llegara la excepción)
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
        child: SafeArea(child: GestureDetector(onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(height: size.height * 0.08),
                _brand(),
                SizedBox(height: size.height * 0.05),
                _card(),
                const SizedBox(height: 16),
                Text('Bar Beer 2024', style: AppTextStyles.labelSmall),
                const SizedBox(height: 24),
              ]))))))));
  }

  Widget _brand() => Column(children: [
    Container(width: 80, height: 80,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          shape: BoxShape.circle, boxShadow: AppShadows.button),
      child: const Icon(Icons.local_bar_rounded, color: Colors.white, size: 40)),
    const SizedBox(height: 16),
    Text('Bar Beer', style: AppTextStyles.displayMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6),
    const Text('Sistema de gestion', style: AppTextStyles.bodyMedium),
  ]);

  Widget _card() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.cardElevated, border: Border.all(color: AppColors.borderLight, width: 0.5)),
    child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Iniciar sesion', style: AppTextStyles.headlineMedium),
      const SizedBox(height: 4),
      const Text('Ingresa tus credenciales para continuar', style: AppTextStyles.bodyMedium),
      const SizedBox(height: 24),
      if (_error != null) ...[_errBox(_error!), const SizedBox(height: 16)],
      AppTextField(label: 'Usuario', hint: 'Nombre de usuario', controller: _userCtrl,
          prefixIcon: Icons.person_outline_rounded, textInputAction: TextInputAction.next,
          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
      const SizedBox(height: 14),
      AppTextField(label: 'Contrasena', hint: 'Ingresa tu contrasena', controller: _passCtrl,
          prefixIcon: Icons.lock_outline_rounded, obscureText: true,
          textInputAction: TextInputAction.done, onSubmitted: (_) => _login(),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(width: 20, height: 20, child: Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? false))),
        const SizedBox(width: 10),
        const Text('Mantener sesion iniciada', style: AppTextStyles.bodySmall),
      ]),
      const SizedBox(height: 24),
      PrimaryButton(label: 'Ingresar', onPressed: _loading ? null : _login, isLoading: _loading, icon: Icons.login_rounded),
    ])));

  Widget _errBox(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFFFEBEB), borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.error.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500))),
    ]));
}
