import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
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
  bool _showPass = false;
  String? _error;
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
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
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPasswordHelp() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solicita el restablecimiento a un administrador.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pageHeight =
                  constraints.maxHeight + media.viewInsets.bottom;
              if (constraints.maxWidth >= 1024) {
                final panelPadding = constraints.maxWidth >= 1600 ? 96.0 : 48.0;
                return Row(
                  key: const Key('login-desktop-composition'),
                  children: [
                    Expanded(
                      child: _LoginHero(height: pageHeight, desktop: true),
                    ),
                    Expanded(
                      child: Container(
                        key: const Key('login-desktop-panel'),
                        height: pageHeight,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF090806), Color(0xFF160C07)],
                          ),
                        ),
                        child: SingleChildScrollView(
                          key: const Key('login-desktop-scroll-view'),
                          padding: EdgeInsets.symmetric(
                            horizontal: panelPadding,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (pageHeight - 64).clamp(
                                0.0,
                                double.infinity,
                              ),
                            ),
                            child: Align(
                              alignment: const Alignment(0, -0.18),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 716,
                                ),
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.asset(
                                        'assets/images/barbeer_Log.png',
                                        key: const Key('login-gold-monogram'),
                                        width: 72,
                                        height: 76,
                                        fit: BoxFit.contain,
                                        semanticLabel: 'Logo de BarBeer',
                                      ),
                                      const SizedBox(height: 24),
                                      _buildForm(desktop: true),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              final contentWidth = constraints.maxWidth
                  .clamp(0.0, 600.0)
                  .toDouble();
              final heroHeight = (pageHeight * 0.42)
                  .clamp(286.0, 360.0)
                  .toDouble();
              final panelMinHeight = (pageHeight - heroHeight)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: SingleChildScrollView(
                    key: const Key('login-scroll-view'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: pageHeight),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LoginHero(height: heroHeight),
                          FadeTransition(
                            opacity: _fade,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Positioned(
                                  top: -36,
                                  child: Container(
                                    key: const Key('login-panel-bump'),
                                    width: 88,
                                    height: 88,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Container(
                                  key: const Key('login-panel'),
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    minHeight: panelMinHeight,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(32),
                                    ),
                                  ),
                                  child: SafeArea(
                                    top: false,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        36,
                                        24,
                                        20,
                                      ),
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 400,
                                          ),
                                          child: _buildForm(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(top: -30, child: _LoginLogo()),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm({bool desktop = false}) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Iniciar sesión',
          style: TextStyle(
            fontSize: desktop ? 32 : 23,
            fontWeight: FontWeight.w800,
            color: desktop ? Colors.white : AppColors.textPrimary,
            letterSpacing: desktop ? -0.7 : null,
          ),
        ),
        SizedBox(height: desktop ? 10 : 3),
        Text(
          desktop
              ? 'Ingresa tus credenciales para acceder al sistema interno'
              : 'Ingresa tus credenciales para ingresar',
          style: TextStyle(
            fontSize: desktop ? 15 : 13,
            color: desktop
                ? Colors.white.withValues(alpha: 0.48)
                : AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: desktop ? 32 : 16),
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _LoginField(
          controller: _userCtrl,
          hint: 'Usuario',
          icon: Icons.person_outline_rounded,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Requerido' : null,
        ),
        SizedBox(height: desktop ? 20 : 10),
        _LoginField(
          controller: _passCtrl,
          hint: 'Contraseña',
          icon: Icons.lock_outline_rounded,
          autofillHints: const [AutofillHints.password],
          obscureText: !_showPass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
          validator: (value) =>
              value == null || value.isEmpty ? 'Requerido' : null,
          trailing: IconButton(
            tooltip: _showPass ? 'Ocultar contraseña' : 'Mostrar contraseña',
            onPressed: () => setState(() => _showPass = !_showPass),
            icon: Icon(
              _showPass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ),
        ),
        TextButton(
          onPressed: _showPasswordHelp,
          style: TextButton.styleFrom(
            foregroundColor: desktop
                ? const Color(0xFFFF4F1F)
                : AppColors.brand,
            minimumSize: const Size(44, 38),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            desktop
                ? '¿Olvidaste tu contraseña? Solicita a un administrador que la restablezca.'
                : '¿Olvidaste tu contraseña?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: desktop ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: desktop ? 16 : 10),
        SizedBox(
          width: double.infinity,
          height: desktop ? 70 : 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _loading
                    ? const [Color(0x99FF7200), Color(0x99FF4B00)]
                    : const [Color(0xFFFF7200), Color(0xFFFF4B00)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: desktop
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF5B00).withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Ingresar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: desktop ? 34 : 10),
        if (desktop)
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SOLO PERSONAL AUTORIZADO',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ],
          )
        else
          const Text(
            'BarBeer © 2026',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
      ],
    ),
  );
}

class _LoginHero extends StatelessWidget {
  final double height;
  final bool desktop;

  const _LoginHero({required this.height, this.desktop = false});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('login-hero'),
    width: double.infinity,
    constraints: BoxConstraints(minHeight: height),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bebb1.webp',
            fit: BoxFit.cover,
            alignment: desktop ? Alignment.center : Alignment.topCenter,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xE6000000), Color(0x52000000)],
              ),
            ),
          ),
        ),
        if (desktop) Positioned.fill(child: _content()) else _content(),
      ],
    ),
  );

  Widget _content() => SafeArea(
    bottom: false,
    child: Padding(
      padding: desktop
          ? const EdgeInsets.symmetric(horizontal: 64, vertical: 32)
          : const EdgeInsets.fromLTRB(20, 32, 20, 12),
      child: desktop
          ? LayoutBuilder(
              builder: (_, constraints) => _desktopContent(constraints),
            )
          : _mobileContent(),
    ),
  );

  Widget _desktopContent(BoxConstraints constraints) {
    final compact = constraints.maxHeight < 800;
    final topSpace = compact
        ? 12.0
        : (constraints.maxHeight - 700).clamp(36.0, 130.0);
    final featureHeight = compact ? 56.0 : 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topSpace),
        BarBeerWordmark(fontSize: compact ? 30 : 34, beerColor: Colors.white),
        SizedBox(height: compact ? 16 : 32),
        const Text(
          'SISTEMA INTERNO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.brand,
            letterSpacing: 2.2,
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        Text(
          'Sistema interno\nde gestión',
          style: TextStyle(
            fontSize: compact ? 42 : 52,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        Text(
          'Accede de forma segura a la plataforma\n'
          'de administración de BarBeer.',
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            color: const Color(0xE6FFFFFF),
            height: 1.55,
          ),
        ),
        SizedBox(height: compact ? 16 : 28),
        _FeatureRow(
          icon: Icons.bar_chart_rounded,
          title: 'Ventas',
          description: 'Consulta y analiza el rendimiento.',
          desktop: true,
          desktopHeight: featureHeight,
        ),
        SizedBox(height: compact ? 8 : 10),
        _FeatureRow(
          icon: Icons.inventory_2_outlined,
          title: 'Inventario',
          description: 'Controla stock y movimientos.',
          desktop: true,
          desktopHeight: featureHeight,
        ),
        SizedBox(height: compact ? 8 : 10),
        _FeatureRow(
          icon: Icons.receipt_long_outlined,
          title: 'Caja y reportes',
          description: 'Cierres, reportes y conciliaciones.',
          desktop: true,
          desktopHeight: featureHeight,
        ),
        const Spacer(),
        Text(
          '© ${DateTime.now().year} BarBeer ERP. Todos los derechos reservados.',
          style: const TextStyle(fontSize: 10, color: Color(0x66FFFFFF)),
        ),
      ],
    );
  }

  Widget _mobileContent() => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: BarBeerWordmark(fontSize: 28, beerColor: Colors.white)),
      SizedBox(height: 8),
      Text(
        'Accede de forma segura a la plataforma\n'
        'de administración de BarBeer.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: Color(0xE6FFFFFF),
          height: 1.3,
        ),
      ),
      SizedBox(height: 10),
      _FeatureRow(
        icon: Icons.bar_chart_rounded,
        title: 'Ventas',
        description: 'Consulta y analiza el rendimiento.',
      ),
      SizedBox(height: 6),
      _FeatureRow(
        icon: Icons.inventory_2_outlined,
        title: 'Inventario',
        description: 'Controla stock y movimientos.',
      ),
      SizedBox(height: 6),
      _FeatureRow(
        icon: Icons.receipt_long_outlined,
        title: 'Caja y reportes',
        description: 'Cierres, reportes y conciliaciones.',
      ),
    ],
  );
}

class _LoginLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    key: const Key('login-logo-circle'),
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.border, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        'assets/images/barbeer_launcher.png',
        fit: BoxFit.cover,
        semanticLabel: 'Logo de BarBeer',
      ),
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool desktop;
  final double desktopHeight;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.desktop = false,
    this.desktopHeight = 72,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(minHeight: desktop ? desktopHeight : 0),
    padding: EdgeInsets.symmetric(
      horizontal: desktop ? 16 : 11,
      vertical: desktop ? 11 : 7,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.27),
      borderRadius: BorderRadius.circular(desktop ? 12 : 10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: desktop ? 48 : 27,
          height: desktop ? 48 : 27,
          decoration: desktop
              ? BoxDecoration(
                  color: const Color(0xFF3A1900).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.28),
                  ),
                )
              : null,
          child: Icon(icon, color: AppColors.brand, size: desktop ? 23 : 19),
        ),
        SizedBox(width: desktop ? 14 : 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xCCFFFFFF),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final Widget? trailing;

  const _LoginField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 1024;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: TextStyle(
        fontSize: desktop ? 16 : 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        suffixIcon: trailing,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        filled: true,
        fillColor: desktop ? const Color(0xFFF8F9FB) : AppColors.backgroundAlt,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: desktop ? 23 : 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
