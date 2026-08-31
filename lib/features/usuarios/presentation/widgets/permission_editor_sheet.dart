import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/models/usuario_permission_models.dart';
import '../../data/usuario_admin_repository.dart';

/// SUPERADMIN-only permission editor. Loads effective permissions via GET,
/// groups by module, allows individual and module-level toggle, atomic PUT.
class PermissionEditorSheet extends StatefulWidget {
  final String userId, username;
  final UsuarioAdminRepository repo;
  const PermissionEditorSheet({required this.userId, required this.username, required this.repo, super.key});
  @override
  State<PermissionEditorSheet> createState() => _EditorState();
}

class _EditorState extends State<PermissionEditorSheet> {
  UsuarioPermisosResponse? _data;
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.repo.getPermissions(widget.userId);
      if (mounted) setState(() { _data = r; _loading = false; });
    } on AppException catch (e) {
      if (mounted) setState(() { _loading = false; _error = '${e.statusCode}: ${e.message}'; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  (Set<String>, Set<String>) _exceptions() {
    final d = _data;
    if (d == null) return ({}, {});
    return (d.permisosAdicionales.map((p) => p.id).toSet(), d.permisosRevocados.map((p) => p.id).toSet());
  }

  Future<void> _togglePermission(EffectivePermission p) async {
    if (_data == null || _saving) return;
    final (adds, revs) = _exceptions();
    if (p.activo) { adds.remove(p.id); if (p.porRol) revs.add(p.id); }
    else { revs.remove(p.id); if (!p.porRol) adds.add(p.id); }
    await _save(adds.toList(), revs.toList());
  }

  Future<void> _toggleModule(String modulo) async {
    if (_data == null || _saving) return;
    final perms = _data!.permisosEfectivos.where((p) => p.modulo == modulo).toList();
    final allActive = perms.every((p) => p.activo);
    final (adds, revs) = _exceptions();
    for (final p in perms) {
      if (allActive) { adds.remove(p.id); if (p.porRol) revs.add(p.id); }
      else { revs.remove(p.id); if (!p.porRol && !p.activo) adds.add(p.id); }
    }
    await _save(adds.toList(), revs.toList());
  }

  Future<void> _save(List<String> addIds, List<String> revIds) async {
    setState(() => _saving = true);
    try {
      final r = await widget.repo.replacePermissions(
        widget.userId, ReplacePermissionsPayload(permisoIds: addIds, permisoIdsRevocados: revIds));
      if (mounted) setState(() { _data = r; _saving = false; });
    } on AppException catch (e) {
      if (mounted) setState(() { _saving = false; _error = '${e.statusCode}: ${e.message}'; });
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16),
        OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
      ])));
    final d = _data!;
    final modules = d.permisosEfectivos.map((p) => p.modulo).toSet().toList()..sort();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Icon(Icons.shield_outlined, size: 20, color: Colors.deepPurple), const SizedBox(width: 8),
        Text('Permisos: ${widget.username}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 4, children: [
        _chip('Rol: ${d.usuario.rol}', Colors.green),
        _chip('${d.permisosPorRol.length} heredados', Colors.blue),
        _chip('${d.permisosAdicionales.length} concesiones', Colors.purple),
        _chip('${d.permisosRevocados.length} revocaciones', Colors.red),
      ]),
      const SizedBox(height: 16),
      for (final m in modules) ...[_moduleSection(m, d), const SizedBox(height: 12)],
    ]);
  }

  Widget _moduleSection(String modulo, UsuarioPermisosResponse d) {
    final perms = d.permisosEfectivos.where((p) => p.modulo == modulo).toList();
    final allActive = perms.every((p) => p.activo);
    final active = perms.where((p) => p.activo).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(modulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.orange)),
          Text('$active de ${perms.length} activas', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ])),
        TextButton(key: Key('module-toggle-$modulo'), onPressed: _saving ? null : () => _toggleModule(modulo),
          child: Text(allActive ? 'Revocar todo' : 'Habilitar todo',
            style: TextStyle(fontSize: 11, color: allActive ? Colors.red : Colors.deepPurple))),
      ]),
      for (final p in perms) _permRow(p),
    ]);
  }

  Widget _permRow(EffectivePermission p) {
    final label = p.porRol && !p.revocado ? 'Heredado' : p.adicional ? 'Concedido' : p.revocado ? 'Revocado' : '—';
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
      Switch(key: Key('perm-toggle-${p.id}'), value: p.activo, onChanged: _saving ? null : (_) => _togglePermission(p)),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text('$label · ${p.descripcion}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ])),
    ]));
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)));
}
