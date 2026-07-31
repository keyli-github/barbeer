import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class CajaMovimiento {
  final String id, tipo, concepto, metodoPago;
  final double monto;
  final DateTime fecha;
  const CajaMovimiento({required this.id, required this.tipo, required this.concepto,
      required this.metodoPago, required this.monto, required this.fecha});
}

class CajaState {
  final List<CajaMovimiento> movimientos;
  final double saldoInicial;
  final bool cajaAbierta;
  const CajaState({this.movimientos = const [], this.saldoInicial = 500.0, this.cajaAbierta = true});
  double get ingresos => movimientos.where((m) => m.tipo == 'INGRESO').fold(0, (s, m) => s + m.monto);
  double get egresos => movimientos.where((m) => m.tipo == 'EGRESO').fold(0, (s, m) => s + m.monto);
  double get saldoActual => saldoInicial + ingresos - egresos;
}

class CajaNotifier extends StateNotifier<CajaState> {
  CajaNotifier() : super(CajaState(movimientos: _mock));
  static final _mock = [
    CajaMovimiento(id:'1',tipo:'INGRESO',concepto:'Apertura de caja',metodoPago:'Efectivo',monto:500,fecha:DateTime.now().subtract(const Duration(hours:6))),
    CajaMovimiento(id:'2',tipo:'INGRESO',concepto:'Venta POS',metodoPago:'Efectivo',monto:125,fecha:DateTime.now().subtract(const Duration(hours:4))),
    CajaMovimiento(id:'3',tipo:'INGRESO',concepto:'Venta POS',metodoPago:'Tarjeta',monto:85,fecha:DateTime.now().subtract(const Duration(hours:3))),
    CajaMovimiento(id:'4',tipo:'EGRESO',concepto:'Pago proveedor',metodoPago:'Efectivo',monto:200,fecha:DateTime.now().subtract(const Duration(hours:2))),
    CajaMovimiento(id:'5',tipo:'INGRESO',concepto:'Venta POS',metodoPago:'Efectivo',monto:220,fecha:DateTime.now().subtract(const Duration(hours:1))),
    CajaMovimiento(id:'6',tipo:'EGRESO',concepto:'Propinas staff',metodoPago:'Efectivo',monto:50,fecha:DateTime.now().subtract(const Duration(minutes:30))),
  ];

  void addEgreso(String concepto, double monto) {
    state = CajaState(movimientos: [...state.movimientos,
      CajaMovimiento(id: DateTime.now().toString(), tipo: 'EGRESO', concepto: concepto, metodoPago: 'Efectivo', monto: monto, fecha: DateTime.now())],
      saldoInicial: state.saldoInicial, cajaAbierta: state.cajaAbierta);
  }
  void cerrarCaja() => state = CajaState(movimientos: state.movimientos, saldoInicial: state.saldoInicial, cajaAbierta: false);
}

final cajaProvider = StateNotifierProvider<CajaNotifier, CajaState>((ref) => CajaNotifier());

class CajaScreen extends ConsumerWidget {
  const CajaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cajaProvider);
    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: CustomScrollView(slivers: [
        SliverAppBar(floating: true, snap: true, backgroundColor: AppColors.background, elevation: 0, scrolledUnderElevation: 0,
          leading: Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary), onPressed: () => Scaffold.of(ctx).openDrawer())),
          title: Row(children: [
            const Text('Caja', style: AppTextStyles.appBarTitle),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: state.cajaAbierta ? AppColors.successLight : AppColors.errorLight, borderRadius: BorderRadius.circular(100)),
              child: Text(state.cajaAbierta ? 'Abierta' : 'Cerrada',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: state.cajaAbierta ? AppColors.success : AppColors.error))),
          ]),
          actions: [
            if (state.cajaAbierta) ...[
              TextButton(onPressed: () => _showEgreso(context, ref), child: const Text('+ Egreso')),
              TextButton(onPressed: () => _confirmCerrar(context, ref),
                  child: const Text('Cerrar caja', style: TextStyle(color: AppColors.error))),
            ],
          ]),
        SliverPadding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            Row(children: [
              Expanded(child: _KpiCard(label: 'Saldo inicial', value: state.saldoInicial, icon: Icons.account_balance_wallet_rounded, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(label: 'Ingresos', value: state.ingresos, icon: Icons.trending_up_rounded, color: AppColors.success)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _KpiCard(label: 'Egresos', value: state.egresos, icon: Icons.trending_down_rounded, color: AppColors.error)),
              const SizedBox(width: 10),
              Expanded(child: _KpiCard(label: 'Saldo actual', value: state.saldoActual, icon: Icons.account_balance_rounded, color: AppColors.primary)),
            ]),
            const SizedBox(height: 20),
            _DesglosePago(movimientos: state.movimientos),
            const SizedBox(height: 20),
            Row(children: [const Text('Movimientos', style: AppTextStyles.titleLarge), const Spacer(),
              Text('${state.movimientos.length} registros', style: AppTextStyles.bodySmall)]),
            const SizedBox(height: 10),
            for (final m in state.movimientos.reversed)
              Padding(padding: const EdgeInsets.only(bottom: 6), child: AppCard(
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: m.tipo == 'INGRESO' ? AppColors.successLight : AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
                    child: Icon(m.tipo == 'INGRESO' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: m.tipo == 'INGRESO' ? AppColors.success : AppColors.error, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.concepto, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                    Text('${m.metodoPago} · ${m.fecha.hour.toString().padLeft(2,'0')}:${m.fecha.minute.toString().padLeft(2,'0')}', style: AppTextStyles.labelSmall),
                  ])),
                  Text('${m.tipo == 'INGRESO' ? '+' : '-'} S/ ${m.monto.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                          color: m.tipo == 'INGRESO' ? AppColors.success : AppColors.error)),
                ]))),
          ]))),
      ])));
  }

  void _showEgreso(BuildContext context, WidgetRef ref) {
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const Text('Registrar egreso', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          TextField(controller: conceptoCtrl, decoration: const InputDecoration(labelText: 'Concepto', prefixIcon: Icon(Icons.description_rounded))),
          const SizedBox(height: 12),
          TextField(controller: montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monto (S/)', prefixIcon: Icon(Icons.attach_money_rounded))),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
            onPressed: () { final m = double.tryParse(montoCtrl.text) ?? 0;
              if (conceptoCtrl.text.isNotEmpty && m > 0) { ref.read(cajaProvider.notifier).addEgreso(conceptoCtrl.text, m); Navigator.of(context).pop(); } },
            child: const Text('Registrar egreso'))),
        ]))));
  }

  Future<void> _confirmCerrar(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmDialog.show(context: context, title: 'Cerrar caja', description: 'Se cerrara la caja del dia.', confirmLabel: 'Cerrar caja', isDanger: true);
    if (ok) ref.read(cajaProvider.notifier).cerrarCaja();
  }
}

class _KpiCard extends StatelessWidget {
  final String label; final double value; final IconData icon; final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});
  @override Widget build(BuildContext context) => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(icon, color: color, size: 20), const Spacer(),
      Text(label, style: AppTextStyles.labelSmall)]),
    const SizedBox(height: 8),
    Text('S/ ${value.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
  ]));
}

class _DesglosePago extends StatelessWidget {
  final List<CajaMovimiento> movimientos;
  const _DesglosePago({required this.movimientos});
  @override Widget build(BuildContext context) {
    final methods = <String, double>{};
    for (final m in movimientos.where((m) => m.tipo == 'INGRESO')) {
      methods[m.metodoPago] = (methods[m.metodoPago] ?? 0) + m.monto;
    }
    final total = methods.values.fold(0.0, (a, b) => a + b);
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Desglose por metodo', style: AppTextStyles.titleMedium),
      const SizedBox(height: 12),
      for (final e in methods.entries) ...[
        Row(children: [
          SizedBox(width: 100, child: Text(e.key, style: AppTextStyles.bodySmall)),
          const SizedBox(width: 8),
          Expanded(child: Stack(children: [
            Container(height: 8, decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(widthFactor: total > 0 ? e.value / total : 0,
              child: Container(height: 8, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)))),
          ])),
          const SizedBox(width: 8),
          Text('S/ ${e.value.toStringAsFixed(0)}', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
      ],
    ]));
  }
}
