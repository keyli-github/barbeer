import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';

class ComprasScreen extends StatefulWidget {
  const ComprasScreen({super.key});
  @override State<ComprasScreen> createState() => _ComprasScreenState();
}

class _ComprasScreenState extends State<ComprasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _statusFilter = 'Todas';

  static final _orders = [
    {'id':'OC-001','proveedor':'Bodega Don Pedro','estado':'Recibida','total':450.0,'items':3,'fecha':DateTime.now().subtract(const Duration(days:5)),'estimada':DateTime.now().subtract(const Duration(days:3))},
    {'id':'OC-002','proveedor':'Distribuidora Norte','estado':'Enviada','total':820.0,'items':5,'fecha':DateTime.now().subtract(const Duration(days:2)),'estimada':DateTime.now().add(const Duration(days:1))},
    {'id':'OC-003','proveedor':'Importaciones Sur','estado':'Pendiente','total':1200.0,'items':8,'fecha':DateTime.now().subtract(const Duration(days:1)),'estimada':DateTime.now().add(const Duration(days:5))},
    {'id':'OC-004','proveedor':'Bodega Don Pedro','estado':'Cancelada','total':300.0,'items':2,'fecha':DateTime.now().subtract(const Duration(days:10)),'estimada':DateTime.now().subtract(const Duration(days:7))},
  ];

  static final _proveedores = [
    {'nombre':'Bodega Don Pedro','contacto':'Juan Perez','telefono':'987654321','email':'juan@bodegas.com','ordenes':12,'total':8500.0},
    {'nombre':'Distribuidora Norte','contacto':'Maria Gomez','telefono':'976543210','email':'maria@distnorte.com','ordenes':8,'total':12000.0},
    {'nombre':'Importaciones Sur','contacto':'Carlos Lopez','telefono':'965432109','email':'carlos@impsur.com','ordenes':5,'total':6800.0},
  ];

  @override void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  List get filteredOrders => _orders.where((o) => _statusFilter == 'Todas' || o['estado'] == _statusFilter).toList();

  @override
  Widget build(BuildContext context) {
    final pendiente = _orders.where((o) => o['estado'] == 'Pendiente').length;
    final enviada = _orders.where((o) => o['estado'] == 'Enviada').length;
    final pendienteTotal = _orders.where((o) => o['estado'] == 'Pendiente' || o['estado'] == 'Enviada').fold(0.0, (s, o) => s + (o['total'] as double));

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.shopping_cart_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Compras', style: AppTextStyles.headlineLarge)),
          ])),
          TabBar(controller: _tabs, indicatorColor: AppColors.primary, labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary, tabs: const [Tab(text: 'Ordenes'), Tab(text: 'Proveedores')]),
        ])),
        Expanded(child: TabBarView(controller: _tabs, children: [
          // Ordenes tab
          Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
              _StatChip(label: 'Pendientes', value: '$pendiente', color: AppColors.warning),
              const SizedBox(width: 8),
              _StatChip(label: 'En camino', value: '$enviada', color: AppColors.primary),
              const SizedBox(width: 8),
              _StatChip(label: 'Por pagar', value: 'S/${pendienteTotal.toStringAsFixed(0)}', color: AppColors.error),
            ])),
            const SizedBox(height: 8),
            SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: ['Todas','Pendiente','Enviada','Recibida','Cancelada'].map((s) =>
                GestureDetector(onTap: () => setState(() => _statusFilter = s),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: _statusFilter == s ? AppColors.primarySurface : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: _statusFilter == s ? AppColors.primaryBorder : AppColors.border)),
                    child: Text(s, style: TextStyle(fontSize: 12, fontWeight: _statusFilter == s ? FontWeight.w700 : FontWeight.w500, color: _statusFilter == s ? AppColors.primary : AppColors.textSecondary))))).toList())),
            Expanded(child: filteredOrders.isEmpty ? const AppEmptyState(icon: Icons.shopping_cart_outlined, title: 'Sin ordenes')
              : ListView(children: [
                  for (final order in filteredOrders)
                    Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: AppCard(onTap: () => _showOrderDetail(context, order), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(order['id'] as String, style: AppTextStyles.titleMedium),
                            Text(order['proveedor'] as String, style: AppTextStyles.bodySmall),
                          ])),
                          _StatusBadge(status: order['estado'] as String),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textTertiary), const SizedBox(width: 4),
                          Text('${order['items']} items', style: AppTextStyles.labelSmall), const SizedBox(width: 12),
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textTertiary), const SizedBox(width: 4),
                          Text(_fmtDate(order['fecha'] as DateTime), style: AppTextStyles.labelSmall), const Spacer(),
                          Text('S/ ${(order['total'] as double).toStringAsFixed(2)}',
                              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
                        ]),
                      ]))),
                  const SizedBox(height: 80),
                ])),
          ]),

          // Proveedores tab
          ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), children: [
            for (final p in _proveedores)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['nombre'] as String, style: AppTextStyles.titleMedium),
                    Text(p['contacto'] as String, style: AppTextStyles.bodySmall),
                  ])),
                ]),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  _InfoChip(icon: Icons.phone_rounded, label: p['telefono'] as String),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.receipt_long_rounded, label: '${p['ordenes']} ordenes'),
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.attach_money_rounded, label: 'S/${(p['total'] as double).toStringAsFixed(0)}'),
                ]),
              ]))),
          ]),
        ])),
      ])));
  }

  void _showOrderDetail(BuildContext context, Map order) {
    final estados = ['Pendiente', 'Enviada', 'Recibida'];
    AppBottomSheet.show(context: context, title: 'Orden ${order['id']}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('Proveedor:', style: AppTextStyles.bodySmall), const SizedBox(width: 8), Text(order['proveedor'] as String, style: AppTextStyles.bodyMedium)]),
        const SizedBox(height: 8),
        Row(children: [const Text('Estado:', style: AppTextStyles.bodySmall), const SizedBox(width: 8), _StatusBadge(status: order['estado'] as String)]),
        const SizedBox(height: 16),
        const Text('Progreso', style: AppTextStyles.titleMedium),
        const SizedBox(height: 10),
        Row(children: estados.map((s) {
          final idx = estados.indexOf(s);
          final current = estados.indexOf(order['estado'] as String);
          final done = idx <= current;
          return Expanded(child: Row(children: [
            Column(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: done ? AppColors.primary : AppColors.backgroundAlt, shape: BoxShape.circle, border: Border.all(color: done ? AppColors.primary : AppColors.border)),
                  child: Icon(done ? Icons.check_rounded : Icons.circle_outlined, size: 14, color: done ? Colors.white : AppColors.textTertiary)),
              const SizedBox(height: 4),
              Text(s, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: done ? AppColors.primary : AppColors.textTertiary)),
            ]),
            if (idx < estados.length - 1) Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 18), color: done ? AppColors.primary : AppColors.border)),
          ]));
        }).toList()),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total:', style: AppTextStyles.titleMedium),
          Text('S/ ${(order['total'] as double).toStringAsFixed(2)}', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
        ]),
      ]));
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _StatusBadge extends StatelessWidget {
  final String status; const _StatusBadge({required this.status});
  @override Widget build(BuildContext context) {
    Color c; switch(status){ case 'Recibida':c=AppColors.success;break; case 'Enviada':c=AppColors.primary;break; case 'Cancelada':c=AppColors.error;break; default:c=AppColors.warning; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)));
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoChip({required this.icon, required this.label});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(AppRadius.full)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: AppColors.textTertiary), const SizedBox(width: 4), Text(label, style: AppTextStyles.labelSmall)]));
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)), Text(label, style: AppTextStyles.labelSmall)])));
}
