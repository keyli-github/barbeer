import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../providers/recargo_control_provider.dart';

class RecargoControlSheet extends ConsumerStatefulWidget {
  const RecargoControlSheet({super.key});

  @override
  ConsumerState<RecargoControlSheet> createState() =>
      _RecargoControlSheetState();
}

class _RecargoControlSheetState extends ConsumerState<RecargoControlSheet> {
  final keyController = TextEditingController();
  final configKeyController = TextEditingController();
  final responsables = <String, String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(recargoControlProvider.notifier).loadConfiguration(),
    );
  }

  @override
  void dispose() {
    keyController.dispose();
    configKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recargoControlProvider);
    if (!state.puedeConfigurar && !state.puedeCambiar) {
      return const SizedBox.shrink();
    }
    for (final sede in state.data.sedes) {
      responsables.putIfAbsent(sede.id, () => sede.responsableId ?? '');
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.visibility_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control de recargos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.oculto ? 'Recargos ocultos' : 'Recargos visibles',
                        style: TextStyle(
                          color: state.oculto
                              ? AppColors.warning
                              : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.errorLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        state.error!.message,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.puedeConfigurar && state.data.sedes.isNotEmpty)
                    _section(
                      context,
                      title: 'Configuración',
                      description:
                          'Define la clave y el responsable de cada sede.',
                      children: [
                        TextField(
                          key: const Key('recargo-config-key'),
                          controller: configKeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: state.configurado
                                ? 'Nueva clave (opcional)'
                                : 'Clave de acceso',
                          ),
                        ),
                        for (final sede in state.data.sedes) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey('recargo-responsable-${sede.id}'),
                            initialValue:
                                responsables[sede.id]?.isNotEmpty == true
                                ? responsables[sede.id]
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Responsable de ${sede.nombre}',
                            ),
                            hint: const Text('Selecciona un responsable'),
                            items: sede.usuarios
                                .map(
                                  (user) => DropdownMenuItem(
                                    value: user.id,
                                    child: Text(user.username),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                responsables[sede.id] = value ?? '',
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () async {
                            await ref
                                .read(recargoControlProvider.notifier)
                                .guardar(
                                  clave: configKeyController.text.isEmpty
                                      ? null
                                      : configKeyController.text,
                                  responsables: responsables,
                                );
                            if (context.mounted &&
                                ref.read(recargoControlProvider).error ==
                                    null) {
                              AppFeedback.success(
                                context,
                                'Configuración guardada',
                              );
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar configuración'),
                        ),
                      ],
                    ),
                  if (state.puedeConfigurar &&
                      state.data.sedes.isNotEmpty &&
                      state.puedeCambiar &&
                      state.configurado)
                    const SizedBox(height: 16),
                  if (state.puedeCambiar && state.configurado)
                    _section(
                      context,
                      title: state.oculto
                          ? 'Mostrar recargos'
                          : 'Ocultar recargos',
                      description: state.oculto
                          ? 'Restaura la visualización de recargos en ventas.'
                          : 'Oculta temporalmente los recargos en ventas.',
                      children: [
                        TextField(
                          key: const Key('recargo-control-key'),
                          controller: keyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Clave de acceso',
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('recargo-control-toggle'),
                          onPressed: () => ref
                              .read(recargoControlProvider.notifier)
                              .cambiar(
                                clave: keyController.text,
                                oculto: !state.oculto,
                              ),
                          icon: Icon(
                            state.oculto
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          label: Text(
                            state.oculto
                                ? 'Restaurar recargos'
                                : 'Ocultar recargos',
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}
