import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/sede_scope_provider.dart';
import '../theme/app_colors.dart';

class SedeScopeSelector extends ConsumerWidget {
  final bool compact;

  const SedeScopeSelector({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final selectedId = ref.watch(globalSedeIdProvider);
    final options = ref.watch(sedeScopeOptionsProvider);
    final selected = options.valueOrNull
        ?.where((sede) => sede.id == selectedId)
        .firstOrNull;
    final label = user?.isSuperAdmin == true
        ? selected?.nombre ?? 'Todas las sedes'
        : user?.sede ?? 'Sin sede';

    return Tooltip(
      message: 'Alcance de datos: $label',
      child: InkWell(
        key: const Key('global-sede-selector'),
        onTap: user?.isSuperAdmin == true
            ? () => _showPicker(context, ref, options)
            : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          constraints: BoxConstraints(maxWidth: compact ? 150 : 240),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: context.colors.backgroundAlt,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              if (user?.isSuperAdmin == true) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<SedeScopeOption>> options,
  ) async {
    if (options.isLoading) return;
    if (options.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar las sedes: ${options.error}'),
        ),
      );
      ref.invalidate(sedeScopeOptionsProvider);
      return;
    }

    final selectedId = ref.read(globalSedeIdProvider);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Seleccionar sede',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            _option(
              sheetContext,
              ref,
              id: null,
              label: 'Todas las sedes',
              selected: selectedId == null,
            ),
            for (final sede in options.value ?? const <SedeScopeOption>[])
              _option(
                sheetContext,
                ref,
                id: sede.id,
                label: sede.nombre,
                subtitle: sede.codigoSede,
                selected: selectedId == sede.id,
              ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    WidgetRef ref, {
    required String? id,
    required String label,
    required bool selected,
    String? subtitle,
  }) => ListTile(
    dense: true,
    title: Text(label),
    subtitle: subtitle?.isNotEmpty == true ? Text(subtitle!) : null,
    trailing: selected
        ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 19)
        : null,
    onTap: () {
      ref.read(globalSedeIdProvider.notifier).select(id);
      Navigator.of(context).pop();
    },
  );
}
