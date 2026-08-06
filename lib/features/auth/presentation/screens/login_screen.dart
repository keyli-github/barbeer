import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate())
      return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(
            username: _userCtrl.text.trim(),
            password: _passCtrl.text,
            rememberMe: true,
          );
    } catch (e) {
      String msg = e
          .toString()
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
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: size.height * 0.1),
                      _buildBrand(),
                      SizedBox(height: size.height * 0.06),
                      _buildLoginForm(),
                      SizedBox(height: AppSpacing.xl),
                      _buildFooter(),
                      SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() => Column(
    children: [
      // Logo con sombra suave
      Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
          boxShadow: AppShadows.card,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        padding: EdgeInsets.all(AppSpacing.md),
        child: Image.asset(
          'assets/images/barbeerLogo.png',
          fit: BoxFit.contain,
        ),
      ),
      SizedBox(height: AppSpacing.lg),
      // Título
      Text(
        'Bar Beer',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      SizedBox(height: AppSpacing.xxs),
      // Subtítulo
      Text(
        'Sistema de gestión',
        style: TextStyle(
          fontSize: 15,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _buildLoginForm() => Container(
    width: double.infinity,
    padding: EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLG),
      boxShadow: AppShadows.card,
      border: Border.all(color: AppColors.border, width: 1),
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Iniciar sesión',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.xxs),
          Text(
            'Ingresa tus credenciales para continuar',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          SizedBox(height: AppSpacing.xl),
          // Error message si existe
          if (_error != null) ...[
            _buildErrorBox(_error!),
            SizedBox(height: AppSpacing.md),
          ],
          // Campo usuario
          AppTextField(
            label: 'Usuario',
            hint: 'Nombre de usuario',
            controller: _userCtrl,
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
          SizedBox(height: AppSpacing.md),
          // Campo contraseña
          AppTextField(
            label: 'Contraseña',
            hint: 'Ingresa tu contraseña',
            controller: _passCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          SizedBox(height: AppSpacing.xl),
          // Botón de login
          PrimaryButton(
            text: 'Ingresar',
            onPressed: _loading ? null : _login,
            isLoading: _loading,
            icon: Icons.login_rounded,
          ),
        ],
      ),
    ),
  );

  Widget _buildErrorBox(String msg) => Container(
    padding: EdgeInsets.all(AppSpacing.sm),
    decoration: BoxDecoration(
      color: AppColors.errorLight,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
      border: Border.all(color: AppColors.errorBorder, width: 1),
    ),
    child: Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: AppSpacing.iconSM,
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFooter() => Column(
    children: [
      Text(
        'Bar Beer © 2024',
        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
      SizedBox(height: AppSpacing.xxs),
      Text(
        'Sistema de gestión empresarial',
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    ],
  );
}
