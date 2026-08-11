import 'package:flutter/material.dart';
import '../../../../core/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
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

final _asistenciaRepoProvider = Provider<AsistenciaRepository>(
  (ref) => AsistenciaRepository(ApiClient.instance),
);

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

  Future<void> load({bool resetPage = false}) async {
    final p = resetPage ? 1 : state.page;
    state = state.copyWith(loading: true, clearError: true, page: p);
    try {
      final results = await Future.wait([
        _repo.list(pagina: p, limite: 20, fecha: state.fecha),
        _repo.resumen(fecha: state.fecha),
      ]);
      final page = results[0] as AsistenciaPage;
      final resumen = results[1] as AsistenciaResumen;
      state = state.copyWith(
        items: page.data,
        resumen: resumen,
        total: page.total,
        totalPages: page.totalPaginas,
        page: page.pagina,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setFecha(String f) {
    state = state.copyWith(fecha: f);
    load(resetPage: true);
  }

  void setPage(int p) {
    state = state.copyWith(page: p);
    load();
  }

  Future<void> crear({
    required String usuarioId,
    String? estado,
    String? turno,
    String? notas,
  }) async {
    await _repo.crear(
      usuarioId: usuarioId,
      fecha: state.fecha,
      estado: estado,
      turno: turno,
      notas: notas,
    );
    await load();
  }

  Future<void> editar(
    String id, {
    String? estado,
    String? turno,
    String? notas,
  }) async {
    await _repo.editar(id, estado: estado, turno: turno, notas: notas);
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

// ─── Screen ───────────────────────────────────────────────────────────────────

class AsistenciaScreen extends ConsumerStatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  ConsumerState<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends ConsumerState<AsistenciaScreen> {
  bool _showHistorial = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(_asistenciaProvider);
    final notifier = ref.read(_asistenciaProvider.notifier);
    final canCreate = auth.hasPermission('asistencia:crear');
    final canEdit = auth.hasPermission('asistencia:editar');
    final canDelete = auth.hasPermission('asistencia:eliminar');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Barra compacta: fecha + toggle (sin título duplicado)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      state.fecha,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              DateTime.tryParse(state.fecha) ?? DateTime.now(),
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
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryBorder),
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
                const SizedBox(height: 8),
                // Toggle Planilla / Historial
                Container(
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showHistorial = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_showHistorial
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !_showHistorial
                                  ? [
                                      const BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Planilla del día',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_showHistorial
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showHistorial = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _showHistorial
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _showHistorial
                                  ? [
                                      const BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Marcajes',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showHistorial
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ─── KPIs ───────────────────────────────────────────
          if (state.resumen != null && !state.loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _Chip(
                    'Total',
                    '${state.resumen!.totalEmpleados}',
                    AppColors.textSecondary,
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
          const SizedBox(height: 4),
          // ─── Contenido ──────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: state.loading
                  ? const AppLoading(key: ValueKey('l'))
                  : state.error != null
                  ? AppErrorState(
                      key: const ValueKey('e'),
                      message: state.error!,
                      onRetry: () => notifier.load(),
                    )
                  : state.items.isEmpty
                  ? const AppEmptyState(
                      key: ValueKey('empty'),
                      icon: Icons.calendar_today_outlined,
                      title: 'Sin empleados disponibles',
                    )
                  : !_showHistorial
                  ? _PlanillaView(
                      key: const ValueKey('planilla'),
                      items: state.items,
                      page: state.page,
                      totalPages: state.totalPages,
                      total: state.total,
                      canCreate: canCreate,
                      canEdit: canEdit,
                      canDelete: canDelete,
                      onPageChange: notifier.setPage,
                      onRegister: (emp) =>
                          _showRegistrar(context, emp, notifier, false),
                      onEdit: (emp) =>
                          _showRegistrar(context, emp, notifier, true),
                      onDelete: (emp) async {
                        if (emp.asistenciaId == null) return;
                        final ok = await ConfirmDialog.show(
                          context: context,
                          title: 'Eliminar asistencia',
                          description:
                              '¿Eliminar el registro de ${emp.username}?',
                          confirmLabel: 'Eliminar',
                          isDanger: true,
                        );
                        if (ok) await notifier.eliminar(emp.asistenciaId!);
                      },
                    )
                  : _MarcajesView(
                      key: const ValueKey('marcajes'),
                      items: state.items,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRegistrar(
    BuildContext context,
    AsistenciaPlanilla emp,
    _AsistenciaNotifier notifier,
    bool isEdit,
  ) {
    AppNav.push(
      context,
      _RegistrarSheet(
        emp: emp,
        isEdit: isEdit,
        onSaved: (estado, turno, notas) async {
          if (isEdit && emp.asistenciaId != null) {
            await notifier.editar(
              emp.asistenciaId!,
              estado: estado,
              turno: turno,
              notas: notas,
            );
          } else {
            await notifier.crear(
              usuarioId: emp.usuarioId,
              estado: estado,
              turno: turno,
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderLight),
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
  const _MarcajesView({super.key, required this.items});

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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderLight),
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
                    m['tipo'] == 'ENTRADA' || m['tipo'] == 'TARDANZA'
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
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
                          color: AppColors.textPrimary,
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
                        color: AppColors.textPrimary,
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
        c = AppColors.textTertiary;
        label = 'Día libre';
        break;
      default:
        c = AppColors.textTertiary;
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

// ─── Registrar sheet ──────────────────────────────────────────────────────────

class _RegistrarSheet extends StatefulWidget {
  final AsistenciaPlanilla emp;
  final bool isEdit;
  final Future<void> Function(String?, String?, String?) onSaved;
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
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      _estado = widget.emp.estado;
      _turnoCtrl.text = widget.emp.turno ?? '';
      _notasCtrl.text = widget.emp.notas ?? '';
    }
  }

  @override
  void dispose() {
    _turnoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
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
        _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SubPageAppBar(
        title: widget.isEdit ? 'Editar asistencia' : 'Registrar asistencia',
        subtitle: widget.emp.username,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Text(
              'Estado',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
                            ? AppColors.primarySurface
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: _estado == e.$1
                              ? AppColors.primaryBorder
                              : AppColors.border,
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
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Turno',
              hint: 'Ej. Apertura, Tarde',
              controller: _turnoCtrl,
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
