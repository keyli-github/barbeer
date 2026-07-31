import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';

class KardexScreen extends StatefulWidget {
  const KardexScreen({super.key});
  @override State<KardexScreen> createState() => _KardexScreenState();
}

class _KardexScreenState extends State<KardexScreen> {
  String _filter = 'Todos';
  final _search = TextEditingController();

  static final _mock = [
    {'id':'M001','tipo':'ENTRADA','producto':'Pisco','codigo':'CKT001','cantidad':20,'stockAntes':5,'stockDespues':25,'referencia':'OC-001','usuario':'admin','fecha':DateTime.now().subtract(const Duration(days:1))},
    {'id':'M002','tipo':'SALIDA','producto':'Cerveza Cusquena','codigo':'CRV001','cantidad':12,'stockAntes':36,'stockDespues':24,'referencia':'VTA-045','usuario':'cajero1','fecha':DateTime.now().subtract(const Duration(hours:5))},
    {'id':'M003','tipo':'ENTRADA','producto':'Ron Havana','codigo':'CKT002','cantidad':10,'stockAntes':2,'stockDespues':12,'referencia':'OC-002','usuario':'admin','fecha':DateTime.now().subtract(const Duration(hours:4))},
    {'id':'M004','tipo':'SALIDA','producto':'Limon Kg','codigo':'BCK002','cantidad':3,'stockAntes':5,'stockDespues':2,'referencia':'USO-001','usuario':'cocina1','fecha':DateTime.now().subtract(const Duration(hours:3))},
    {'id':'M005','tipo':'AJUSTE','producto':'Hielo Bolsa','codigo':'BCK001','cantidad':5,'stockAntes':7,'stockDespues':12,'referencia':'AJ-001','usuario':'admin','fecha':DateTime.now().subtract(const Duration(hours:2))},
    {'id':'M006','tipo':'TRASLADO','producto':'Malbec Trivento','codigo':'VNO001','cantidad':4,'stockAntes':12,'stockDespues':8,'referencia':'TRF-001','usuario':'admin','fecha':DateTime.now().subtract(const Duration(hours:1))},
  ];

  List get filtered => _mock.where((m) {
    final mt = _filter == 'Todos' || m['tipo'] == _filter;
    final ms = _search.text.isEmpty || (m['producto'] as String).toLowerCase().contains(_search.text.toLowerCase()) || (m['codigo'] as String).toLowerCase().contains(_search.text.toLowerCase());
    return mt && ms;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final f = filtered;
    final entradas = _mock.where((m) => m['tipo'] == 'ENTRADA').length;
    final salidas = _mock.where((m) => m['tipo'] == 'SALIDA').length;
    final total = _mock.length;

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.swap_vert_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Kardex', style: AppTextStyles.headlineLarge)),
            Text('$total mov.', style: AppTextStyles.bodySmall),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(controller: _search, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: ['Todos','ENTRADA','SALIDA','AJUSTE','TRASLADO'].map((t) =>
              GestureDetector(onTap: () => setState(() => _filter = t),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: _filter == t ? AppColors.primarySurface : AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: _filter == t ? AppColors.primaryBorder : AppColors.border)),
                  child: Text(t, style: TextStyle(fontSize: 12, fontWeight: _filter == t ? FontWeight.w700 : FontWeight.w500, color: _filter == t ? AppColors.primary : AppColors.textSecondary))))).toList())),
        ])),

        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
          _StatChip(label: 'Total', value: '$total', color: AppColors.primary),
          const SizedBox(width: 8),
          _StatChip(label: 'Entradas', value: '$entradas', color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'Salidas', value: '$salidas', color: AppColors.error),
        ])),
        const SizedBox(height: 8),

        Expanded(child: f.isEmpty
          ? const AppEmptyState(icon: Icons.swap_vert_outlined, title: 'Sin movimientos encontrados')
          : ListView(children: [
              for (final m in f)
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: AppCard(child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: _typeColor(m['tipo'] as String).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_typeIcon(m['tipo'] as String), color: _typeColor(m['tipo'] as String), size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(m['producto'] as String, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        _TypeBadge(tipo: m['tipo'] as String),
                      ]),
                      Text('${m['codigo']} · Ref: ${m['referencia']} · ${m['usuario']}', style: AppTextStyles.labelSmall),
                      Text('${m['stockAntes']} → ${m['stockDespues']} unidades', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimary)),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${m['tipo'] == 'SALIDA' ? '-' : '+'}${m['cantidad']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _typeColor(m['tipo'] as String))),
                      Text(_formatTime(m['fecha'] as DateTime), style: AppTextStyles.labelSmall),
                    ]),
                  ]))),
              const SizedBox(height: 80),
            ])),
      ])));
  }

  Color _typeColor(String t) { switch(t) { case 'ENTRADA': return AppColors.success; case 'SALIDA': return AppColors.error; case 'AJUSTE': return AppColors.warning; default: return AppColors.primary; } }
  IconData _typeIcon(String t) { switch(t) { case 'ENTRADA': return Icons.arrow_downward_rounded; case 'SALIDA': return Icons.arrow_upward_rounded; case 'AJUSTE': return Icons.tune_rounded; default: return Icons.swap_horiz_rounded; } }
  String _formatTime(DateTime d) { final n = DateTime.now(); final diff = n.difference(d); if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m'; if (diff.inHours < 24) return 'hace ${diff.inHours}h'; return 'hace ${diff.inDays}d'; }
}

class _TypeBadge extends StatelessWidget {
  final String tipo; const _TypeBadge({required this.tipo});
  @override Widget build(BuildContext context) {
    Color c; switch(tipo){case 'ENTRADA':c=AppColors.success;break;case 'SALIDA':c=AppColors.error;break;case 'AJUSTE':c=AppColors.warning;break;default:c=AppColors.primary;}
    return Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:c.withOpacity(0.12),borderRadius:BorderRadius.circular(4)),child:Text(tipo,style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:c)));
  }
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)), Text(label, style: AppTextStyles.labelSmall)])));
}
