import 'package:flutter/material.dart';
import '../../../../core/widgets/app_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class RolesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> roles;
  final int total, page, totalPages;
  final List<Map<String, dynamic>> allPermisos;
  const RolesState({
    this.isLoading = false,
    this.error,
    this.roles = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.allPermisos = const [],
  });
  RolesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? roles,
    int? total,
    int? page,
    int? totalPages,
    List<Map<String, dynamic>>? allPermisos,
  }) => RolesState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    roles: roles ?? this.roles,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    allPermisos: allPermisos ?? this.allPermisos,
  );
}

class RolesNotifier extends StateNotifier<RolesState> {
  final ApiClient _api;
  RolesNotifier(this._api) : super(const RolesState()) {
    load();
  }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rs = await Future.wait([
        _api.get(
          ApiConstants.roles,
          queryParameters: {'pagina': page, 'limite': 25},
        ),
        _api.get(ApiConstants.permissionsGrouped),
      ]);
      final rd = rs[0].data as Map;
      final pd = rs[1].data;
      // permissionsGrouped returns {modulo: [permisos]}
      final flatPermisos = <Map<String, dynamic>>[];
      if (pd is Map) {
        for (final entry in pd.entries) {
          if (entry.value is List) {
            for (final p in entry.value as List) {
              flatPermisos.add(Map<String, dynamic>.from(p as Map));
            }
          }
        }
      }
      state = state.copyWith(
        isLoading: false,
        roles: List<Map<String, dynamic>>.from(rd['data'] ?? []),
        total: rd['total'] as int? ?? 0,
        page: rd['pagina'] as int? ?? 1,
        totalPages: rd['totalPaginas'] as int? ?? 1,
        allPermisos: flatPermisos,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createRole(Map<String, dynamic> data) async {
    await _api.post(ApiConstants.roles, data: data);
    await load(page: 1);
  }

  Future<void> updateRole(String id, Map<String, dynamic> data) async {
    await _api.patch(ApiConstants.role(id), data: data);
    await load(page: state.page);
  }

  Future<void> deleteRole(String id) async {
    await _api.delete(ApiConstants.role(id));
    await load(page: state.page);
  }

  Future<void> assignPermissions(String id, List<String> permisoIds) async {
    await _api.put(
      ApiConstants.rolePermissions(id),
      data: {'permisoIds': permisoIds},
    );
    await load(page: state.page);
  }
}

final rolesProvider = StateNotifierProvider<RolesNotifier, RolesState>(
  (ref) => RolesNotifier(ApiClient.instance),
);

class RolesScreen extends ConsumerWidget {
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolesProvider);
    final auth = ref.watch(authProvider);
    final isSuperAdmin = auth.user?.isSuperAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton(
              heroTag: 'roles_fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateModal(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(rolesProvider.notifier).load(),
        child: Column(
          children: [
            Expanded(
              child: state.isLoading
                  ? const AppLoading()
                  : state.error != null
                  ? AppErrorState(
                      message: state.error!,
                      onRetry: () => ref.read(rolesProvider.notifier).load(),
                    )
                  : state.roles.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Sin roles',
                    )
                  : ListView(
                      children: [
                        const SizedBox(height: 8),
                        for (final role in state.roles)
                          _RoleTile(
                            role: role,
                            isSuperAdmin: isSuperAdmin,
                            onEdit: () => _showEditModal(context, ref, role),
                            onDelete: () => _deleteRole(context, ref, role),
                            onAssignPerms: () => _showPermissionsModal(
                              context,
                              ref,
                              role,
                              state,
                            ),
                          ),
                        AppPagination(
                          page: state.page,
                          totalPages: state.totalPages,
                          total: state.total,
                          onPageChange: (p) =>
                              ref.read(rolesProvider.notifier).load(page: p),
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

  void _showCreateModal(BuildContext context, WidgetRef ref) {
    AppNav.push(
      context,
      _RoleForm(
        onSave: (data) => ref.read(rolesProvider.notifier).createRole(data),
      ),
    );
  }

  void _showEditModal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> role,
  ) {
    AppNav.push(
      context,
      _RoleEditForm(
        role: role,
        onSave: (data) => ref
            .read(rolesProvider.notifier)
            .updateRole(role['id'] as String, data),
      ),
    );
  }

  Future<void> _deleteRole(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> role,
  ) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Eliminar rol',
      description:
          'Se eliminara el rol "${role['nombre']}". Esta accion no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDanger: true,
    );
    if (ok && context.mounted) {
      try {
        await ref.read(rolesProvider.notifier).deleteRole(role['id'] as String);
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Rol eliminado')));
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showPermissionsModal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> role,
    RolesState state,
  ) {
    AppNav.push(
      context,
      _PermissionsAssign(
        role: role,
        allPermisos: state.allPermisos,
        onSave: (ids) => ref
            .read(rolesProvider.notifier)
            .assignPermissions(role['id'] as String, ids),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final Map<String, dynamic> role;
  final bool isSuperAdmin;
  final VoidCallback onEdit, onDelete, onAssignPerms;
  const _RoleTile({
    required this.role,
    required this.isSuperAdmin,
    required this.onEdit,
    required this.onDelete,
    required this.onAssignPerms,
  });

  static const _protected = ['SUPERADMIN', 'ADMIN', 'CAJERO', 'VENDEDORA'];

  @override
  Widget build(BuildContext context) {
    final nombre = role['nombre'] as String? ?? '';
    final desc = role['descripcion'] as String? ?? '';
    final nivel = role['nivel'] as int? ?? 0;
    final activo = role['activo'] as bool? ?? false;
    final userCount = role['_count']?['usuarios'] as int? ?? 0;
    final permCount = (role['permisos'] as List?)?.length ?? 0;
    final isProtected = _protected.contains(nombre.toUpperCase());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.roleColor(nombre).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: AppColors.roleColor(nombre),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(nombre, style: AppTextStyles.titleMedium),
                          if (isProtected) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BASE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                StatusBadge(activo: activo),
                if (isSuperAdmin)
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
                      else if (v == 'perms')
                        onAssignPerms();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'perms',
                        child: Row(
                          children: [
                            Icon(Icons.security_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Asignar permisos'),
                          ],
                        ),
                      ),
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
                      if (!isProtected)
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
                _InfoChip(
                  icon: Icons.people_rounded,
                  label: '$userCount usuarios',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.security_rounded,
                  label: '$permCount permisos',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Nivel $nivel',
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

class _RoleForm extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _RoleForm({required this.onSave});
  @override
  State<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends State<_RoleForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _nivel = 10;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: const SubPageAppBar(title: 'Nuevo rol'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nombre',
              hint: 'NOMBRE_ROL',
              controller: _nameCtrl,
              prefixIcon: Icons.label_rounded,
              textCapitalization: TextCapitalization.characters,
              onChanged: (v) {
                _nameCtrl.value = _nameCtrl.value.copyWith(
                  text: v.toUpperCase(),
                  selection: TextSelection.collapsed(offset: v.length),
                );
              },
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Descripcion',
              hint: 'Descripcion del rol (opcional)',
              controller: _descCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            Text(
              'Nivel (1-99)',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _nivel.toDouble(),
                    min: 1,
                    max: 99,
                    onChanged: (v) => setState(() => _nivel = v.toInt()),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text(
                      '$_nivel',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Crear rol',
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
    setState(() => _loading = true);
    try {
      await widget.onSave({
        'nombre': _nameCtrl.text.toUpperCase().trim(),
        'descripcion': _descCtrl.text,
        'nivel': _nivel,
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rol creado')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _RoleEditForm extends StatefulWidget {
  final Map<String, dynamic> role;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _RoleEditForm({required this.role, required this.onSave});
  @override
  State<_RoleEditForm> createState() => _RoleEditFormState();
}

class _RoleEditFormState extends State<_RoleEditForm> {
  late final TextEditingController _descCtrl;
  late int _nivel;
  late bool _activo;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(
      text: widget.role['descripcion'] as String? ?? '',
    );
    _nivel = widget.role['nivel'] as int? ?? 10;
    _activo = widget.role['activo'] as bool? ?? true;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: const SubPageAppBar(title: 'Editar rol'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Descripcion',
            hint: 'Descripcion del rol',
            controller: _descCtrl,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          Text(
            'Nivel (1-99)',
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _nivel.toDouble(),
                  min: 1,
                  max: 99,
                  onChanged: (v) => setState(() => _nivel = v.toInt()),
                ),
              ),
              SizedBox(
                width: 50,
                child: Center(
                  child: Text(
                    '$_nivel',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Activo', style: AppTextStyles.bodyMedium),
              ),
              Switch(
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Guardar cambios',
            isLoading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await widget.onSave({
        'descripcion': _descCtrl.text,
        'nivel': _nivel,
        'activo': _activo,
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rol actualizado')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _PermissionsAssign extends StatefulWidget {
  final Map<String, dynamic> role;
  final List<Map<String, dynamic>> allPermisos;
  final Future<void> Function(List<String>) onSave;
  const _PermissionsAssign({
    required this.role,
    required this.allPermisos,
    required this.onSave,
  });
  @override
  State<_PermissionsAssign> createState() => _PermissionsAssignState();
}

class _PermissionsAssignState extends State<_PermissionsAssign> {
  late Set<String> _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final current =
        (widget.role['permisos'] as List?)
            ?.map((p) => p['id'] as String? ?? '')
            .toSet() ??
        {};
    _selected = current;
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final p in widget.allPermisos) {
      final mod = p['modulo'] as String? ?? 'otros';
      m.putIfAbsent(mod, () => []).add(p);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: SubPageAppBar(title: 'Permisos: ${widget.role['nombre']}'),
    body: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (final mod in _grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                PermissionModuleBadge(module: mod.key),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    final ids = mod.value
                        .map((p) => p['id'] as String? ?? '')
                        .toSet();
                    if (ids.every(_selected.contains)) {
                      _selected.removeAll(ids);
                    } else {
                      _selected.addAll(ids);
                    }
                  }),
                  child: Text(
                    _grouped[mod.key]!.every((p) => _selected.contains(p['id']))
                        ? 'Deseleccionar todo'
                        : 'Seleccionar todo',
                  ),
                ),
              ],
            ),
          ),
          for (final perm in mod.value)
            CheckboxListTile(
              dense: true,
              value: _selected.contains(perm['id']),
              onChanged: (v) => setState(() {
                if (v == true)
                  _selected.add(perm['id'] as String? ?? '');
                else
                  _selected.remove(perm['id']);
              }),
              title: Text(
                perm['nombre'] as String? ?? '',
                style: AppTextStyles.bodyMedium,
              ),
              subtitle: Text(
                perm['descripcion'] as String? ?? '',
                style: AppTextStyles.labelSmall,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          const Divider(),
        ],
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PrimaryButton(
          label: 'Guardar permisos (${_selected.length})',
          isLoading: _loading,
          onPressed: () async {
            setState(() => _loading = true);
            try {
              await widget.onSave(_selected.toList());
              if (mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permisos actualizados')),
                );
              }
            } catch (e) {
              if (mounted) {
                setState(() => _loading = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          },
        ),
      ),
    ),
  );
}
