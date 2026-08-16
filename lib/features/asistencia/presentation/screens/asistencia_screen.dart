import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/asistencia_repository.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _asistenciaRepoProvider = Provider<AsistenciaRepository>(
  (ref) => AsistenciaRepository(ApiClient.instance),
);

final _turnosRepoProvider = Provider<TurnosRepository>(
  (ref) => TurnosRepository(ApiClient.instance),
);

// ─── Asistencia state / notifier ──────────────────────────────────────────────

class _AsistenciaState {
  final List<AsistenciaPlanilla> items;
  final AsistenciaResumen? resumen;
  final bool loading;
  final String? error;
  final int page, totalPages, total;
  final String fecha;

  _AsistenciaState({
    this.items = const [],
    this.resumen,
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
    String? fecha,
  }) : fecha = fecha ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

  _AsistenciaState copyWith({
    List<AsistenciaPlanilla>? items,
    AsistenciaResumen? resumen,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
    String? fecha,
  }) => _AsistenciaState(
    items: items ?? this.items,
    resumen: resumen ?? this.resumen,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
    fecha: fecha ?? this.fecha,
  );
}

class _AsistenciaNotifier extends StateNotifier<_AsistenciaState> {
  final AsistenciaRepository _repo;

  _AsistenciaNotifier(this._repo) : super(_AsistenciaState()) {
    load();
  }

  /// Realiza la carga real desde el backend usando el estado actual.
  /// No emite ningún estado intermedio — el caller ya debe haber
  /// establecido `loading: true` antes de invocar este método.
  Future<void> _fetchData() async {
    final fecha = state.fecha;
    final p = state.page;
    try {
      final results = await Future.wait([
        _repo.list(pagina: p, limite: 20, fecha: fecha),
        _repo.resumen(fecha: fecha),
      ]);
      final page = results[0] as AsistenciaPage;
      final resumen = results[1] as AsistenciaResumen;
      // Verificar que la fecha no cambió mientras esperábamos la respuesta.
      if (state.fecha != fecha) return;
      state = state.copyWith(
        items: page.data,
        resumen: resumen,
        total: page.total,
        totalPages: page.totalPaginas,
        page: page.pagina,
        loading: false,
      );
    } catch (e) {
      if (state.fecha != fecha) return;
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> load({bool resetPage = false}) async {
    // Un solo setState síncrono antes de la llamada al API.
    state = state.copyWith(
      loading: true,
      clearError: true,
      page: resetPage ? 1 : state.page,
    );
    await _fetchData();
  }

  void setFecha(String f) {
    // Merge fecha + loading + reset de página en UN solo setState para
    // evitar el flash intermedio que se percibe como "recarga extra".
    state = state.copyWith(fecha: f, loading: true, clearError: true, page: 1);
    _fetchData();
  }

  void setPage(int p) {
    state = state.copyWith(page: p, loading: true, clearError: true);
    _fetchData();
  }

  Future<void> crear({
    required String usuarioId,
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  }) async {
    await _repo.crear(
      usuarioId: usuarioId,
      fecha: state.fecha,
      estado: estado,
      turno: turno,
      horaEntrada: horaEntrada,
      horaSalida: horaSalida,
      notas: notas,
    );
    await load();
  }

  Future<void> editar(
    String id, {
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  }) async {
    await _repo.editar(
      id,
      estado: estado,
      turno: turno,
      horaEntrada: horaEntrada,
      horaSalida: horaSalida,
      notas: notas,
    );
    await load();
  }

  Future<void> eliminar(String id) async {
    await _repo.eliminar(id);
    await load();
  }
}

final _asistenciaProvider =
    StateNotifierProvider<_AsistenciaNotifier, _AsistenciaState>(
      (ref) => _AsistenciaNotifier(ref.watch(_asistenciaRepoProvider)),
    );

// ─── Turnos state / notifier ──────────────────────────────────────────────────

class _TurnosState {
  final List<Turno> items;
  final bool loading;
  final String? error;
  final int page, totalPages, total;

  const _TurnosState({
    this.items = const [],
    this.loading = true,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.total = 0,
  });

  _TurnosState copyWith({
    List<Turno>? items,
    bool? loading,
    String? error,
    bool clearError = false,
    int? page,
    int? totalPages,
    int? total,
  }) => _TurnosState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    total: total ?? this.total,
  );
}

class _TurnosNotifier extends StateNotifier<_TurnosState> {
  final TurnosRepository _repo;
  final String? _sedeId;

  _TurnosNotifier(this._repo, this._sedeId) : super(const _TurnosState()) {
    load();
  }

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final result = await _repo.list(pagina: p, limite: 25, sedeId: _sedeId);
      state = state.copyWith(
        items: result.data,
        total: result.total,
        totalPages: result.totalPaginas,
        page: result.pagina,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  Future<void> crear({
    required String sedeId,
    required String nombre,
    required int horaInicio,
    required int horaFin,
    int margenTardanza = 15,
  }) async {
    await _repo.crear(
      sedeId: sedeId,
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      margenTardanza: margenTardanza,
    );
    await load(resetPage: true);
  }

  Future<void> editar(
    String id, {
    String? nombre,
    int? horaInicio,
    int? horaFin,
    int? margenTardanza,
    bool? activo,
  }) async {
    await _repo.editar(
      id,
      nombre: nombre,
      horaInicio: horaInicio,
      horaFin: horaFin,
      margenTardanza: margenTardanza,
      activo: activo,
    );
    await load();
  }

  Future<void> eliminar(String id) async {
    await _repo.eliminar(id);
    await load();
  }
}

final _turnosProvider =
    StateNotifierProvider.family<_TurnosNotifier, _TurnosState, String?>(
      (ref, sedeId) => _TurnosNotifier(ref.watch(_turnosRepoProvider), sedeId),
    );

// ─── Main screen ──────────────────────────────────────────────────────────────

class AsistenciaScreen extends ConsumerStatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  ConsumerState<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends ConsumerState<AsistenciaScreen> {
  int _tabIndex = 0; // La web administrativa abre primero el kiosco QR.

  static const _tabs = [
    (icon: Icons.qr_code_2_rounded, label: 'Asistencia QR'),
    (icon: Icons.people_outline, label: 'Resumen del día'),
    (icon: Icons.login_rounded, label: 'Marcajes'),
    (icon: Icons.schedule_rounded, label: 'Turnos'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final canRead = auth.hasPermission('asistencia:leer');
    final isAttendanceAdmin =
        auth.user?.isAdmin == true || auth.user?.isSuperAdmin == true;

    // CAJERO, VENDEDORA y cualquier rol operativo no administran planillas:
    // su único flujo es escanear el QR de la sede para marcar entrada/salida.
    if (!isAttendanceAdmin || !canRead) {
      return _EmployeeAttendanceView(
        username: auth.user?.username ?? 'Empleado',
      );
    }

    final state = ref.watch(_asistenciaProvider);
    final notifier = ref.read(_asistenciaProvider.notifier);
    final sedeId = ref.watch(globalSedeIdProvider);

    final canCreate = auth.hasPermission('asistencia:crear');
    final canEdit = auth.hasPermission('asistencia:editar');
    final canDelete = auth.hasPermission('asistencia:eliminar');

    // Sede efectiva para crear/listar turnos.
    final effectiveTurnoSedeId = sedeId ?? auth.user?.sedeId;

    return Scaffold(
      backgroundColor: context.colors.background,
      // FAB "Nuevo turno" — solo visible en la pestaña Turnos.
      // Usar el floatingActionButton del Scaffold garantiza el posicionamiento
      // correcto respetando la SafeArea (navigation bar, etc.).
      floatingActionButton: (_tabIndex == 3 && canCreate)
          ? FloatingActionButton(
              heroTag: 'fab_turnos',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Nuevo turno',
              onPressed: () {
                final turnosNotifier = ref.read(
                  _turnosProvider(sedeId).notifier,
                );
                AppNav.push(
                  context,
                  _TurnoFormSheet(
                    sedeId: effectiveTurnoSedeId ?? '',
                    onSaved:
                        (nombre, horaInicio, horaFin, margenTardanza) async {
                          await turnosNotifier.crear(
                            sedeId: effectiveTurnoSedeId ?? '',
                            nombre: nombre,
                            horaInicio: horaInicio,
                            horaFin: horaFin,
                            margenTardanza: margenTardanza,
                          );
                        },
                  ),
                );
              },
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          // ─── Top bar con fecha + tabs ──────────────────────────────────
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                // Fecha + picker (solo en tabs de asistencia)
                if (_tabIndex == 1 || _tabIndex == 2)
                  Row(
                    children: [
                      Text(
                        state.fecha,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.tryParse(state.fecha) ??
                                DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            notifier.setFecha(
                              DateFormat('yyyy-MM-dd').format(picked),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: context.colors.primaryBorder,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Fecha',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_tabIndex == 1 || _tabIndex == 2) const SizedBox(height: 8),
                // Tab bar
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_tabs.length, (i) {
                      final t = _tabs[i];
                      final active = _tabIndex == i;
                      return GestureDetector(
                        onTap: () => setState(() => _tabIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(
                            right: i < _tabs.length - 1 ? 4 : 0,
                            bottom: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? context.colors.primarySurface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: active
                                  ? context.colors.primaryBorder
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                t.icon,
                                size: 14,
                                color: active
                                    ? AppColors.primary
                                    : context.colors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: active
                                      ? AppColors.primary
                                      : context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          // ─── KPIs (solo planilla) ──────────────────────────────────────
          if (_tabIndex == 1 && state.resumen != null && !state.loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _Chip(
                    'Total',
                    '${state.resumen!.totalEmpleados}',
                    context.colors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    'Presentes',
                    '${state.resumen!.presente}',
                    AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    'Ausentes',
                    '${state.resumen!.ausente}',
                    AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    'Tardanza',
                    '${state.resumen!.tardanza}',
                    AppColors.warning,
                  ),
                ],
              ),
            ),
          if (_tabIndex == 1 && state.resumen != null && !state.loading)
            const SizedBox(height: 4),
          // ─── Contenido ────────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                // Tab 0: QR Kiosco
                _QrKioscoTab(sedeId: sedeId),
                // Tab 1: Planilla
                _planillaContent(
                  state,
                  notifier,
                  canCreate,
                  canEdit,
                  canDelete,
                ),
                // Tab 2: Marcajes
                _marcajesContent(state),
                // Tab 3: Turnos
                _TurnosTab(
                  sedeId: sedeId,
                  canEdit: canEdit,
                  canDelete: canDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planillaContent(
    _AsistenciaState state,
    _AsistenciaNotifier notifier,
    bool canCreate,
    bool canEdit,
    bool canDelete,
  ) {
    if (state.loading) return const AppLoading(key: ValueKey('l'));
    if (state.error != null) {
      return AppErrorState(
        key: const ValueKey('e'),
        message: state.error!,
        onRetry: () => notifier.load(),
      );
    }
    if (state.items.isEmpty) {
      return const AppEmptyState(
        key: ValueKey('empty'),
        icon: Icons.calendar_today_outlined,
        title: 'Sin empleados disponibles',
      );
    }
    return _PlanillaView(
      items: state.items,
      page: state.page,
      totalPages: state.totalPages,
      total: state.total,
      canCreate: canCreate,
      canEdit: canEdit,
      canDelete: canDelete,
      onPageChange: notifier.setPage,
      onRegister: (emp) => _showRegistrar(emp, notifier, false),
      onEdit: (emp) => _showRegistrar(emp, notifier, true),
      onDelete: (emp) async {
        if (emp.asistenciaId == null) return;
        final ok = await ConfirmDialog.show(
          context: context,
          title: 'Eliminar asistencia',
          description: '¿Eliminar el registro de ${emp.username}?',
          confirmLabel: 'Eliminar',
          isDanger: true,
        );
        if (ok) await notifier.eliminar(emp.asistenciaId!);
      },
    );
  }

  Widget _marcajesContent(_AsistenciaState state) {
    if (state.loading) return const AppLoading(key: ValueKey('lm'));
    if (state.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.login_outlined,
        title: 'Sin marcajes',
        description: 'No hay entradas o salidas para esta fecha.',
      );
    }
    return _MarcajesView(items: state.items);
  }

  void _showRegistrar(
    AsistenciaPlanilla emp,
    _AsistenciaNotifier notifier,
    bool isEdit,
  ) {
    AppNav.push(
      context,
      _RegistrarSheet(
        emp: emp,
        isEdit: isEdit,
        onSaved: (estado, turno, horaEntrada, horaSalida, notas) async {
          if (isEdit && emp.asistenciaId != null) {
            await notifier.editar(
              emp.asistenciaId!,
              estado: estado,
              turno: turno,
              horaEntrada: horaEntrada,
              horaSalida: horaSalida,
              notas: notas,
            );
          } else {
            await notifier.crear(
              usuarioId: emp.usuarioId,
              estado: estado,
              turno: turno,
              horaEntrada: horaEntrada,
              horaSalida: horaSalida,
              notas: notas,
            );
          }
        },
      ),
    );
  }
}

// ─── Planilla view ────────────────────────────────────────────────────────────

class _PlanillaView extends StatelessWidget {
  final List<AsistenciaPlanilla> items;
  final int page, totalPages, total;
  final bool canCreate, canEdit, canDelete;
  final ValueChanged<int> onPageChange;
  final ValueChanged<AsistenciaPlanilla> onRegister, onEdit;
  final ValueChanged<AsistenciaPlanilla> onDelete;

  const _PlanillaView({
    super.key,
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.onPageChange,
    required this.onRegister,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    itemCount: items.length + 1,
    itemBuilder: (_, i) {
      if (i == items.length) {
        return AppPagination(
          page: page,
          totalPages: totalPages,
          total: total,
          onPageChange: onPageChange,
        );
      }
      final emp = items[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.colors.borderLight),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.avatarColor(
                  emp.username,
                ).withOpacity(0.15),
                child: Text(
                  _initials(emp.username),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.avatarColor(emp.username),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emp.username, style: AppTextStyles.titleMedium),
                    Text(
                      '${emp.rol}${emp.turno != null ? " · ${emp.turno}" : ""}',
                      style: AppTextStyles.bodySmall,
                    ),
                    if (emp.horaEntrada != null)
                      Text(
                        'Entrada: ${_fmtHour(emp.horaEntrada!)}',
                        style: AppTextStyles.labelSmall,
                      ),
                    if (emp.horaSalida != null)
                      Text(
                        'Salida: ${_fmtHour(emp.horaSalida!)}',
                        style: AppTextStyles.labelSmall,
                      ),
                    if (emp.horasTrabajadas != null)
                      Text(
                        '${emp.horasTrabajadas!.toStringAsFixed(1)}h trabajadas',
                        style: AppTextStyles.labelSmall,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(estado: emp.estado),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (emp.asistenciaId == null && canCreate)
                        _IconBtn(
                          icon: Icons.add_rounded,
                          color: AppColors.primary,
                          onTap: () => onRegister(emp),
                        ),
                      if (emp.asistenciaId != null && canEdit)
                        _IconBtn(
                          icon: Icons.edit_rounded,
                          color: AppColors.primary,
                          onTap: () => onEdit(emp),
                        ),
                      if (emp.asistenciaId != null && canDelete)
                        _IconBtn(
                          icon: Icons.delete_rounded,
                          color: AppColors.error,
                          onTap: () => onDelete(emp),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  String _initials(String u) {
    final p = u.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : u.substring(0, 2).toUpperCase();
  }

  String _fmtHour(String iso) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: color),
    ),
  );
}

// ─── Marcajes view ────────────────────────────────────────────────────────────

class _MarcajesView extends StatelessWidget {
  final List<AsistenciaPlanilla> items;
  const _MarcajesView({required this.items});

  @override
  Widget build(BuildContext context) {
    final marcajes = <Map<String, String>>[];
    for (final emp in items) {
      if (emp.horaEntrada != null) {
        marcajes.add({
          'empleado': emp.username,
          'rol': emp.rol,
          'tipo': emp.estado == 'TARDANZA' ? 'TARDANZA' : 'ENTRADA',
          'hora': emp.horaEntrada!,
          'detalle': 'Registro de entrada',
        });
      }
      if (emp.horaSalida != null) {
        marcajes.add({
          'empleado': emp.username,
          'rol': emp.rol,
          'tipo': 'SALIDA',
          'hora': emp.horaSalida!,
          'detalle': 'Registro de salida',
        });
      }
    }
    marcajes.sort((a, b) => a['hora']!.compareTo(b['hora']!));

    if (marcajes.isEmpty) {
      return const AppEmptyState(
        icon: Icons.login_outlined,
        title: 'Sin marcajes',
        description: 'No hay entradas o salidas registradas para esta fecha.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: marcajes.length,
      itemBuilder: (_, i) {
        final m = marcajes[i];
        final color = m['tipo'] == 'ENTRADA'
            ? AppColors.success
            : m['tipo'] == 'TARDANZA'
            ? AppColors.warning
            : AppColors.primary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: context.colors.borderLight),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    m['tipo'] == 'SALIDA'
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['empleado']!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${m['rol']} · ${m['detalle']}',
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m['tipo']!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _fmtHour(m['hora']!),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtHour(String iso) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}

// ─── QR Kiosco tab ────────────────────────────────────────────────────────────

class _QrKioscoTab extends ConsumerStatefulWidget {
  final String? sedeId;
  const _QrKioscoTab({required this.sedeId});

  @override
  ConsumerState<_QrKioscoTab> createState() => _QrKioscoTabState();
}

class _QrKioscoTabState extends ConsumerState<_QrKioscoTab> {
  QrKioscoResponse? _qr;
  bool _loading = false;
  String? _error;
  Timer? _refreshTimer;
  int _secondsLeft = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadQr();
  }

  @override
  void didUpdateWidget(_QrKioscoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sedeId != widget.sedeId) _loadQr();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQr() async {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(_asistenciaRepoProvider);
      final qr = await repo.qrKiosco(sedeId: widget.sedeId);
      setState(() {
        _qr = qr;
        _loading = false;
        _secondsLeft = qr.expiraEnSegundos;
      });
      // Refresh QR before it expires (at 30s or at expiry - 5s)
      final refreshAfter = qr.expiraEnSegundos > 35
          ? 30
          : (qr.expiraEnSegundos - 5).clamp(5, 300);
      _refreshTimer = Timer(Duration(seconds: refreshAfter), _loadQr);
      // Countdown timer
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          if (_secondsLeft > 0) _secondsLeft--;
        });
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isSuperAdmin = auth.user?.isSuperAdmin == true;

    if (isSuperAdmin && widget.sedeId == null) {
      return const AppEmptyState(
        icon: Icons.store_outlined,
        title: 'Selecciona una sede',
        description:
            'Como SuperAdmin, selecciona una sede en la barra superior para generar el QR.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        children: [
          // QR Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: context.colors.borderLight),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QR Kiosco',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    if (_qr != null)
                      Text(
                        '${_secondsLeft}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: _secondsLeft < 10
                              ? AppColors.error
                              : context.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _loadQr,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SizedBox(
                    height: 260,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error al generar QR',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadQr,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                else if (_qr != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _qr!.token,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                if (_qr != null) ...[
                  const SizedBox(height: 12),
                  Text('Fecha: ${_qr!.fecha}', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Los empleados escanean este código para marcar asistencia',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Llegadas de hoy
          _TodayArrivalsSection(),
        ],
      ),
    );
  }
}

// ─── Asistencia de empleado: solo escáner ────────────────────────────────────

class _EmployeeAttendanceView extends StatelessWidget {
  final String username;

  const _EmployeeAttendanceView({required this.username});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, $username',
              style: AppTextStyles.headlineLarge.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra tu entrada o salida escaneando el QR vigente de tu sede.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: context.colors.border),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 112,
                      color: AppColors.brand.withValues(alpha: 0.9),
                    ),
                    Positioned(
                      bottom: 20,
                      child: Text(
                        'ENTRADA / SALIDA',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: context.colors.textTertiary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _openScanner(context),
                icon: const Icon(Icons.camera_alt_outlined, size: 19),
                label: const Text('ESCANEAR QR DE ASISTENCIA'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'El QR debe pertenecer a tu sede y estar vigente.',
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openScanner(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;
    if (status.isGranted) {
      AppNav.push(context, const _QrScannerScreen(sedeId: null));
      return;
    }
    final permanentlyDenied = status.isPermanentlyDenied;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          permanentlyDenied ? 'Cámara bloqueada' : 'Permiso necesario',
        ),
        content: Text(
          permanentlyDenied
              ? 'Habilitaste el permiso de cámara para esta app. Para escanear el QR de asistencia, actívalo desde los ajustes del dispositivo.'
              : 'La app necesita acceso a la cámara para escanear el QR de asistencia. Se solicitará el permiso al abrir el escáner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(permanentlyDenied ? 'Abrir ajustes' : 'Solicitar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (permanentlyDenied) {
      await openAppSettings();
    } else {
      AppNav.push(context, const _QrScannerScreen(sedeId: null));
    }
  }
}

// ─── Today arrivals (live list in QR kiosco) ─────────────────────────────────

class _TodayArrivalsSection extends ConsumerStatefulWidget {
  const _TodayArrivalsSection();

  @override
  ConsumerState<_TodayArrivalsSection> createState() =>
      _TodayArrivalsSectionState();
}

class _TodayArrivalsSectionState extends ConsumerState<_TodayArrivalsSection> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.read(_asistenciaProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_asistenciaProvider);
    final arrivals = state.items.where((e) => e.horaEntrada != null).toList()
      ..sort((a, b) => (b.horaEntrada ?? '').compareTo(a.horaEntrada ?? ''));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.borderLight),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text('Llegadas de hoy', style: AppTextStyles.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${arrivals.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (arrivals.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Nadie ha llegado aún',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            )
          else
            ...arrivals
                .take(10)
                .map(
                  (emp) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.avatarColor(
                            emp.username,
                          ).withOpacity(0.15),
                          child: Text(
                            emp.username.isNotEmpty
                                ? emp.username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.avatarColor(emp.username),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emp.username,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              Text(emp.rol, style: AppTextStyles.labelSmall),
                            ],
                          ),
                        ),
                        _StatusBadge(estado: emp.estado),
                        const SizedBox(width: 8),
                        Text(
                          _fmtHour(emp.horaEntrada!),
                          style: AppTextStyles.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  String _fmtHour(String iso) {
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}

// ─── QR Scanner screen ────────────────────────────────────────────────────────

class _QrScannerScreen extends ConsumerStatefulWidget {
  final String? sedeId;
  const _QrScannerScreen({required this.sedeId});

  @override
  ConsumerState<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<_QrScannerScreen> {
  late final MobileScannerController _ctrl;
  bool _processing = false;
  String? _resultMessage;
  bool _success = false;
  bool _starting = false;
  bool _torchOn = false;
  MobileScannerException? _cameraError;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
      // El arranque se controla manualmente para que la cámara solo se inicie
      // con el widget ya montado y el permiso concedido. autoStart junto a una
      // solicitud de permiso en paralelo provoca "no se pudo iniciar la cámara"
      // en dispositivos reales.
      autoStart: false,
    );
    // Mantiene _cameraError sincronizado con el estado interno del controlador
    // (un arranque fallido no lanza excepción: expone el error en value.error).
    _ctrl.addListener(_onControllerValue);
    // El primer arranque se hace tras montar el widget MobileScanner.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerValue);
    _ctrl.dispose();
    super.dispose();
  }

  void _onControllerValue() {
    if (!mounted) return;
    final error = _ctrl.value.error;
    if (error != null || _cameraError != null) {
      setState(() => _cameraError = error);
    }
  }

  Future<void> _startCamera() async {
    if (!mounted || _starting) return;
    setState(() => _starting = true);
    try {
      if (!_ctrl.value.isRunning) {
        // start() solicita el permiso de cámara por sí mismo si no está
        // concedido (muestra el diálogo del sistema y espera la respuesta).
        await _ctrl.start();
      }
    } catch (e) {
      if (mounted && _ctrl.value.error == null) {
        setState(() {
          _cameraError = e is MobileScannerException
              ? e
              : MobileScannerException(
                  errorCode: MobileScannerErrorCode.genericError,
                  errorDetails: MobileScannerErrorDetails(message: '$e'),
                );
        });
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _retryCamera() async {
    if (!mounted) return;
    await _ctrl.stop().catchError((_) {});
    await _startCamera();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _processing = true;
      _resultMessage = null;
    });
    await _ctrl.stop();
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(_asistenciaRepoProvider);
      final result = await repo.marcar(barcode.rawValue!);
      if (!mounted) return;
      setState(() {
        _success = true;
        _resultMessage =
            '${result.tipo == 'ENTRADA' ? '✓ Entrada' : '✓ Salida'} registrada\n${result.username} — ${result.mensaje}';
      });
      // Reload planilla
      ref.read(_asistenciaProvider.notifier).load();
      // Auto-close after 2s
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _resultMessage = e.toString().replaceFirst('Exception: ', '');
        _processing = false;
      });
      // Restart scanner after error
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        setState(() => _resultMessage = null);
        _startCamera();
      });
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _ctrl.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Linterna no disponible: se ignora silenciosamente.
    }
  }

  @override
  Widget build(BuildContext context) {
    final showScanUi = _cameraError == null && !_starting;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear QR de asistencia'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (ctx, error) {
              _cameraError = error;
              return _ScannerErrorView(
                error: error,
                starting: _starting,
                onRetry: _retryCamera,
                onOpenSettings: () async {
                  await openAppSettings();
                  await _retryCamera();
                },
              );
            },
            placeholderBuilder: (ctx) => ColoredBox(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            ),
          ),
          // Scanning overlay (solo cuando la cámara está operativa)
          if (showScanUi)
            Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          // Instruction + torch controls
          if (showScanUi)
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Apunta al QR del kiosco de tu sede',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _toggleTorch,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _torchOn
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Result overlay
          if (_resultMessage != null)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _success ? AppColors.success : AppColors.error,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _success ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _resultMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Processing indicator
          if (_processing && _resultMessage == null)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Vista de error del escáner: explica el problema y da acciones para resolverlo.
class _ScannerErrorView extends StatelessWidget {
  final MobileScannerException error;
  final bool starting;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  const _ScannerErrorView({
    required this.error,
    required this.starting,
    required this.onRetry,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;

    final title = permissionDenied
        ? 'Permiso de cámara denegado'
        : unsupported
        ? 'Cámara no disponible'
        : 'No se pudo iniciar la cámara';

    final description = permissionDenied
        ? 'Para escanear el QR de asistencia, BarBeer necesita acceso a la cámara. Puedes habilitarlo desde los ajustes del dispositivo.'
        : unsupported
        ? 'Este dispositivo no tiene una cámara compatible con el escáner de QR.'
        : 'Ocurrió un error al iniciar la cámara. Revisa que ninguna otra app la esté usando e inténtalo de nuevo.';

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: starting
                ? const CircularProgressIndicator(color: Colors.white70)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        permissionDenied
                            ? Icons.no_photography_outlined
                            : Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: permissionDenied
                            ? onOpenSettings
                            : unsupported
                            ? () => Navigator.of(context).pop()
                            : onRetry,
                        icon: Icon(
                          permissionDenied
                              ? Icons.settings_outlined
                              : unsupported
                              ? Icons.arrow_back_rounded
                              : Icons.refresh_rounded,
                          size: 18,
                        ),
                        label: Text(
                          permissionDenied
                              ? 'Abrir ajustes'
                              : unsupported
                              ? 'Volver'
                              : 'Reintentar',
                        ),
                      ),
                      if (permissionDenied) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onRetry,
                          child: const Text(
                            'Volver a intentar',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Turnos tab ───────────────────────────────────────────────────────────────

class _TurnosTab extends ConsumerWidget {
  final String? sedeId;
  final bool canEdit, canDelete;
  const _TurnosTab({
    required this.sedeId,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_turnosProvider(sedeId));
    final notifier = ref.read(_turnosProvider(sedeId).notifier);
    // Mapa sedeId → nombre para mostrar la sede en cada tile
    // (solo disponible para SUPERADMIN que carga la lista completa de sedes).
    final sedesMap = {
      for (final s
          in ref.watch(sedeScopeOptionsProvider).valueOrNull ??
              const <SedeScopeOption>[])
        s.id: s.nombre,
    };

    Widget content;
    if (state.loading) {
      content = const AppLoading();
    } else if (state.error != null) {
      content = AppErrorState(
        message: state.error!,
        onRetry: () => notifier.load(),
      );
    } else if (state.items.isEmpty) {
      content = const AppEmptyState(
        icon: Icons.schedule_outlined,
        title: 'Sin turnos',
        description: 'Crea el primer turno para esta sede.',
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: state.items.length + 1,
        itemBuilder: (_, i) {
          if (i == state.items.length) {
            return AppPagination(
              page: state.page,
              totalPages: state.totalPages,
              total: state.total,
              onPageChange: notifier.setPage,
            );
          }
          final turno = state.items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.colors.borderLight),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                turno.nombre,
                                style: AppTextStyles.titleMedium,
                              ),
                            ),
                            if (turno.cruzaMedianoche)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CRUZA MEDIANOCHE',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Nombre de sede: visible cuando hay varias (SUPERADMIN sin filtro).
                        if (sedesMap.containsKey(turno.sedeId))
                          Text(
                            sedesMap[turno.sedeId]!,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        Text(
                          '${turno.horaInicioLabel} – ${turno.horaFinLabel}  ·  Margen: ${turno.margenTardanza} min',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _StatusPill(activo: turno.activo),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            _IconBtn(
                              icon: Icons.edit_rounded,
                              color: AppColors.primary,
                              onTap: () => AppNav.push(
                                context,
                                _TurnoFormSheet(
                                  sedeId: turno.sedeId,
                                  turno: turno,
                                  onSaved:
                                      (
                                        nombre,
                                        horaInicio,
                                        horaFin,
                                        margenTardanza,
                                      ) async {
                                        await notifier.editar(
                                          turno.id,
                                          nombre: nombre,
                                          horaInicio: horaInicio,
                                          horaFin: horaFin,
                                          margenTardanza: margenTardanza,
                                        );
                                      },
                                ),
                              ),
                            ),
                          if (canEdit)
                            _IconBtn(
                              icon: turno.activo
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                              color: turno.activo
                                  ? AppColors.success
                                  : context.colors.textTertiary,
                              onTap: () async {
                                await notifier.editar(
                                  turno.id,
                                  activo: !turno.activo,
                                );
                              },
                            ),
                          if (canDelete)
                            _IconBtn(
                              icon: Icons.delete_rounded,
                              color: AppColors.error,
                              onTap: () async {
                                final ok = await ConfirmDialog.show(
                                  context: context,
                                  title: 'Eliminar turno',
                                  description:
                                      '¿Eliminar "${turno.nombre}"? Si tiene jornadas asociadas, solo se desactivará.',
                                  confirmLabel: 'Eliminar',
                                  isDanger: true,
                                );
                                if (ok) await notifier.eliminar(turno.id);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // El FAB "Nuevo turno" está en el Scaffold padre (AsistenciaScreen),
    // que lo posiciona correctamente respetando SafeArea.
    return content;
  }
}

class _StatusPill extends StatelessWidget {
  final bool activo;
  const _StatusPill({required this.activo});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: (activo ? AppColors.success : context.colors.textTertiary)
          .withOpacity(0.12),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      activo ? 'Activo' : 'Inactivo',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: activo ? AppColors.success : context.colors.textTertiary,
      ),
    ),
  );
}

// ─── Turno form sheet (create / edit) ────────────────────────────────────────

class _TurnoFormSheet extends StatefulWidget {
  final String sedeId;
  final Turno? turno;
  final Future<void> Function(
    String nombre,
    int horaInicio,
    int horaFin,
    int margenTardanza,
  )
  onSaved;

  const _TurnoFormSheet({
    required this.sedeId,
    required this.onSaved,
    this.turno,
  });

  @override
  State<_TurnoFormSheet> createState() => _TurnoFormSheetState();
}

class _TurnoFormSheetState extends State<_TurnoFormSheet> {
  final _nombreCtrl = TextEditingController();
  final _margenCtrl = TextEditingController();
  TimeOfDay _horaInicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 16, minute: 0);
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.turno != null) {
      final t = widget.turno!;
      _nombreCtrl.text = t.nombre;
      _horaInicio = TimeOfDay(
        hour: t.horaInicio ~/ 60,
        minute: t.horaInicio % 60,
      );
      _horaFin = TimeOfDay(hour: t.horaFin ~/ 60, minute: t.horaFin % 60);
      _margenCtrl.text = t.margenTardanza.toString();
    } else {
      _margenCtrl.text = '15';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _margenCtrl.dispose();
    super.dispose();
  }

  int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  bool get _cruzaMedianoche =>
      _timeToMinutes(_horaFin) < _timeToMinutes(_horaInicio);

  Future<void> _pickTime(bool isInicio) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isInicio ? _horaInicio : _horaFin,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _horaInicio = picked;
        } else {
          _horaFin = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    final margen = int.tryParse(_margenCtrl.text.trim()) ?? 15;
    if (margen < 0 || margen > 240) {
      setState(() => _error = 'El margen debe estar entre 0 y 240 minutos');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaved(
        nombre,
        _timeToMinutes(_horaInicio),
        _timeToMinutes(_horaFin),
        margen,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: widget.turno != null ? 'Editar turno' : 'Nuevo turno',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nombre del turno *',
              hint: 'Ej. Mañana, Tarde, Noche',
              controller: _nombreCtrl,
            ),
            const SizedBox(height: 16),
            // Hora inicio + fin
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hora de inicio',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickTime(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.backgroundAlt,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(_horaInicio),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hora de fin',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _pickTime(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.backgroundAlt,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fmt(_horaFin),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_cruzaMedianoche) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.brightness_3,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Este turno cruza medianoche',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              label: 'Margen de tardanza (minutos)',
              hint: 'Ej. 15',
              controller: _margenCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            PrimaryButton(
              label: widget.turno != null ? 'Guardar cambios' : 'Crear turno',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Registrar / editar asistencia sheet ─────────────────────────────────────

class _RegistrarSheet extends StatefulWidget {
  final AsistenciaPlanilla emp;
  final bool isEdit;
  final Future<void> Function(
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  )
  onSaved;

  const _RegistrarSheet({
    required this.emp,
    required this.isEdit,
    required this.onSaved,
  });

  @override
  State<_RegistrarSheet> createState() => _RegistrarSheetState();
}

class _RegistrarSheetState extends State<_RegistrarSheet> {
  String _estado = 'PRESENTE';
  final _turnoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  DateTime? _horaEntrada;
  DateTime? _horaSalida;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _estado = widget.emp.estado;
      _turnoCtrl.text = widget.emp.turno ?? '';
      _notasCtrl.text = widget.emp.notas ?? '';
      if (widget.emp.horaEntrada != null) {
        _horaEntrada = DateTime.tryParse(widget.emp.horaEntrada!);
      }
      if (widget.emp.horaSalida != null) {
        _horaSalida = DateTime.tryParse(widget.emp.horaSalida!);
      }
    }
  }

  @override
  void dispose() {
    _turnoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isEntrada) async {
    final now = DateTime.now();
    final initial = isEntrada ? (_horaEntrada ?? now) : (_horaSalida ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isEntrada) {
        _horaEntrada = combined;
      } else {
        _horaSalida = combined;
      }
    });
  }

  void _clearDateTime(bool isEntrada) {
    setState(() {
      if (isEntrada) {
        _horaEntrada = null;
      } else {
        _horaSalida = null;
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaved(
        _estado,
        _turnoCtrl.text.trim().isEmpty ? null : _turnoCtrl.text.trim(),
        _horaEntrada?.toIso8601String(),
        _horaSalida?.toIso8601String(),
        _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: SubPageAppBar(
        title: widget.isEdit ? 'Editar asistencia' : 'Registrar asistencia',
        subtitle: widget.emp.username,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado selector
            Text(
              'Estado',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  ('PRESENTE', 'Presente'),
                  ('TARDANZA', 'Tardanza'),
                  ('AUSENTE', 'Ausente'),
                  ('DIA_LIBRE', 'Día libre'),
                ])
                  GestureDetector(
                    onTap: () => setState(() => _estado = e.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _estado == e.$1
                            ? context.colors.primarySurface
                            : context.colors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: _estado == e.$1
                              ? context.colors.primaryBorder
                              : context.colors.border,
                        ),
                      ),
                      child: Text(
                        e.$2,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _estado == e.$1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _estado == e.$1
                              ? AppColors.primary
                              : context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Turno',
              hint: 'Ej. Apertura, Tarde',
              controller: _turnoCtrl,
            ),
            const SizedBox(height: 14),
            // Hora de entrada
            _DateTimePickerRow(
              label: 'Hora de entrada',
              value: _horaEntrada,
              onTap: () => _pickDateTime(true),
              onClear: _horaEntrada != null ? () => _clearDateTime(true) : null,
            ),
            const SizedBox(height: 12),
            // Hora de salida
            _DateTimePickerRow(
              label: 'Hora de salida',
              value: _horaSalida,
              onTap: () => _pickDateTime(false),
              onClear: _horaSalida != null ? () => _clearDateTime(false) : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Notas',
              hint: 'Opcional',
              controller: _notasCtrl,
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: widget.isEdit ? 'Guardar cambios' : 'Registrar',
              onPressed: _saving ? null : _submit,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DateTime picker row ─────────────────────────────────────────────────────

class _DateTimePickerRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateTimePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = value != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(value!.toLocal())
        : 'No asignado';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.backgroundAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: value != null
                      ? AppColors.primary
                      : context.colors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fmt,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: value != null
                          ? context.colors.textPrimary
                          : context.colors.textTertiary,
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: context.colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String estado;
  const _StatusBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (estado) {
      case 'PRESENTE':
        c = AppColors.success;
        label = 'Presente';
        break;
      case 'TARDANZA':
        c = AppColors.warning;
        label = 'Tardanza';
        break;
      case 'AUSENTE':
        c = AppColors.error;
        label = 'Ausente';
        break;
      case 'DIA_LIBRE':
        c = context.colors.textTertiary;
        label = 'Día libre';
        break;
      default:
        c = context.colors.textTertiary;
        label = estado;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    ),
  );
}
