import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
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
        queryParameters: {'pagina': page, 'limite': 20},
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(sucursalesProvider.notifier).load(),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.store_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sucursales',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${state.total} sedes',
                            style: AppTextStyles.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (canCreate)
                      FilledButton.icon(
                        onPressed: () => _showForm(context, ref, null),
                        icon: Icon(Icons.add_rounded, size: 18),
                        label: Text('Nueva'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatChip(
                                    label: 'Total',
                                    value: '${state.total}',
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatChip(
                                    label: 'Activas',
                                    value:
                                        '${state.sedes.where((s) => s['activo'] == true).length}',
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatChip(
                                    label: 'Inactivas',
                                    value:
                                        '${state.sedes.where((s) => s['activo'] != true).length}',
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final sede in state.sedes)
                            _SedeTile(
                              sede: sede,
                              auth: auth,
                              onDetail: () => _showDetail(
                                context,
                                ref,
                                sede['id'] as String,
                              ),
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
    await AppBottomSheet.show(
      context: context,
      title: 'Detalle de sucursal',
      child: _SedeDetail(sede: sede),
    );
  }

  void _showForm(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? sede,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SedeForm(
        sede: sede,
        onSave: (data) async {
          try {
            if (sede == null) {
              await ref.read(sucursalesProvider.notifier).createSede(data);
            } else {
              await ref
                  .read(sucursalesProvider.notifier)
                  .updateSede(sede['id'] as String, data);
            }
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    sede == null ? 'Sucursal creada' : 'Sucursal actualizada',
                  ),
                ),
              );
            }
          } catch (e) {
            if (context.mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar: tiene usuarios asignados'),
        ),
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
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sucursal eliminada')));
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final ruc = sede['ruc'] as String?;
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
                    color: AppColors.primarySurface,
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
                      Text(nombre, style: AppTextStyles.titleMedium),
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
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AppColors.textTertiary,
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
            Row(
              children: [
                if (telefono != null) ...[
                  _InfoChip(icon: Icons.phone_rounded, label: telefono),
                  const SizedBox(width: 8),
                ],
                if (ruc != null) ...[
                  _InfoChip(icon: Icons.receipt_rounded, label: 'RUC: $ruc'),
                  const SizedBox(width: 8),
                ],
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
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    ),
  );
}

class _SedeDetail extends StatelessWidget {
  final Map<String, dynamic> sede;
  const _SedeDetail({required this.sede});
  @override
  Widget build(BuildContext context) {
    final items = {
      'Nombre': sede['nombre'] as String? ?? '',
      'Direccion': sede['direccion'] as String? ?? '',
      'Telefono': sede['telefono'] as String? ?? '',
      'RUC': sede['ruc'] as String? ?? '',
      'Estado': (sede['activo'] as bool? ?? false) ? 'Activa' : 'Inactiva',
      'Creada': sede['createdAt'] as String? ?? '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in items.entries)
          if (e.value.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    e.value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
          ],
      ],
    );
  }
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
  late final TextEditingController _nameCtrl, _dirCtrl, _telCtrl, _rucCtrl;
  bool _activo = true, _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.sede?['nombre'] as String? ?? '',
    );
    _dirCtrl = TextEditingController(
      text: widget.sede?['direccion'] as String? ?? '',
    );
    _telCtrl = TextEditingController(
      text: widget.sede?['telefono'] as String? ?? '',
    );
    _rucCtrl = TextEditingController(
      text: widget.sede?['ruc'] as String? ?? '',
    );
    _activo = widget.sede?['activo'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dirCtrl.dispose();
    _telCtrl.dispose();
    _rucCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              Text(
                widget.sede == null ? 'Nueva sucursal' : 'Editar sucursal',
                style: AppTextStyles.headlineMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(),
        Flexible(
          child: SingleChildScrollView(
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
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'RUC',
                    hint: '11 digitos (opcional)',
                    controller: _rucCtrl,
                    prefixIcon: Icons.receipt_rounded,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (!RegExp(r'^\d{11}$').hasMatch(v))
                        return 'El RUC debe tener 11 digitos';
                      return null;
                    },
                  ),
                  if (widget.sede != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Activa',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: _activo,
                          onChanged: (v) => setState(() => _activo = v),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: widget.sede == null
                        ? 'Crear sucursal'
                        : 'Guardar cambios',
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{'nombre': _nameCtrl.text.trim()};
      if (_dirCtrl.text.isNotEmpty) data['direccion'] = _dirCtrl.text;
      if (_telCtrl.text.isNotEmpty) data['telefono'] = _telCtrl.text;
      if (_rucCtrl.text.isNotEmpty) data['ruc'] = _rucCtrl.text;
      if (widget.sede != null) data['activo'] = _activo;
      await widget.onSave(data);
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
        Text(label, style: AppTextStyles.labelSmall),
      ],
    ),
  );
}
