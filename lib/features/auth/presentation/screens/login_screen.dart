import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
import '../providers/auth_provider.dart';

/// Superficie del panel del login: siempre oscura, igual en web y app,
/// sin importar el tema del sistema (evita que "se ponga blanco").
const Color _loginPanel = Color(0xFF000000);
const Color _loginInputFill = Color(0xFF171512);
const Color _loginInputBorder = Color(0x33F97316);

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
    AppFeedback.success(
      context,
      'Solicita el restablecimiento a un administrador.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final branding = ref.watch(brandingProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _loginPanel,
        systemNavigationBarIconBrightness: Brightness.light,
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
                return Row(
                  key: const Key('login-desktop-composition'),
                  children: [
                    Expanded(
                      child: _LoginHero(
                        height: pageHeight,
                        desktop: true,
                        coverUrl: branding.coverUrl,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        key: const Key('login-desktop-panel'),
                        height: pageHeight,
                        color: Colors.black,
                        child: SingleChildScrollView(
                          key: const Key('login-desktop-scroll-view'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 32,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (pageHeight - 64).clamp(
                                0.0,
                                double.infinity,
                              ),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _BrandingLogo(
                                        url: branding.logoUrl,
                                        width: 88,
                                        height: 72,
                                      ),
                                      const SizedBox(height: 18),
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
              final isNarrow = constraints.maxWidth < 340;
              final isShort = pageHeight < 560;
              final contentWidth = constraints.maxWidth
                  .clamp(0.0, 600.0)
                  .toDouble();
              final heroHeight = (pageHeight * 0.42)
                  .clamp(isShort ? 180.0 : 286.0, isShort ? 250.0 : 360.0)
                  .toDouble();
              final panelMinHeight = (pageHeight - heroHeight)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              final panelHPad = isNarrow ? 20.0 : 24.0;
              final panelTopPad = isShort ? 34.0 : 44.0;
              final panelBottomPad = isShort ? 16.0 : 20.0;

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
                          _LoginHero(
                            height: heroHeight,
                            coverUrl: branding.coverUrl,
                          ),
                          FadeTransition(
                            opacity: _fade,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(_fade),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    key: const Key('login-panel'),
                                    margin: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      24,
                                    ),
                                    width: double.infinity,
                                    constraints: BoxConstraints(
                                      minHeight: (panelMinHeight - 24).clamp(
                                        0.0,
                                        double.infinity,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: _loginPanel,
                                      borderRadius: BorderRadius.circular(28),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x80000000),
                                          blurRadius: 40,
                                          offset: Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: SafeArea(
                                      top: false,
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          panelHPad,
                                          panelTopPad,
                                          panelHPad,
                                          panelBottomPad,
                                        ),
                                        child: Center(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 400,
                                            ),
                                            child: _buildForm(
                                              desktop: false,
                                              narrow: isNarrow,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -30,
                                    child: _LoginLogo(url: branding.logoUrl),
                                  ),
                                ],
                              ),
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

  Widget _buildForm({bool desktop = false, bool narrow = false}) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Iniciar sesión',
          style: TextStyle(
            fontSize: desktop ? 30 : (narrow ? 21 : 23),
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          desktop
              ? 'Ingresa tus credenciales para acceder al sistema interno'
              : 'Ingresa tus credenciales para ingresar',
          style: TextStyle(
            fontSize: desktop ? 15 : (narrow ? 12 : 13),
            color: Colors.white.withValues(alpha: 0.48),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: desktop ? 24 : 16),
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF481B1B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF8F3030)),
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
        SizedBox(height: desktop ? 14 : 10),
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
              color: AppColors.brand.withValues(alpha: 0.60),
              size: 20,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showPasswordHelp,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              minimumSize: const Size(44, 38),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SizedBox(height: desktop ? 14 : 10),
        SizedBox(
          width: double.infinity,
          height: desktop ? 54 : 50,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Ingresar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: desktop ? 20 : 10),
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
          Text(
            'Yacare © 2026',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.32),
            ),
          ),
      ],
    ),
  );
}

class _LoginHero extends StatelessWidget {
  final double height;
  final bool desktop;
  final String? coverUrl;

  const _LoginHero({required this.height, this.desktop = false, this.coverUrl});

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('login-hero'),
    width: double.infinity,
    constraints: BoxConstraints(minHeight: height),
    child: Stack(
      children: [
        Positioned.fill(
          child: coverUrl == null
              ? Image.asset(
                  'assets/images/login.webp',
                  fit: BoxFit.cover,
                  alignment: desktop ? Alignment.center : Alignment.topCenter,
                )
              : Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  alignment: desktop ? Alignment.center : Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/login.webp',
                    fit: BoxFit.cover,
                    alignment: desktop ? Alignment.center : Alignment.topCenter,
                  ),
                ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xD9000000), Color(0x66000000)],
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
              builder: (_, constraints) =>
                  _desktopContent(compact: constraints.maxHeight < 600),
            )
          : _mobileContent(),
    ),
  );

  Widget _desktopContent({required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Center(child: BarBeerWordmark(fontSize: 30)),
      const Spacer(),
      const Text(
        'SISTEMA INTERNO',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.brand,
          letterSpacing: 2.2,
        ),
      ),
      const SizedBox(height: 10),
      RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 42,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
          children: [
            TextSpan(text: 'Sistema interno\nde '),
            TextSpan(
              text: 'gestión',
              style: TextStyle(color: AppColors.brand),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Accede de forma segura a la plataforma\n'
        'de administración de Yacare.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Color(0xE6FFFFFF), height: 1.5),
      ),
      if (!compact) ...[
        const SizedBox(height: 22),
        const _FeatureRow(
          icon: Icons.bar_chart_rounded,
          title: 'Ventas',
          description: 'Consulta y analiza el rendimiento.',
          desktop: true,
        ),
        const SizedBox(height: 8),
        const _FeatureRow(
          icon: Icons.inventory_2_outlined,
          title: 'Inventario',
          description: 'Controla stock y movimientos.',
          desktop: true,
        ),
        const SizedBox(height: 8),
        const _FeatureRow(
          icon: Icons.receipt_long_outlined,
          title: 'Caja y reportes',
          description: 'Cierres, reportes y conciliaciones.',
          desktop: true,
        ),
      ],
      const Spacer(),
      const Center(
        child: Text(
          '© 2026 Yacare ERP. Todos los derechos reservados.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF)),
        ),
      ),
    ],
  );

  Widget _mobileContent() => const Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(child: BarBeerWordmark(fontSize: 28)),
      SizedBox(height: 8),
      Text(
        'Accede de forma segura a la plataforma\n'
        'de administración de Yacare.',
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
  const _LoginLogo({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('login-logo-circle'),
    width: 64,
    height: 64,
    child: url == null
        ? Image.asset(
            'assets/images/yacare.png',
            fit: BoxFit.contain,
            semanticLabel: 'Logo de Yacare',
          )
        : Image.network(
            url!,
            fit: BoxFit.contain,
            semanticLabel: 'Logo de Yacare',
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/images/yacare.png',
              fit: BoxFit.contain,
              semanticLabel: 'Logo de Yacare',
            ),
          ),
  );
}

class _BrandingLogo extends StatelessWidget {
  const _BrandingLogo({this.url, this.width = 88, this.height = 72});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => url == null
      ? Image.asset(
          'assets/images/yacare.png',
          width: width,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: 'Logo de Yacare',
        )
      : Image.network(
          url!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: 'Logo de Yacare',
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/yacare.png',
            width: width,
            height: height,
            fit: BoxFit.contain,
            semanticLabel: 'Logo de Yacare',
          ),
        );
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool desktop;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.desktop = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: desktop ? 14 : 11,
      vertical: desktop ? 10 : 7,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.27),
      borderRadius: BorderRadius.circular(desktop ? 12 : 10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 27,
          child: Icon(icon, color: AppColors.brand, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
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
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    autofillHints: autofillHints,
    textInputAction: textInputAction,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    style: const TextStyle(fontSize: 15, color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 15,
        color: Color(0x66F9A03F),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        icon,
        color: AppColors.brand.withValues(alpha: 0.70),
        size: 20,
      ),
      suffixIcon: trailing,
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      filled: true,
      fillColor: _loginInputFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _loginInputBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _loginInputBorder),
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
