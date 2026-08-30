import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recargo_control_provider.dart';

class RecargoControlSheet extends ConsumerStatefulWidget {
  const RecargoControlSheet({super.key});
  @override
  ConsumerState<RecargoControlSheet> createState() => _RecargoControlSheetState();
}
class _RecargoControlSheetState extends ConsumerState<RecargoControlSheet> {
  final keyController = TextEditingController();
  final configKeyController = TextEditingController();
  final responsables = <String, String>{};
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(recargoControlProvider.notifier).loadConfiguration());
  }
  @override
  void dispose() { keyController.dispose(); configKeyController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recargoControlProvider);
    if (!state.puedeConfigurar && !state.puedeCambiar) return const SizedBox();
    for (final sede in state.data.sedes) {
      responsables.putIfAbsent(sede.id, () => sede.responsableId ?? '');
    }
    return SafeArea(child: ListView(shrinkWrap: true,
      padding: const EdgeInsets.all(20), children: [
      Text('Control de recargos', style: Theme.of(context).textTheme.titleLarge),
      Text(state.oculto ? 'Recargos ocultos' : 'Recargos visibles'),
      if (state.error != null) Text(state.error!.message),
      if (state.puedeConfigurar && state.data.sedes.isNotEmpty) ...[
        TextField(key: const Key('recargo-config-key'), controller: configKeyController,
          obscureText: true, decoration: InputDecoration(labelText:
            state.configurado ? 'Nueva clave (opcional)' : 'Clave de acceso')),
        for (final sede in state.data.sedes) DropdownButtonFormField<String>(
          initialValue: responsables[sede.id] as String?,
          decoration: InputDecoration(labelText: 'Responsable de ${sede.nombre}'),
          items: sede.usuarios.map((user) => DropdownMenuItem(
            value: user.id, child: Text(user.username))).toList(),
          onChanged: (value) => responsables[sede.id] = value ?? ''),
        FilledButton(onPressed: () => ref.read(recargoControlProvider.notifier).guardar(
          clave: configKeyController.text.isEmpty ? null : configKeyController.text,
          responsables: responsables), child: const Text('Guardar configuración')),
      ],
      if (state.puedeCambiar && state.configurado) ...[
        TextField(key: const Key('recargo-control-key'), controller: keyController,
          obscureText: true, decoration: const InputDecoration(labelText: 'Clave')),
        FilledButton(key: const Key('recargo-control-toggle'),
          onPressed: () => ref.read(recargoControlProvider.notifier).cambiar(
            clave: keyController.text, oculto: !state.oculto),
          child: Text(state.oculto ? 'Restaurar recargos' : 'Ocultar recargos')),
      ],
    ]));
  }
}
