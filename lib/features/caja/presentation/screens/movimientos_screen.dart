import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
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
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
          children: [
            Text('Movimientos del día', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 4),
            Text(
              'Historial de ventas, ingresos y egresos de caja.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
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
                  builder: (context, constraints) => constraints.maxWidth >= 800
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
    );
  }
}

class _Filters extends StatelessWidget {
  final MovimientosState state;
  final MovimientosNotifier notifier;

  const _Filters({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) => AppCard(
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: state.isLoading ? null : () => _pickDate(context, true),
          icon: const Icon(Icons.calendar_today_outlined, size: 17),
          label: Text(
            'Desde ${DateFormat('dd/MM/yyyy').format(state.fechaInicio)}',
          ),
        ),
        OutlinedButton.icon(
          onPressed: state.isLoading ? null : () => _pickDate(context, false),
          icon: const Icon(Icons.event_outlined, size: 17),
          label: Text(
            'Hasta ${DateFormat('dd/MM/yyyy').format(state.fechaFin)}',
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            key: ValueKey(state.tipo),
            initialValue: state.tipo,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos los tipos')),
              DropdownMenuItem(value: 'ENTRADA', child: Text('Entradas')),
              DropdownMenuItem(value: 'SALIDA', child: Text('Salidas')),
            ],
            onChanged: state.isLoading ? null : notifier.filtrarTipo,
          ),
        ),
      ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha inicial no puede ser posterior a la final.'),
        ),
      );
      return;
    }
    await notifier.filtrarFechas(inicio, fin);
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
          children: [
            Icon(
              incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
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
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_dateTime(movement.createdAt)} · ${_label(movement)} · ${_user(movement)}',
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${incoming ? '+' : '-'} ${_money(movement.monto)}',
              style: AppTextStyles.labelLarge.copyWith(color: color),
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
