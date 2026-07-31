import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
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

// ─── State ────────────────────────────────────────────────────────────────────

class UsuariosState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> users;
  final int total, page, totalPages;
  final List<Map<String, dynamic>> roles, sedes;
  const UsuariosState({this.isLoading = false, this.error, this.users = const [],
      this.total = 0, this.page = 1, this.totalPages = 1, this.roles = const [], this.sedes = const []});
  UsuariosState copyWith({bool? isLoading, String? error, List<Map<String, dynamic>>? users,
      int? total, int? page, int? totalPages, List<Map<String, dynamic>>? roles, List<Map<String, dynamic>>? sedes}) =>
    UsuariosState(isLoading: isLoading ?? this.isLoading, error: error, users: users ?? this.users,
        total: total ?? this.total, page: page ?? this.page, totalPages: totalPages ?? this.totalPages,
        roles: roles ?? this.roles, sedes: sedes ?? this.sedes);
}

class UsuariosNotifier extends StateNotifier<UsuariosState> {
  final ApiClient _api;
  UsuariosNotifier(this._api) : super(const UsuariosState()) { load(); }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rs = await Future.wait([
        _api.get(ApiConstants.users, queryParameters: {'pagina': page, 'limite': 25}),
        _api.get(ApiConstants.roles, queryParameters: {'pagina': 1, 'limite': 50}),
        _api.get(ApiConstants.establishments, queryParameters: {'pagina': 1, 'limite': 50}),
      ]);
      final ud = rs[0].data as Map;
      final rd = rs[1].data as Map;
      final sd = rs[2].data as Map;
      state = state.copyWith(
        isLoading: false, users: List<Map<String, dynamic>>.from(ud['data'] ?? []),
        total: ud['total'] as int? ?? 0, page: ud['pagina'] as int? ?? 1,
        totalPages: ud['totalPaginas'] as int? ?? 1,
        roles: List<Map<String, dynamic>>.from(rd['data'] ?? []),
        sedes: List<Map<String, dynamic>>.from(sd['data'] ?? []));
    } catch (e) { state = state.copyWith(isLoading: false, error: e.toString()); }
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    try {
      final r = await _api.get(ApiConstants.user(id));
      return r.data as Map<String, dynamic>;
    } catch (_) { return null; }
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

  Future<Map<String, dynamic>?> resetPassword(String id) async {
    final r = await _api.post(ApiConstants.resetUserPassword(id));
    await load(page: state.page);
    return r.data as Map<String, dynamic>?;
  }
}

final usuariosProvider = StateNotifierProvider<UsuariosNotifier, UsuariosState>(
    (ref) => UsuariosNotifier(ApiClient.instance));

// ─── Screen ───────────────────────────────────────────────────────────────────

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usuariosProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(usuariosProvider.notifier).load(),
        child: Column(children: [
          // Header
          Container(color: AppColors.background, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              const Icon(Icons.people_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Expanded(child: Text('Usuarios', style: AppTextStyles.headlineLarge)),
              if (auth.hasPermission('usuarios:crear'))
                FilledButton.icon(
                  onPressed: () => _showCreateModal(context, ref, state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nuevo'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10))),
            ])),

          // Content
          Expanded(child: state.isLoading
            ? const AppLoading()
            : state.error != null
              ? AppErrorState(message: state.error!, onRetry: () => ref.read(usuariosProvider.notifier).load())
              : state.users.isEmpty
                ? const AppEmptyState(icon: Icons.people_outline_rounded, title: 'Sin usuarios', description: 'No hay usuarios registrados')
                : ListView(children: [
                    // Stats
                    Padding(padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(child: _StatChip(label: 'Total', value: '${state.total}', color: AppColors.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatChip(label: 'Activos',
                            value: '${state.users.where((u) => u['activo'] == true).length}', color: AppColors.success)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatChip(label: 'Inactivos',
                            value: '${state.users.where((u) => u['activo'] != true).length}', color: AppColors.textTertiary)),
                      ])),
                    // User list
                    for (final user in state.users)
                      _UserTile(user: user, auth: auth,
                        onTap: () => _showDetail(context, ref, user['id'] as String),
                        onEdit: () => _showEditModal(context, ref, user, state),
                        onDeactivate: () => _deactivate(context, ref, user),
                        onReactivate: () => ref.read(usuariosProvider.notifier).reactivateUser(user['id'] as String),
                        onResetPassword: () => _resetPassword(context, ref, user['id'] as String)),
                    // Pagination
                    AppPagination(page: state.page, totalPages: state.totalPages, total: state.total,
                        onPageChange: (p) => ref.read(usuariosProvider.notifier).load(page: p)),
                    const SizedBox(height: 80),
                  ])),
        ]))),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref, String id) async {
    final user = await ref.read(usuariosProvider.notifier).getUser(id);
    if (user == null || !context.mounted) return;
    await AppBottomSheet.show(context: context, title: 'Detalle de usuario',
      child: _UserDetail(user: user));
  }

  void _showCreateModal(BuildContext context, WidgetRef ref, UsuariosState state) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _UserForm(
        roles: state.roles, sedes: state.sedes, isSuperAdmin: ref.read(authProvider).user?.isSuperAdmin ?? false,
        onSave: (data) async {
          try {
            await ref.read(usuariosProvider.notifier).createUser(data);
            if (context.mounted) { Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado exitosamente'))); }
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }));
  }

  void _showEditModal(BuildContext context, WidgetRef ref, Map<String, dynamic> user, UsuariosState state) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => _UserEditForm(user: user, roles: state.roles, sedes: state.sedes,
        isSuperAdmin: ref.read(authProvider).user?.isSuperAdmin ?? false,
        onSave: (data) async {
          try {
            await ref.read(usuariosProvider.notifier).updateUser(user['id'] as String, data);
            if (context.mounted) { Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado'))); }
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }));
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, Map<String, dynamic> user) async {
    final ok = await ConfirmDialog.show(context: context, title: 'Desactivar usuario',
        description: 'Se desactivara la cuenta de "${user['username']}". Podra reactivarla despues.',
        confirmLabel: 'Desactivar', isDanger: true);
    if (ok && context.mounted) {
      try {
        await ref.read(usuariosProvider.notifier).deactivateUser(user['id'] as String);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario desactivado')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _resetPassword(BuildContext context, WidgetRef ref, String id) async {
    try {
      final result = await ref.read(usuariosProvider.notifier).resetPassword(id);
      if (context.mounted) {
        final tempPwd = result?['tempPassword'] as String? ?? '';
        showDialog(context: context, builder: (_) => AlertDialog(
          title: const Text('Contrasena temporal'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('La contrasena temporal es:'),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(tempPwd, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            const SizedBox(height: 8),
            const Text('El usuario debera cambiarla al iniciar sesion.', style: AppTextStyles.bodySmall),
          ]),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
        ));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ─── User Tile ────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final AuthState auth;
  final VoidCallback onTap, onEdit, onDeactivate, onReactivate, onResetPassword;
  const _UserTile({required this.user, required this.auth, required this.onTap,
      required this.onEdit, required this.onDeactivate, required this.onReactivate, required this.onResetPassword});

  @override
  Widget build(BuildContext context) {
    final username = user['username'] as String? ?? '';
    final role = user['rol']?['nombre'] as String? ?? '';
    final sede = user['sede']?['nombre'] as String?;
    final activo = user['activo'] as bool? ?? false;
    final mustChange = user['mustChangePassword'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AppCard(onTap: onTap, child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: AppColors.avatarColor(username),
          child: Text(FormatUtils.initials(username),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(username, style: AppTextStyles.titleMedium),
            if (mustChange) ...[const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 14)],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            RoleBadge(role: role),
            if (sede != null) ...[const SizedBox(width: 6),
              Text(sede, style: AppTextStyles.labelSmall)],
          ]),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusBadge(activo: activo),
          const SizedBox(height: 4),
          _ActionsMenu(user: user, auth: auth, onEdit: onEdit,
              onDeactivate: onDeactivate, onReactivate: onReactivate, onResetPassword: onResetPassword),
        ]),
      ])),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final Map<String, dynamic> user;
  final AuthState auth;
  final VoidCallback onEdit, onDeactivate, onReactivate, onResetPassword;
  const _ActionsMenu({required this.user, required this.auth, required this.onEdit,
      required this.onDeactivate, required this.onReactivate, required this.onResetPassword});

  @override
  Widget build(BuildContext context) {
    final activo = user['activo'] as bool? ?? false;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        else if (v == 'deactivate') onDeactivate();
        else if (v == 'reactivate') onReactivate();
        else if (v == 'reset') onResetPassword();
      },
      itemBuilder: (_) => [
        if (auth.hasPermission('usuarios:editar'))
          const PopupMenuItem(value: 'edit', child: Row(children: [
            Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Editar')])),
        if (auth.hasPermission('usuarios:resetear-password'))
          const PopupMenuItem(value: 'reset', child: Row(children: [
            Icon(Icons.lock_reset_rounded, size: 16), SizedBox(width: 8), Text('Resetear contrasena')])),
        if (auth.hasPermission('usuarios:eliminar'))
          activo
            ? const PopupMenuItem(value: 'deactivate', child: Row(children: [
                Icon(Icons.block_rounded, size: 16, color: AppColors.error), SizedBox(width: 8),
                Text('Desactivar', style: TextStyle(color: AppColors.error))]))
            : const PopupMenuItem(value: 'reactivate', child: Row(children: [
                Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success), SizedBox(width: 8),
                Text('Reactivar', style: TextStyle(color: AppColors.success))])),
      ],
    );
  }
}

// ─── User Detail ──────────────────────────────────────────────────────────────

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
      'Cambio de contrasena requerido': (user['mustChangePassword'] as bool? ?? false) ? 'Si' : 'No',
      'Creado': user['createdAt'] as String? ?? '',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in items.entries) ...[
        Row(children: [
          Expanded(child: Text(e.key, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textTertiary))),
          Expanded(flex: 2, child: Text(e.value, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary))),
        ]),
        const Divider(height: 16),
      ],
    ]);
  }
}

// ─── User Form ────────────────────────────────────────────────────────────────

class _UserForm extends StatefulWidget {
  final List<Map<String, dynamic>> roles, sedes;
  final bool isSuperAdmin;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _UserForm({required this.roles, required this.sedes, required this.isSuperAdmin, required this.onSave});
  @override State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _rolId, _sedeId;
  bool _loading = false;

  @override void dispose() { _userCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            const Text('Nuevo usuario', style: AppTextStyles.headlineMedium),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          ])),
        const Divider(),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
          child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppTextField(label: 'Usuario', hint: 'Nombre de usuario', controller: _userCtrl,
                prefixIcon: Icons.person_outline_rounded, textInputAction: TextInputAction.next,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
            const SizedBox(height: 14),
            AppTextField(label: 'Contrasena temporal', hint: 'Minimo 12 caracteres', controller: _passCtrl,
                prefixIcon: Icons.lock_outline_rounded, obscureText: true,
                validator: (v) { if (v == null || v.isEmpty) return 'Requerido';
                  if (v.length < 12) return 'Minimo 12 caracteres'; return null; }),
            const SizedBox(height: 14),
            _label('Rol'),
            DropdownButtonFormField<String>(value: _rolId, hint: const Text('Seleccionar rol'),
              items: widget.roles.map((r) => DropdownMenuItem(value: r['id'] as String,
                  child: Text(r['nombre'] as String? ?? ''))).toList(),
              onChanged: (v) => setState(() => _rolId = v),
              validator: (v) => v == null ? 'Requerido' : null),
            if (widget.isSuperAdmin) ...[
              const SizedBox(height: 14),
              _label('Sede'),
              DropdownButtonFormField<String>(value: _sedeId, hint: const Text('Seleccionar sede (opcional)'),
                items: [const DropdownMenuItem(value: null, child: Text('Sin sede')),
                  ...widget.sedes.map((s) => DropdownMenuItem(value: s['id'] as String,
                      child: Text(s['nombre'] as String? ?? '')))],
                onChanged: (v) => setState(() => _sedeId = v)),
            ],
            const SizedBox(height: 24),
            PrimaryButton(label: 'Crear usuario', isLoading: _loading, onPressed: _submit),
          ])))),
      ]));
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await widget.onSave({'username': _userCtrl.text.trim(), 'password': _passCtrl.text,
          'rolId': _rolId, if (_sedeId != null) 'sedeId': _sedeId});
    } finally { if (mounted) setState(() => _loading = false); }
  }
}

class _UserEditForm extends StatefulWidget {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> roles, sedes;
  final bool isSuperAdmin;
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _UserEditForm({required this.user, required this.roles, required this.sedes,
      required this.isSuperAdmin, required this.onSave});
  @override State<_UserEditForm> createState() => _UserEditFormState();
}

class _UserEditFormState extends State<_UserEditForm> {
  late String? _rolId, _sedeId;
  bool _loading = false;

  @override void initState() {
    super.initState();
    _rolId = widget.user['rol']?['id'] as String?;
    _sedeId = widget.user['sede']?['id'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            const Text('Editar usuario', style: AppTextStyles.headlineMedium), const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          ])),
        const Divider(),
        SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label('Rol'),
          DropdownButtonFormField<String>(value: _rolId,
            items: widget.roles.map((r) => DropdownMenuItem(value: r['id'] as String,
                child: Text(r['nombre'] as String? ?? ''))).toList(),
            onChanged: (v) => setState(() => _rolId = v)),
          if (widget.isSuperAdmin) ...[
            const SizedBox(height: 14),
            _label('Sede'),
            DropdownButtonFormField<String>(value: _sedeId,
              items: [const DropdownMenuItem(value: null, child: Text('Sin sede')),
                ...widget.sedes.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['nombre'] as String? ?? '')))],
              onChanged: (v) => setState(() => _sedeId = v)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Guardar cambios', isLoading: _loading, onPressed: _submit),
        ])),
      ]));
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Text(t, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w500, color: AppColors.textSecondary)));

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{};
      if (_rolId != null) data['rolId'] = _rolId;
      if (_sedeId != null) data['sedeId'] = _sedeId;
      await widget.onSave(data);
    } finally { if (mounted) setState(() => _loading = false); }
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      Text(label, style: AppTextStyles.labelSmall),
    ]));
}
