import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/branding_provider.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/barbeer_wordmark.dart';
import '../providers/auth_provider.dart';

// ── Colores del panel derecho (exactos a la web) ──────────────────────────
const Color _panelBg = Color(0xFF000000);
const Color _inputFill = Color(0x59000000); // bg-black/35
const Color _inputBorder = Color(0x33F97316); // border-orange-400/20
const Color _inputIconColor = Color(0xB3F97316); // text-orange-400/70
const Color _placeholderColor = Color(0x66F9A03F); // placeholder orange-300/40
const Color _eyeIconColor = Color(0x99F97316); // text-orange-400/60

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
      await ref.read(authProvider.notifier).login(
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
        systemNavigationBarColor: _panelBg,
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
              final isDesktop = constraints.maxWidth >= 1024;

              if (isDesktop) {
                return _buildDesktop(pageHeight, branding);
              }
              return _buildMobile(pageHeight, constraints, branding);
            },
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT (≥ 1024px) — Split 50/50 like web
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildDesktop(double pageHeight, BrandingState branding) => Row(
        children: [
          // ── Left: Hero image + content ──
          Expanded(
            child: _HeroPanel(
              height: pageHeight,
              desktop: true,
              coverUrl: branding.coverUrl,
            ),
          ),
          // ── Right: Login form panel ──
          Expanded(
            child: Container(
              height: pageHeight,
              color: _panelBg,
              child: Center(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          _Logo(url: branding.logoUrl, size: 100),
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
        ],
      );

  // ════════════════════════════════════════════════════════════════════════════
  // MOBILE LAYOUT (< 1024px) — Stacked: hero top, panel bottom
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildMobile(
    double pageHeight,
    BoxConstraints constraints,
    BrandingState branding,
  ) {
    final isNarrow = constraints.maxWidth < 360;
    final isShort = pageHeight < 600;
    // Keep hero visible but never dominate a short screen.
    // Minimum is 160 so the logo (positioned -30px above the card) always has
    // a visible background instead of overlapping the status bar.
    final heroHeight = (pageHeight * 0.38)
        .clamp(isShort ? 160.0 : 220.0, isShort ? 220.0 : 320.0)
        .toDouble();

    return Center(
      child: SizedBox(
        width: constraints.maxWidth.clamp(0.0, 600.0).toDouble(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: pageHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeroPanel(
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
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0A08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.10),
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
                                isNarrow ? 20.0 : 24.0,
                                isShort ? 34.0 : 44.0,
                                isNarrow ? 20.0 : 24.0,
                                isShort ? 16.0 : 20.0,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 400),
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
                          child: _Logo(url: branding.logoUrl, size: 64),
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
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FORM (shared between desktop & mobile)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildForm({bool desktop = false, bool narrow = false}) => Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Iniciar sesión',
              style: TextStyle(
                fontSize: desktop ? 30 : (narrow ? 21 : 23),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ingresa tus credenciales para acceder al sistema interno',
              style: TextStyle(
                fontSize: desktop ? 15 : (narrow ? 12 : 13),
                color: Colors.white.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: desktop ? 28 : 18),

            // Error
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF481B1B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x4DEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 16),
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
              const SizedBox(height: 12),
            ],

            // Username
            _buildInput(
              controller: _userCtrl,
              hint: 'Usuario',
              icon: Icons.person_outline_rounded,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              desktop: desktop,
            ),
            SizedBox(height: desktop ? 14 : 10),

            // Password
            _buildInput(
              controller: _passCtrl,
              hint: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              autofillHints: const [AutofillHints.password],
              obscureText: !_showPass,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              desktop: desktop,
              trailing: IconButton(
                tooltip:
                    _showPass ? 'Ocultar contraseña' : 'Mostrar contraseña',
                onPressed: () => setState(() => _showPass = !_showPass),
                icon: Icon(
                  _showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _eyeIconColor,
                  size: 20,
                ),
              ),
            ),
            SizedBox(height: desktop ? 18 : 14),

            // Button
            SizedBox(
              width: double.infinity,
              height: desktop ? 52 : 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: desktop ? 14 : 10),

            // Forgot password
            GestureDetector(
              onTap: _showPasswordHelp,
              child: Text(
                '¿Olvidaste tu contraseña? Solicita a un administrador que la restablezca.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: desktop ? 14 : 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ),
            SizedBox(height: desktop ? 24 : 14),

            // Footer divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.10), height: 1),
                ),
                Flexible(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'SOLO PERSONAL AUTORIZADO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                      color: Colors.white.withValues(alpha: 0.10), height: 1),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    List<String>? autofillHints,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    Widget? trailing,
    bool desktop = false,
  }) =>
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        validator: (v) =>
            v == null || v.trim().isEmpty ? 'Requerido' : null,
        style: const TextStyle(fontSize: 15, color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: _placeholderColor,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(icon, color: _inputIconColor, size: 20),
          suffixIcon: trailing,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 48, minHeight: 48),
          filled: true,
          fillColor: _inputFill,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _inputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _inputBorder),
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

// ══════════════════════════════════════════════════════════════════════════════
// HERO PANEL (left side on desktop, top on mobile)
// ══════════════════════════════════════════════════════════════════════════════
class _HeroPanel extends StatelessWidget {
  final double height;
  final bool desktop;
  final String? coverUrl;

  const _HeroPanel({
    required this.height,
    this.desktop = false,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: height),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: coverUrl == null
                  ? Image.asset(
                      'assets/images/login.webp',
                      fit: BoxFit.cover,
                      alignment:
                          desktop ? Alignment.center : Alignment.topCenter,
                    )
                  : Image.network(
                      coverUrl!,
                      fit: BoxFit.cover,
                      alignment:
                          desktop ? Alignment.center : Alignment.topCenter,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/login.webp',
                        fit: BoxFit.cover,
                        alignment:
                            desktop ? Alignment.center : Alignment.topCenter,
                      ),
                    ),
            ),
            // Gradient overlays
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xB3000000), Color(0x66000000), Color(0x1A000000)],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x40000000), Colors.transparent, Color(0x1A000000)],
                  ),
                ),
              ),
            ),
            // Content
            if (desktop) Positioned.fill(child: _desktopContent()) else _mobileContent(),
          ],
        ),
      );

  Widget _desktopContent() => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
          child: LayoutBuilder(
            builder: (_, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                const Center(child: BarBeerWordmark(fontSize: 30)),
                const SizedBox(height: 16),
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
                  'Accede de forma segura a la plataforma\nde administración de Yacare.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Color(0xE6FFFFFF), height: 1.5),
                ),
                if (constraints.maxHeight > 500) ...[
                  const SizedBox(height: 22),
                  const _FeatureCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Ventas',
                    desc: 'Consulta y analiza el rendimiento.',
                  ),
                  const SizedBox(height: 8),
                  const _FeatureCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'Inventario',
                    desc: 'Controla stock y movimientos.',
                  ),
                  const SizedBox(height: 8),
                  const _FeatureCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Caja y reportes',
                    desc: 'Cierres, reportes y conciliaciones.',
                  ),
                ],
                const Spacer(),
                const Center(
                  child: Text(
                    '© 2026 Yacare ERP. Todos los derechos reservados.',
                    style: TextStyle(fontSize: 10, color: Color(0x66FFFFFF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _mobileContent() => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Center(child: BarBeerWordmark(fontSize: 28)),
              SizedBox(height: 8),
              Text(
                'Accede de forma segura a la plataforma\nde administración de Yacare.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xE6FFFFFF),
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10),
              _FeatureCard(
                icon: Icons.bar_chart_rounded,
                title: 'Ventas',
                desc: 'Consulta y analiza el rendimiento.',
              ),
              SizedBox(height: 6),
              _FeatureCard(
                icon: Icons.inventory_2_outlined,
                title: 'Inventario',
                desc: 'Controla stock y movimientos.',
              ),
              SizedBox(height: 6),
              _FeatureCard(
                icon: Icons.receipt_long_outlined,
                title: 'Caja y reportes',
                desc: 'Cierres, reportes y conciliaciones.',
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// LOGO (no background, just the image)
// ══════════════════════════════════════════════════════════════════════════════
class _Logo extends StatelessWidget {
  const _Logo({this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
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

// ══════════════════════════════════════════════════════════════════════════════
// FEATURE CARD (matches web's feature rows)
// ══════════════════════════════════════════════════════════════════════════════
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0x26F97316), // orange-500/15
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x40F97316)), // ring
              ),
              child: Icon(icon, color: AppColors.brand, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xD9FFFFFF),
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
