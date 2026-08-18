import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/navigation/app_nav.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

const passwordPolicyHint =
    'Entre 6 y 72 caracteres, con al menos una letra minúscula y un número.';

bool passwordMeetsBackendPolicy(String value) =>
    value.length >= 6 &&
    value.length <= 72 &&
    RegExp('[a-z]').hasMatch(value) &&
    RegExp(r'\d').hasMatch(value);

List<Map<String, dynamic>> assignableRoles(
  List<Map<String, dynamic>> roles,
  int currentLevel, {
  required bool isSuperAdmin,
}) => roles
    .where(
      (role) =>
          role['activo'] == true &&
          role['nombre'] != 'SUPERADMIN' &&
          (isSuperAdmin || (role['nivel'] as int? ?? 0) < currentLevel),
    )
    .toList();

List<Map<String, dynamic>> editableSedesForUser(
  List<Map<String, dynamic>> activeSedes,
  Map<String, dynamic> user,
) {
  final current = user['sede'];
  if (current is! Map || current['id'] is! String) return activeSedes;
  if (activeSedes.any((sede) => sede['id'] == current['id'])) {
    return activeSedes;
  }
  return [...activeSedes, Map<String, dynamic>.from(current)];
}

// ─── State ────────────────────────────────────────────────────────────────────

class UsuariosState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> users;
  final int total, page, totalPages;
  final List<Map<String, dynamic>> roles, sedes;
  const UsuariosState({
    this.isLoading = false,
    this.error,
    this.users = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.roles = const [],
    this.sedes = const [],
  });
  UsuariosState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? users,
    int? total,
    int? page,
    int? totalPages,
    List<Map<String, dynamic>>? roles,
    List<Map<String, dynamic>>? sedes,
  }) => UsuariosState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
    users: users ?? this.users,
    total: total ?? this.total,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    roles: roles ?? this.roles,
    sedes: sedes ?? this.sedes,
  );
}

class UsuariosNotifier extends StateNotifier<UsuariosState> {
  final ApiClient _api;
  final bool _canReadRoles;
  final bool _canReadSedes;
  final String? _sedeId;

  UsuariosNotifier(
    this._api,
    this._canReadRoles,
    this._canReadSedes,
    this._sedeId,
  ) : super(const UsuariosState()) {
    load();
  }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final usersResponse = await _api.get(
        ApiConstants.users,
        queryParameters: {
          'pagina': page,
          'limite': 25,
          if (_sedeId != null) 'sedeId': _sedeId,
        },
      );
      final ud = usersResponse.data as Map;
      var roles = state.roles;
      var sedes = state.sedes;

      if (_canReadRoles) {
        try {
          final response = await _api.get(
            ApiConstants.roles,
            queryParameters: {'pagina': 1, 'limite': 50},
          );
          final data = response.data as Map;
          roles = List<Map<String, dynamic>>.from(data['data'] ?? []);
        } catch (_) {
          // El listado de usuarios sigue siendo útil sin el catálogo de roles.
        }
      }
      if (_canReadSedes) {
        try {
          final response = await _api.get(
            ApiConstants.establishments,
            queryParameters: {'pagina': 1, 'limite': 50},
          );
          final data = response.data as Map;
          sedes = List<Map<String, dynamic>>.from(data['data'] ?? []);
        } catch (_) {
          // El listado de usuarios sigue siendo útil sin el catálogo de sedes.
        }
      }
      state = state.copyWith(
        isLoading: false,
        users: List<Map<String, dynamic>>.from(ud['data'] ?? []),
        total: ud['total'] as int? ?? 0,
        page: ud['pagina'] as int? ?? 1,
        totalPages: ud['totalPaginas'] as int? ?? 1,
        roles: roles,
        sedes: sedes,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    try {
      final r = await _api.get(ApiConstants.user(id));
      return r.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    await _api.post(ApiConstants.users, data: data);
    await load(page: state.page);
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await _api.patch(ApiConstants.user(id), data: data);
    await load(page: state.page);
  }

  Future<void> deactivateUser(String id) async {
    await _api.delete(ApiConstants.user(id));
    await load(page: state.page);
  }

  Future<void> reactivateUser(String id) async {
    await _api.patch(ApiConstants.user(id), data: {'activo': true});
    await load(page: state.page);
  }

  Future<void> resetPassword(String id, String password) async {
    await _api.post(
      ApiConstants.resetUserPassword(id),
      data: {'password': password},
    );
    await load(page: state.page);
  }
}

final usuariosProvider = StateNotifierProvider<UsuariosNotifier, UsuariosState>(
  (ref) {
    final auth = ref.watch(authProvider);
    return UsuariosNotifier(
      ApiClient.instance,
      auth.hasPermission('roles:leer'),
      auth.hasPermission('establecimientos:leer'),
      ref.watch(globalSedeIdProvider),
    );
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class UsuariosScreen extends ConsumerStatefulWidget {
  const UsuariosScreen({super.key});

  @override
  ConsumerState<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends ConsumerState<UsuariosScreen> {
  String _search = '';
  String _roleFilter = '';
  String _statusFilter = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usuariosProvider);
    final auth = ref.watch(authProvider);
    final availableRoles = assignableRoles(
      state.roles,
      auth.user?.nivel ?? 0,
      isSuperAdmin: auth.user?.isSuperAdmin ?? false,
    );
    final activeSedes = state.sedes
        .where((sede) => sede['activo'] == true)
        .toList();
    final query = _search.trim().toLowerCase();
    final filteredUsers = state.users.where((user) {
      final role = user['rol'] is Map ? user['rol'] as Map : const {};
      final sede = user['sede'] is Map ? user['sede'] as Map : const {};
      final text = [
        user['username'],
        user['nombres'],
        user['apellidos'],
        role['nombre'],
        sede['nombre'],
      ].whereType<Object>().join(' ').toLowerCase();
      final matchesSearch = query.isEmpty || text.contains(query);
      final matchesRole =
          _roleFilter.isEmpty || role['id']?.toString() == _roleFilter;
      final matchesStatus =
          _statusFilter.isEmpty ||
          (user['activo'] == true).toString() == _statusFilter;
      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
    final adminCount = state.users.where((user) {
      final role = user['rol'] is Map ? user['rol'] as Map : const {};
      return const ['SUPERADMIN', 'ADMIN'].contains(role['nombre']);
    }).length;

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: auth.hasPermission('usuarios:crear')
          ? FloatingActionButton(
              heroTag: 'usuarios_fab',
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              onPressed: () => _showCreateModal(
                context,
                ref,
                state,
                availableRoles,
                activeSedes,
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(usuariosProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
          children: [
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar usuario...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _FilterDropdown<String>(
                      label: 'Rol',
                      initialValue: _roleFilter,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Todos'),
                        ),
                        for (final role in state.roles)
                          DropdownMenuItem(
                            value: role['id'] as String? ?? '',
                            child: Text(role['nombre'] as String? ?? ''),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _roleFilter = value ?? ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _FilterDropdown<String>(
                      label: 'Estado',
                      initialValue: _statusFilter,
                      items: const [
                        DropdownMenuItem(value: '', child: Text('Todos')),
                        DropdownMenuItem(
                          value: 'true',
                          child: Text('Activos'),
                        ),
                        DropdownMenuItem(
                          value: 'false',
                          child: Text('Inactivos'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _statusFilter = value ?? ''),
                    ),
                  ),
                ],
              ),
            ),
            // Stats
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AppCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 700 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: cols,
                      childAspectRatio: cols == 4 ? 2.6 : 1.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StatChip(
                          label: 'Administradores',
                          value: '$adminCount',
                          color: AppColors.primary,
                        ),
                        _StatChip(
                          label: 'Empleados',
                          value: '${state.users.length - adminCount}',
                          color: AppColors.info,
                        ),
                        _StatChip(
                          label: 'Activos',
                          value:
                              '${state.users.where((u) => u['activo'] == true).length}',
                          color: AppColors.success,
                        ),
                        _StatChip(
                          label: 'Inactivos',
                          value:
                              '${state.users.where((u) => u['activo'] != true).length}',
                          color: context.colors.textTertiary,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Content
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: AppLoading(),
              )
            else if (state.error != null)
              AppErrorState(
                message: state.error!,
                onRetry: () => ref.read(usuariosProvider.notifier).load(),
              )
            else if (filteredUsers.isEmpty)
              const AppEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'Sin usuarios',
                description: 'No hay usuarios registrados',
              )
            else ...[
              if (MediaQuery.sizeOf(context).width >= 1024)
                _UsersDesktopTable(
                  users: filteredUsers,
                  auth: auth,
                  onTap: (user) =>
                      _showDetail(context, ref, user['id'] as String),
                  onEdit: (user) => _showEditModal(
                    context,
                    ref,
                    user,
                    state,
                    availableRoles,
                    activeSedes,
                  ),
                  onDeactivate: (user) => _deactivate(context, ref, user),
                  onReactivate: (user) => ref
                      .read(usuariosProvider.notifier)
                      .reactivateUser(user['id'] as String),
                  onResetPassword: (user) => _resetPassword(
                    context,
                    ref,
                    user['id'] as String,
                  ),
                )
              else
                for (final user in filteredUsers)
                  _UserTile(
                    user: user,
                    auth: auth,
                    onTap: () =>
                        _showDetail(context, ref, user['id'] as String),
                    onEdit: () => _showEditModal(
                      context,
                      ref,
                      user,
                      state,
                      availableRoles,
                      activeSedes,
                    ),
                    onDeactivate: () => _deactivate(context, ref, user),
                    onReactivate: () => ref
                        .read(usuariosProvider.notifier)
                        .reactivateUser(user['id'] as String),
                    onResetPassword: () => _resetPassword(
                      context,
                      ref,
                      user['id'] as String,
                    ),
                  ),
              AppPagination(
                page: state.page,
                totalPages: state.totalPages,
                total: state.total,
                onPageChange: (p) =>
                    ref.read(usuariosProvider.notifier).load(page: p),
              ),
            ],
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
    final user = await ref.read(usuariosProvider.notifier).getUser(id);
    if (user == null || !context.mounted) return;
    final state = ref.read(usuariosProvider);
    final auth = ref.read(authProvider);
    final availableRoles = assignableRoles(
      state.roles,
      auth.user?.nivel ?? 0,
      isSuperAdmin: auth.user?.isSuperAdmin ?? false,
    );
    final activeSedes = state.sedes
        .where((sede) => sede['activo'] == true)
        .toList();
    AppNav.push(
      context,
      _UserDetailScreen(
        user: user,
        roles: availableRoles,
        sedes: activeSedes,
        isSuperAdmin: auth.user?.isSuperAdmin ?? false,
        canEdit: auth.hasPermission('usuarios:editar'),
        canDeactivate: auth.hasPermission('usuarios:eliminar'),
        canReset: auth.hasPermission('usuarios:resetear-password'),
        onEdit: () => _showEditModal(
          context,
          ref,
          user,
          state,
          availableRoles,
          activeSedes,
        ),
        onDeactivate: () => _deactivate(context, ref, user),
        onReactivate: () => ref
            .read(usuariosProvider.notifier)
            .reactivateUser(user['id'] as String),
        onResetPassword: (uid) => _resetPassword(context, ref, uid),
      ),
    );
  }

  void _showCreateModal(
    BuildContext context,
    WidgetRef ref,
    UsuariosState state,
    List<Map<String, dynamic>> availableRoles,
    List<Map<String, dynamic>> activeSedes,
  ) {
    AppNav.push(
      context,
      _UserForm(
        roles: availableRoles,
        sedes: activeSedes,
        isSuperAdmin: ref.read(authProvider).user?.isSuperAdmin ?? false,
        onSave: (data) => ref.read(usuariosProvider.notifier).createUser(data),
      ),
    );
  }

  void _showEditModal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
    UsuariosState state,
    List<Map<String, dynamic>> availableRoles,
    List<Map<String, dynamic>> activeSedes,
  ) {
    AppNav.push(
      context,
      _UserEditForm(
        user: user,
        roles: availableRoles,
        sedes: editableSedesForUser(activeSedes, user),
        isSuperAdmin: ref.read(authProvider).user?.isSuperAdmin ?? false,
        onSave: (data) => ref
            .read(usuariosProvider.notifier)
            .updateUser(user['id'] as String, data),
      ),
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final ok = await ConfirmDialog.show(
      context: context,
      title: 'Desactivar usuario',
      description:
          'Se desactivara la cuenta de "${user['username']}". Podra reactivarla despues.',
      confirmLabel: 'Desactivar',
      isDanger: true,
    );
    if (ok && context.mounted) {
      try {
        await ref
            .read(usuariosProvider.notifier)
            .deactivateUser(user['id'] as String);
        if (context.mounted)
          AppFeedback.success(context, 'Usuario desactivado');
      } catch (e) {
        if (context.mounted) AppFeedback.error(context, 'Error: $e');
      }
    }
  }

  Future<void> _resetPassword(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final password = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const _ResetPasswordDialog(),
    );
    if (password == null || !context.mounted) return;
    try {
      await ref.read(usuariosProvider.notifier).resetPassword(id, password);
      if (context.mounted) {
        AppFeedback.success(context, 'Contraseña actualizada');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.error(context, 'Error: $e');
      }
    }
  }
}

// ─── User Tile ────────────────────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.initialValue,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: initialValue,
    isExpanded: true,
    isDense: true,
    decoration: InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    items: items,
    onChanged: onChanged,
  );
}

/// Desktop DataTable for users — matches web's table layout with columns:
/// Cuenta, Rol, Sede, Estado, Alta, Acciones
class _UsersDesktopTable extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final AuthState auth;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDeactivate;
  final ValueChanged<Map<String, dynamic>> onReactivate;
  final ValueChanged<Map<String, dynamic>> onResetPassword;

  const _UsersDesktopTable({
    required this.users,
    required this.auth,
    required this.onTap,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = auth.hasPermission('usuarios:editar');
    final canDelete = auth.hasPermission('usuarios:eliminar');
    final canReset = auth.hasPermission('usuarios:resetear-password');

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.sizeOf(context).width - 400,
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                context.colors.backgroundAlt,
              ),
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('Cuenta')),
                DataColumn(label: Text('Rol')),
                DataColumn(label: Text('Sede')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Alta')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: users.map((user) {
                final role = user['rol'] is Map
                    ? user['rol'] as Map
                    : const {};
                final sede = user['sede'] is Map
                    ? user['sede'] as Map
                    : const {};
                final username = user['username'] as String? ?? '';
                final roleName = role['nombre'] as String? ?? '';
                final sedeName = sede['nombre'] as String? ?? '—';
                final activo = user['activo'] == true;
                final createdAt = user['createdAt'] as String? ?? '';
                final roleColor = AppColors.roleColor(roleName);
                final avatarColor = AppColors.avatarColor(username);
                final isSuperadmin = roleName.toUpperCase() == 'SUPERADMIN';

                return DataRow(
                  cells: [
                    // Cuenta (avatar + username)
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: avatarColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: avatarColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => onTap(user),
                    ),
                    // Rol
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                        ),
                      ),
                    )),
                    // Sede
                    DataCell(Text(
                      sedeName,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    )),
                    // Estado
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: activo
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: activo ? AppColors.success : AppColors.error,
                        ),
                      ),
                    )),
                    // Alta (createdAt)
                    DataCell(Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    )),
                    // Acciones
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'Detalle',
                          onPressed: () => onTap(user),
                          color: context.colors.textSecondary,
                        ),
                        if (canEdit)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Editar',
                            onPressed: () => onEdit(user),
                            color: context.colors.textSecondary,
                          ),
                        if (canReset)
                          IconButton(
                            icon: const Icon(Icons.key_outlined, size: 18),
                            tooltip: 'Reset contraseña',
                            onPressed: () => onResetPassword(user),
                            color: context.colors.textSecondary,
                          ),
                        if (canDelete && activo && !isSuperadmin)
                          IconButton(
                            icon: const Icon(
                              Icons.person_off_outlined,
                              size: 18,
                            ),
                            tooltip: 'Desactivar',
                            onPressed: () => onDeactivate(user),
                            color: AppColors.error,
                          ),
                        if (canEdit && !activo)
                          IconButton(
                            icon: const Icon(
                              Icons.person_add_outlined,
                              size: 18,
                            ),
                            tooltip: 'Reactivar',
                            onPressed: () => onReactivate(user),
                            color: AppColors.success,
                          ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final date = DateTime.parse(iso);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final AuthState auth;
  final VoidCallback onTap, onEdit, onDeactivate, onReactivate, onResetPassword;
  const _UserTile({
    required this.user,
    required this.auth,
    required this.onTap,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String? ?? '';
    final role = user['rol']?['nombre'] as String? ?? '';
    final sede = user['sede']?['nombre'] as String?;
    final activo = user['activo'] as bool? ?? false;
    final mustChange = user['mustChangePassword'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.avatarColor(username),
              child: Text(
                FormatUtils.initials(username),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      if (mustChange) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      RoleBadge(role: role),
                      if (sede != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            sede,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.labelSmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(activo: activo),
                const SizedBox(width: 2),
                _ActionsMenu(
                  user: user,
                  auth: auth,
                  onEdit: onEdit,
                  onDeactivate: onDeactivate,
                  onReactivate: onReactivate,
                  onResetPassword: onResetPassword,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final Map<String, dynamic> user;
  final AuthState auth;
  final VoidCallback onEdit, onDeactivate, onReactivate, onResetPassword;
  const _ActionsMenu({
    required this.user,
    required this.auth,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final activo = user['activo'] as bool? ?? false;
    final isSuperAdmin = user['rol']?['nombre'] == 'SUPERADMIN';
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: context.colors.textTertiary,
      ),
      onSelected: (v) {
        if (v == 'edit')
          onEdit();
        else if (v == 'deactivate')
          onDeactivate();
        else if (v == 'reactivate')
          onReactivate();
        else if (v == 'reset')
          onResetPassword();
      },
      itemBuilder: (_) => [
        if (!isSuperAdmin && auth.hasPermission('usuarios:editar'))
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
        if (!isSuperAdmin && auth.hasPermission('usuarios:resetear-password'))
          const PopupMenuItem(
            value: 'reset',
            child: Row(
              children: [
                Icon(Icons.lock_reset_rounded, size: 16),
                SizedBox(width: 8),
                Text('Resetear contrasena'),
              ],
            ),
          ),
        if (!isSuperAdmin && activo && auth.hasPermission('usuarios:eliminar'))
          const PopupMenuItem(
            value: 'deactivate',
            child: Row(
              children: [
                Icon(Icons.block_rounded, size: 16, color: AppColors.error),
                SizedBox(width: 8),
                Text('Desactivar', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        if (!isSuperAdmin && !activo && auth.hasPermission('usuarios:editar'))
          const PopupMenuItem(
            value: 'reactivate',
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                SizedBox(width: 8),
                Text('Reactivar', style: TextStyle(color: AppColors.success)),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── User Detail ──────────────────────────────────────────────────────────────

// ─── Subpantalla: Detalle de Usuario ────────────────────────────────────────

class _UserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> roles, sedes;
  final bool isSuperAdmin;
  final bool canEdit, canDeactivate, canReset;
  final VoidCallback onEdit, onDeactivate, onReactivate;
  final void Function(String) onResetPassword;

  const _UserDetailScreen({
    required this.user,
    required this.roles,
    required this.sedes,
    required this.isSuperAdmin,
    required this.canEdit,
    required this.canDeactivate,
    required this.canReset,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final activo = user['activo'] as bool? ?? false;
    final username = user['username'] as String? ?? '';
    final rol = user['rol'] is Map
        ? user['rol']['nombre'] as String? ?? ''
        : user['rol'] as String? ?? '';
    final sede = user['sede'] is Map
        ? user['sede']['nombre'] as String? ?? 'Sin sede'
        : user['sedeId'] as String? ?? 'Sin sede';
    final mustChange = user['mustChangePassword'] as bool? ?? false;
    final protected = rol == 'SUPERADMIN';

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      appBar: SubPageAppBar(
        title: 'Detalle de usuario',
        actions: [
          if (canEdit && !protected)
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
            // Avatar + nombre
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
                  // Avatar grande
                  Builder(
                    builder: (_) {
                      final color = AppColors.avatarColor(username);
                      final initial = username.isNotEmpty
                          ? username[0].toUpperCase()
                          : '?';
                      return Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _Badge(rol, AppColors.roleColor(rol.toUpperCase())),
                      _Badge(
                        activo ? 'Activo' : 'Inactivo',
                        activo
                            ? AppColors.success
                            : context.colors.textTertiary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Detalles
            Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.borderLight),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _DetailRow('Sede', sede),
                  Divider(height: 1, color: context.colors.surfaceAlt),
                  _DetailRow(
                    'Cambio de contraseña',
                    mustChange ? 'Requerido' : 'No requerido',
                  ),
                  Divider(height: 1, color: context.colors.surfaceAlt),
                  _DetailRow('ID', user['id'] as String? ?? '', mono: true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Acciones
            if (canReset && !protected)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onResetPassword.call.bind(
                    user['id'] as String? ?? '',
                  ),
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text('Restablecer contraseña'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: context.colors.primaryBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (canReset && !protected) const SizedBox(height: 10),
            if (activo && canDeactivate && !protected)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDeactivate();
                  },
                  icon: const Icon(Icons.person_off_outlined, size: 18),
                  label: const Text('Desactivar usuario'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (!activo && canEdit && !protected)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onReactivate();
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Reactivar usuario'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on void Function(String) {
  void Function() bind(String arg) =>
      () => this(arg);
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  const _DetailRow(this.label, this.value, {this.mono = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
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
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _UserDetail extends StatelessWidget {
  final Map<String, dynamic> user;
  const _UserDetail({required this.user});

  @override
  Widget build(BuildContext context) {
    final items = {
      'ID': user['id'] as String? ?? '',
      'Usuario': user['username'] as String? ?? '',
      'Rol': user['rol']?['nombre'] as String? ?? '',
      'Sede': user['sede']?['nombre'] as String? ?? 'Sin sede',
      'Estado': (user['activo'] as bool? ?? false) ? 'Activo' : 'Inactivo',
      'Cambio de contrasena requerido':
          (user['mustChangePassword'] as bool? ?? false) ? 'Si' : 'No',
      'Creado': user['createdAt'] as String? ?? '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in items.entries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  e.key,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  e.value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.colors.textPrimary,
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

// ─── User Form ────────────────────────────────────────────────────────────────

class _UserForm extends StatefulWidget {
  final List<Map<String, dynamic>> roles, sedes;
  final bool isSuperAdmin;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _UserForm({
    required this.roles,
    required this.sedes,
    required this.isSuperAdmin,
    required this.onSave,
  });
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _rolId, _sedeId;
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const SubPageAppBar(title: 'Nuevo usuario'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                label: 'Usuario',
                hint: 'Nombre de usuario',
                controller: _userCtrl,
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Contrasena temporal',
                hint: '6-72 caracteres, minúscula y número',
                controller: _passCtrl,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  if (!passwordMeetsBackendPolicy(v)) {
                    return passwordPolicyHint;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _label('Rol'),
              DropdownButtonFormField<String>(
                value: _rolId,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  hintText: 'Seleccionar rol',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                items: widget.roles
                    .map(
                      (r) => DropdownMenuItem(
                        value: r['id'] as String,
                        child: Text(r['nombre'] as String? ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _rolId = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
              if (widget.isSuperAdmin) ...[
                const SizedBox(height: 14),
                _label('Sede'),
                DropdownButtonFormField<String>(
                  value: _sedeId,
                  isExpanded: true,
                  isDense: true,
                  decoration: const InputDecoration(
                    hintText: 'Seleccionar sede',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  items: widget.sedes
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['nombre'] as String? ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sedeId = v),
                  validator: (v) => v == null ? 'Requerido' : null,
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Crear usuario',
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w500,
        color: context.colors.textSecondary,
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.onSave({
        'username': _userCtrl.text.trim(),
        'password': _passCtrl.text,
        'rolId': _rolId,
        if (_sedeId != null) 'sedeId': _sedeId,
      });
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.success(context, 'Usuario creado exitosamente');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _UserEditForm extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> roles, sedes;
  final bool isSuperAdmin;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _UserEditForm({
    required this.user,
    required this.roles,
    required this.sedes,
    required this.isSuperAdmin,
    required this.onSave,
  });
  @override
  State<_UserEditForm> createState() => _UserEditFormState();
}

class _UserEditFormState extends State<_UserEditForm> {
  late String? _rolId, _sedeId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final currentRoleId = widget.user['rol']?['id'] as String?;
    _rolId = widget.roles.any((role) => role['id'] == currentRoleId)
        ? currentRoleId
        : null;
    _sedeId = widget.user['sede']?['id'] as String?;
    if (!widget.sedes.any((sede) => sede['id'] == _sedeId)) {
      _sedeId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: const SubPageAppBar(title: 'Editar usuario'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Rol'),
            DropdownButtonFormField<String>(
              value: _rolId,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              items: widget.roles
                  .map(
                    (r) => DropdownMenuItem(
                      value: r['id'] as String,
                      child: Text(r['nombre'] as String? ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _rolId = v),
            ),
            if (widget.isSuperAdmin) ...[
              const SizedBox(height: 14),
              _label('Sede'),
              DropdownButtonFormField<String>(
                value: _sedeId,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin sede')),
                  ...widget.sedes.map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(s['nombre'] as String? ?? ''),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _sedeId = v),
              ),
            ],
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
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: AppTextStyles.bodySmall.copyWith(
        fontWeight: FontWeight.w500,
        color: context.colors.textSecondary,
      ),
    ),
  );

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{};
      if (_rolId != null) data['rolId'] = _rolId;
      if (_sedeId != null) data['sedeId'] = _sedeId;
      await widget.onSave(data);
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.success(context, 'Usuario actualizado');
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!passwordMeetsBackendPolicy(_password.text)) {
      setState(() => _error = passwordPolicyHint);
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    icon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
    title: const Text('Nueva contraseña'),
    content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Asigna una contraseña definitiva. Se cerrarán las sesiones activas del usuario.',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('reset-password-field'),
            controller: _password,
            obscureText: _obscure,
            maxLength: 72,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              counterText: '',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reset-password-confirmation-field'),
            controller: _confirmation,
            obscureText: _obscure,
            maxLength: 72,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text(passwordPolicyHint, style: AppTextStyles.labelSmall),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Actualizar')),
    ],
  );
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
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
