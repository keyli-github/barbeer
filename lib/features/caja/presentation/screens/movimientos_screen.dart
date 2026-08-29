import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/caja_repository.dart';
import '../providers/movimientos_provider.dart';

class MovimientosScreen extends ConsumerWidget {
  const MovimientosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movimientosProvider);
    final isSuperAdmin = ref.watch(
      authProvider.select((auth) => auth.user?.isSuperAdmin ?? false),
    );
    final notifier = ref.read(movimientosProvider.notifier);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: notifier.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              children: [
                Text(
                  'Movimientos del día',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Historial de ventas, ingresos y egresos de caja.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 18),
                if (state.sedeId == null)
                  AppCard(
                    child: Text(
                      isSuperAdmin
                          ? 'Selecciona una sede en el encabezado para consultar sus movimientos.'
                          : 'Tu usuario no tiene una sede asignada.',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                else ...[
                  _Filters(state: state, notifier: notifier),
                  const SizedBox(height: 14),
                  if (state.error != null)
                    SizedBox(
                      height: 300,
                      child: AppErrorState(
                        message: state.error!,
                        onRetry: notifier.load,
                      ),
                    )
                  else if (state.isLoading)
                    const _LoadingRows()
                  else if (state.movimientos.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sin movimientos',
                        description:
                            'No se encontraron registros para los filtros seleccionados.',
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth >= 800
                          ? _DesktopTable(items: state.movimientos)
                          : Column(
                              children: [
                                for (final movement in state.movimientos)
                                  _MovementCard(movement: movement),
                              ],
                            ),
                    ),
                  _Pager(state: state, onPage: notifier.cambiarPagina),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final MovimientosState state;
  final MovimientosNotifier notifier;

  const _Filters({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final desde = _DateButton(
          label: 'Desde ${DateFormat('dd/MM/yyyy').format(state.fechaInicio)}',
          icon: Icons.calendar_today_outlined,
          enabled: !state.isLoading,
          onTap: () => _pickDate(context, true),
        );
        final hasta = _DateButton(
          label: 'Hasta ${DateFormat('dd/MM/yyyy').format(state.fechaFin)}',
          icon: Icons.event_outlined,
          enabled: !state.isLoading,
          onTap: () => _pickDate(context, false),
        );
        final tipo = _TipoDropdown(
          value: state.tipo,
          enabled: !state.isLoading,
          onChanged: notifier.filtrarTipo,
        );
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 3, child: desde),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: hasta),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: tipo),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: desde),
                const SizedBox(width: 10),
                Expanded(child: hasta),
              ],
            ),
            const SizedBox(height: 10),
            tipo,
          ],
        );
      },
    ),
  );

  Future<void> _pickDate(BuildContext context, bool start) async {
    final current = start ? state.fechaInicio : state.fechaFin;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final inicio = start ? picked : state.fechaInicio;
    final fin = start ? state.fechaFin : picked;
    if (inicio.isAfter(fin)) {
      if (!context.mounted) return;
      AppFeedback.error(
        context,
        'La fecha inicial no puede ser posterior a la final.',
      );
      return;
    }
    await notifier.filtrarFechas(inicio, fin);
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _DateButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TipoDropdown extends StatelessWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const _TipoDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value ?? '';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Tipo',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const ValueKey('movimientos-tipo'),
          value: selected,
          isExpanded: true,
          isDense: true,
          items: const [
            DropdownMenuItem(value: '', child: Text('Todos los tipos')),
            DropdownMenuItem(value: 'ENTRADA', child: Text('Entradas')),
            DropdownMenuItem(value: 'SALIDA', child: Text('Salidas')),
          ],
          onChanged: enabled ? (v) => onChanged(v == '' ? null : v) : null,
        ),
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  final List<CajaMovimiento> items;

  const _DesktopTable({required this.items});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Fecha / hora')),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Etiqueta')),
          DataColumn(label: Text('Concepto')),
          DataColumn(label: Text('Monto'), numeric: true),
          DataColumn(label: Text('Comprobante')),
          DataColumn(label: Text('Usuario')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(_dateTime(item.createdAt))),
                  DataCell(_TypeChip(type: item.tipo)),
                  DataCell(Text(_label(item))),
                  DataCell(
                    SizedBox(
                      width: 280,
                      child: Text(
                        item.concepto,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(_money(item.monto))),
                  DataCell(_ComprobanteButton(url: item.comprobante)),
                  DataCell(Text(_user(item))),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _MovementCard extends StatelessWidget {
  final CajaMovimiento movement;

  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final incoming = movement.tipo == 'ENTRADA';
    final color = incoming ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                incoming
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.concepto.isEmpty
                        ? 'Sin concepto'
                        : movement.concepto,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_dateTime(movement.createdAt)} · ${_label(movement)} · ${_user(movement)}',
                    style: AppTextStyles.labelSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (movement.comprobante?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    _ComprobanteButton(url: movement.comprobante),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${incoming ? '+' : '-'} ${_money(movement.monto)}',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5),
                  _TypeChip(type: movement.tipo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final incoming = type == 'ENTRADA';
    final color = incoming ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(type, style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _Pager extends StatelessWidget {
  final MovimientosState state;
  final ValueChanged<int> onPage;

  const _Pager({required this.state, required this.onPage});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Text('${state.total} registros', style: AppTextStyles.labelSmall),
        const Spacer(),
        IconButton.outlined(
          onPressed: state.pagina > 1 && !state.isLoading
              ? () => onPage(state.pagina - 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${state.pagina} / ${state.totalPaginas}',
            style: AppTextStyles.labelLarge,
          ),
        ),
        IconButton.outlined(
          onPressed: state.pagina < state.totalPaginas && !state.isLoading
              ? () => onPage(state.pagina + 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 300,
    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );
}

String _label(CajaMovimiento movement) =>
    movement.etiqueta ?? movement.medioPago ?? '-';

String _user(CajaMovimiento movement) =>
    movement.usuario.isEmpty ? 'Usuario no disponible' : movement.usuario;

String _dateTime(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());

String _money(double value) => 'S/ ${value.toStringAsFixed(2)}';

// ─── Botón/visor comprobante ─────────────────────────────────────────────────

class _ComprobanteButton extends StatelessWidget {
  final String? url;
  const _ComprobanteButton({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Text('—', style: TextStyle(color: context.colors.textTertiary));
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primary,
      ),
      icon: const Icon(Icons.visibility_outlined, size: 14),
      label: const Text(
        'Ver comprobante',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      onPressed: () => _show(context),
    );
  }

  void _show(BuildContext context) {
    final normalised = (url!.startsWith('http') || url!.startsWith('/'))
        ? url!
        : 'https://$url';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comprobante',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    normalised,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, chunk) => chunk == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No se pudo cargar la imagen.\n$normalised',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
