import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SucursalesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> sedes;
  final int total, page, totalPages;
  const SucursalesState({
    this.isLoading = false,
    this.error,
    this.sedes = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
  });
  SucursalesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? sedes,
    int? total,
    int? page,
    int? totalPages,
  }) => SucursalesState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    sedes: sedes ?? this.sedes,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
  );
}

class SucursalesNotifier extends StateNotifier<SucursalesState> {
  final ApiClient _api;
  SucursalesNotifier(this._api) : super(const SucursalesState()) {
    load();
  }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final r = await _api.get(
        ApiConstants.establishments,
        queryParameters: {'pagina': page, 'limite': 25},
      );
      final d = r.data as Map;
      state = state.copyWith(
        isLoading: false,
        sedes: List<Map<String, dynamic>>.from(d['data'] ?? []),
        total: d['total'] as int? ?? 0,
        page: d['pagina'] as int? ?? 1,
        totalPages: d['totalPaginas'] as int? ?? 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getSede(String id) async {
    try {
      final r = await _api.get(ApiConstants.establishment(id));
      return r.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> createSede(Map<String, dynamic> data) async {
    await _api.post(ApiConstants.establishments, data: data);
    await load(page: state.page);
  }

  Future<void> updateSede(String id, Map<String, dynamic> data) async {
    await _api.patch(ApiConstants.establishment(id), data: data);
    await load(page: state.page);
  }

  Future<void> deleteSede(String id) async {
    await _api.delete(ApiConstants.establishment(id));
    await load(page: state.page);
  }
}

final sucursalesProvider =
    StateNotifierProvider<SucursalesNotifier, SucursalesState>(
      (ref) => SucursalesNotifier(ApiClient.instance),
    );

class SucursalesScreen extends ConsumerWidget {
  const SucursalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sucursalesProvider);
    final auth = ref.watch(authProvider);
    final canCreate = auth.hasPermission('establecimientos:crear');

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              heroTag: 'sucursales_fab',
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              onPressed: () => _showForm(context, ref, null),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(sucursalesProvider.notifier).load(),
        child: Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? AppLoadingIndicator()
                  : state.error != null
                  ? AppErrorState(
                      message: state.error!,
                      onActionPressed: () =>
                          ref.read(sucursalesProvider.notifier).load(),
                    )
                  : state.sedes.isEmpty
                  ? AppEmptyState(
                      icon: Icons.store_outlined,
                      title: 'Sin sucursales',
                      message: 'No hay sucursales registradas',
                    )
                  : ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.count(
                            crossAxisCount:
                                MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _StatChip(
                                label: 'Total',
                                value: '${state.total}',
                                color: AppColors.primary,
                              ),
                              _StatChip(
                                label: 'Activas',
                                value:
                                    '${state.sedes.where((s) => s['activo'] == true).length}',
                                color: AppColors.success,
                              ),
                              _StatChip(
                                label: 'Inactivas',
                                value:
                                    '${state.sedes.where((s) => s['activo'] != true).length}',
                                color: context.colors.textTertiary,
                              ),
                              _StatChip(
                                label: 'Usuarios',
                                value:
                                    '${state.sedes.fold<int>(0, (total, sede) => total + ((sede['_count'] as Map?)?['usuarios'] as int? ?? 0))}',
                                color: AppColors.info,
                              ),
                            ],
                          ),
                        ),
                        for (final sede in state.sedes)
                          _SedeTile(
                            sede: sede,
                            auth: auth,
                            onDetail: () =>
                                _showDetail(context, ref, sede['id'] as String),
                            onEdit: () => _showForm(context, ref, sede),
                            onDelete: () => _deleteSede(context, ref, sede),
                          ),
                        AppPagination(
                          page: state.page,
                          totalPages: state.totalPages,
                          total: state.total,
                          onPageChange: (p) => ref
                              .read(sucursalesProvider.notifier)
                              .load(page: p),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final sede = await ref.read(sucursalesProvider.notifier).getSede(id);
    if (sede == null || !context.mounted) return;
    AppNav.push(
      context,
      _SedeDetailScreen(
        sede: sede,
        canEdit: ref
            .read(authProvider)
            .hasPermission('establecimientos:editar'),
        canDelete: ref
            .read(authProvider)
            .hasPermission('establecimientos:eliminar'),
        onEdit: () => _showForm(context, ref, sede),
        onDelete: () => _deleteSede(context, ref, sede),
      ),
    );
  }

  void _showForm(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? sede,
  ) {
    AppNav.push(
      context,
      _SedeForm(
        sede: sede,
        onSave: (data) async {
          if (sede == null) {
            await ref.read(sucursalesProvider.notifier).createSede(data);
          } else {
            await ref
                .read(sucursalesProvider.notifier)
                .updateSede(sede['id'] as String, data);
          }
        },
      ),
    );
  }

  Future<void> _deleteSede(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> sede,
  ) async {
    final userCount = sede['_count']?['usuarios'] as int? ?? 0;
    if (userCount > 0) {
      AppFeedback.error(
        context,
        'No se puede eliminar: tiene usuarios asignados',
      );
      return;
    }
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Eliminar sucursal',
      description:
          'Se eliminara la sucursal "${sede['nombre']}". Esta accion no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDanger: true,
    );
    if (ok && context.mounted) {
      try {
        await ref
            .read(sucursalesProvider.notifier)
            .deleteSede(sede['id'] as String);
        if (context.mounted) AppFeedback.success(context, 'Sucursal eliminada');
      } catch (e) {
        if (context.mounted) AppFeedback.error(context, 'Error: $e');
      }
    }
  }
}

class _SedeTile extends StatelessWidget {
  final Map<String, dynamic> sede;
  final AuthState auth;
  final VoidCallback onDetail, onEdit, onDelete;
  const _SedeTile({
    required this.sede,
    required this.auth,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = sede['nombre'] as String? ?? '';
    final direccion = sede['direccion'] as String?;
    final telefono = sede['telefono'] as String?;
    final codigoSede = sede['codigoSede'] as String? ?? '';
    final activo = sede['activo'] as bool? ?? false;
    final userCount = sede['_count']?['usuarios'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AppCard(
        onTap: onDetail,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.store_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (codigoSede.isNotEmpty)
                        Text(
                          'Código: $codigoSede',
                          style: AppTextStyles.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (direccion != null && direccion.isNotEmpty)
                        Text(
                          direccion,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusBadge(activo: activo),
                if (auth.hasPermission('establecimientos:editar'))
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: context.colors.textTertiary,
                    ),
                    onSelected: (v) {
                      if (v == 'edit')
                        onEdit();
                      else if (v == 'delete')
                        onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (telefono != null)
                  _InfoChip(icon: Icons.phone_rounded, label: telefono),
                _InfoChip(
                  icon: Icons.people_rounded,
                  label: '$userCount usuarios',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: context.colors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.colors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    ),
  );
}

// ─── Subpantalla: Detalle de Sucursal ────────────────────────────────────────

class _SedeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sede;
  final bool canEdit, canDelete;
  final VoidCallback onEdit, onDelete;

  const _SedeDetailScreen({
    required this.sede,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = sede['nombre'] as String? ?? '';
    final activo = sede['activo'] as bool? ?? false;
    final dir = sede['direccion'] as String? ?? '';
    final tel = sede['telefono'] as String? ?? '';
    final codigo =
        sede['codigoSede'] as String? ?? sede['codigo'] as String? ?? '';
    final users = (sede['_count'] as Map?)?['usuarios'] as int? ?? 0;

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      appBar: SubPageAppBar(
        title: 'Detalle de sucursal',
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: context.colors.textSecondary,
              onPressed: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        child: Column(
          children: [
            // Card principal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.borderLight),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.colors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nombre,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (codigo.isNotEmpty)
                    Text(
                      'Código: $codigo',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (activo
                                  ? AppColors.success
                                  : context.colors.textTertiary)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      activo ? 'Activa' : 'Inactiva',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: activo
                            ? AppColors.success
                            : context.colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.borderLight),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  if (dir.isNotEmpty) ...[
                    _SRow('Dirección', dir),
                    Divider(height: 1, color: context.colors.surfaceAlt),
                  ],
                  if (tel.isNotEmpty) ...[
                    _SRow('Teléfono', tel),
                    Divider(height: 1, color: context.colors.surfaceAlt),
                  ],
                  _SRow('Usuarios', '$users'),
                ],
              ),
            ),
            if (canDelete) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar sucursal'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SRow extends StatelessWidget {
  final String label, value;
  const _SRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _SedeForm extends StatefulWidget {
  final Map<String, dynamic>? sede;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _SedeForm({this.sede, required this.onSave});
  @override
  State<_SedeForm> createState() => _SedeFormState();
}

class _SedeFormState extends State<_SedeForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl, _codigoCtrl, _dirCtrl, _telCtrl;
  bool _activo = true, _loading = false;

  int get _assignedUsers =>
      (widget.sede?['_count'] as Map?)?['usuarios'] as int? ?? 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.sede?['nombre'] as String? ?? '',
    );
    _codigoCtrl = TextEditingController(
      text: widget.sede?['codigoSede'] as String? ?? '',
    );
    _dirCtrl = TextEditingController(
      text: widget.sede?['direccion'] as String? ?? '',
    );
    _telCtrl = TextEditingController(
      text: widget.sede?['telefono'] as String? ?? '',
    );
    _activo = widget.sede?['activo'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codigoCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    appBar: SubPageAppBar(
      title: widget.sede == null ? 'Nueva sucursal' : 'Editar sucursal',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nombre',
              hint: 'Nombre de la sucursal',
              controller: _nameCtrl,
              prefixIcon: Icons.store_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Código de sede',
              hint: 'Ej. CENT',
              controller: _codigoCtrl,
              prefixIcon: Icons.tag_rounded,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                LengthLimitingTextInputFormatter(5),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                return RegExp(r'^[A-Z0-9]{2,5}$').hasMatch(value)
                    ? null
                    : 'Usa entre 2 y 5 letras mayúsculas o números';
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Direccion',
              hint: 'Direccion fisica (opcional)',
              controller: _dirCtrl,
              prefixIcon: Icons.location_on_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Telefono',
              hint: 'Telefono de contacto (opcional)',
              controller: _telCtrl,
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            if (widget.sede != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text('Activa', style: AppTextStyles.bodyMedium),
                  ),
                  Switch(
                    value: _activo,
                    onChanged: _activo && _assignedUsers > 0
                        ? null
                        : (v) => setState(() => _activo = v),
                  ),
                ],
              ),
              if (_activo && _assignedUsers > 0)
                Text(
                  'No se puede desactivar mientras haya $_assignedUsers usuario(s) asignado(s).',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: widget.sede == null ? 'Crear sucursal' : 'Guardar cambios',
              isLoading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_activo && _assignedUsers > 0) {
      AppFeedback.error(
        context,
        'No se puede desactivar una sede con usuarios',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{'nombre': _nameCtrl.text.trim()};
      if (_codigoCtrl.text.isNotEmpty) {
        data['codigoSede'] = _codigoCtrl.text.trim();
      }
      if (_dirCtrl.text.isNotEmpty) data['direccion'] = _dirCtrl.text;
      if (_telCtrl.text.isNotEmpty) data['telefono'] = _telCtrl.text;
      if (widget.sede != null) data['activo'] = _activo;
      await widget.onSave(data);
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.success(
          context,
          widget.sede == null ? 'Sucursal creada' : 'Sucursal actualizada',
        );
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelSmall,
        ),
      ],
    ),
  );
}
