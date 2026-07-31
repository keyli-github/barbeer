import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});
  @override State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  bool _showHistorial = false;

  static final _empleados = [
    {'nombre':'Juan Quispe','rol':'CAJERO','turno':'Manana 8-4pm','entrada':'08:05','horas':'3h 55m','estado':'Presente'},
    {'nombre':'Maria Torres','rol':'MOZO','turno':'Manana 8-4pm','entrada':'07:58','horas':'4h 02m','estado':'Presente'},
    {'nombre':'Carlos Vega','rol':'BARTENDER','turno':'Tarde 4-12pm','entrada':null,'horas':'0h','estado':'Pendiente'},
    {'nombre':'Ana Flores','rol':'COCINA','turno':'Manana 8-4pm','entrada':'08:22','horas':'3h 38m','estado':'Tardanza'},
    {'nombre':'Pedro Lima','rol':'MOZO','turno':'Tarde 4-12pm','entrada':null,'horas':'0h','estado':'Ausente'},
  ];

  static final _registros = [
    {'empleado':'Juan Quispe','rol':'CAJERO','tipo':'ENTRADA','hora':'08:05','detalle':'Entrada registrada - Puntual'},
    {'empleado':'Maria Torres','rol':'MOZO','tipo':'ENTRADA','hora':'07:58','detalle':'Entrada anticipada'},
    {'empleado':'Ana Flores','rol':'COCINA','tipo':'TARDANZA','hora':'08:22','detalle':'Tardanza de 22 minutos'},
    {'empleado':'Juan Quispe','rol':'CAJERO','tipo':'ENTRADA','hora':'ayer 08:02','detalle':'Entrada registrada'},
    {'empleado':'Maria Torres','rol':'MOZO','tipo':'SALIDA','hora':'ayer 16:03','detalle':'Salida normal'},
    {'empleado':'Carlos Vega','rol':'BARTENDER','tipo':'ENTRADA','hora':'ayer 16:05','detalle':'Turno tarde'},
  ];

  @override
  Widget build(BuildContext context) {
    final presentes = _empleados.where((e) => e['estado'] == 'Presente').length;
    final ausentes = _empleados.where((e) => e['estado'] == 'Ausente').length;
    final tardanza = _empleados.where((e) => e['estado'] == 'Tardanza').length;

    return Scaffold(backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(bottom: false, child: Column(children: [
        Container(color: AppColors.background, child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            const Expanded(child: Text('Asistencia', style: AppTextStyles.headlineLarge)),
            Text(_today(), style: AppTextStyles.bodySmall),
          ])),
          // View toggle
          Container(margin: const EdgeInsets.fromLTRB(16, 0, 16, 12), padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(children: [
              Expanded(child: GestureDetector(onTap: () => setState(() => _showHistorial = false),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: !_showHistorial ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(8),
                      boxShadow: !_showHistorial ? [const BoxShadow(color: Color(0x1A000000), blurRadius: 4)] : null),
                  child: Text('Hoy', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: !_showHistorial ? AppColors.primary : AppColors.textSecondary))))),
              Expanded(child: GestureDetector(onTap: () => setState(() => _showHistorial = true),
                child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: _showHistorial ? AppColors.surface : Colors.transparent, borderRadius: BorderRadius.circular(8),
                      boxShadow: _showHistorial ? [const BoxShadow(color: Color(0x1A000000), blurRadius: 4)] : null),
                  child: Text('Historial', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _showHistorial ? AppColors.primary : AppColors.textSecondary))))),
            ])),
        ])),

        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
          _StatChip(label: 'Total', value: '${_empleados.length}', color: AppColors.textSecondary),
          const SizedBox(width: 8),
          _StatChip(label: 'Presentes', value: '$presentes', color: AppColors.success),
          const SizedBox(width: 8),
          _StatChip(label: 'Ausentes', value: '$ausentes', color: AppColors.error),
          const SizedBox(width: 8),
          _StatChip(label: 'Tardanza', value: '$tardanza', color: AppColors.warning),
        ])),
        const SizedBox(height: 8),

        Expanded(child: !_showHistorial
          // Resumen del dia
          ? ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), children: [
              for (final e in _empleados)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: AppCard(child: Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: _roleColor(e['rol'] as String).withOpacity(0.15),
                    child: Text(_initials(e['nombre'] as String), style: TextStyle(fontWeight: FontWeight.w700, color: _roleColor(e['rol'] as String), fontSize: 14))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['nombre'] as String, style: AppTextStyles.titleMedium),
                    Text('${e['rol']} · ${e['turno']}', style: AppTextStyles.bodySmall),
                    if (e['entrada'] != null) Text('Entrada: ${e['entrada']}', style: AppTextStyles.labelSmall),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _StatusBadge(status: e['estado'] as String),
                    const SizedBox(height: 4),
                    Text(e['horas'] as String, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ]))),
            ])

          // Historial
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), children: [
              for (final r in _registros)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.borderLight, width: 0.5)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _tipoColor(r['tipo'] as String).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Icon(_tipoIcon(r['tipo'] as String), color: _tipoColor(r['tipo'] as String), size: 18)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['empleado'] as String, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      Text(r['detalle'] as String, style: AppTextStyles.labelSmall),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      _TipoBadge(tipo: r['tipo'] as String),
                      const SizedBox(height: 3),
                      Text(r['hora'] as String, style: AppTextStyles.labelSmall),
                    ]),
                  ]))),
            ])),
      ])));
  }

  String _today() { final d = DateTime.now(); return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'; }
  String _initials(String n) { final p = n.split(' '); if (p.length >= 2) return '${p[0][0]}${p[1][0]}'; return n[0]; }
  Color _roleColor(String r) { switch(r){ case 'CAJERO': return AppColors.roleCajero; case 'MOZO': return AppColors.roleMozo; case 'COCINA': return AppColors.roleCocina; case 'BARTENDER': return AppColors.roleBartender; default: return AppColors.primary; } }
  Color _tipoColor(String t) { switch(t){ case 'ENTRADA': return AppColors.success; case 'SALIDA': return AppColors.primary; default: return AppColors.warning; } }
  IconData _tipoIcon(String t) { switch(t){ case 'ENTRADA': return Icons.login_rounded; case 'SALIDA': return Icons.logout_rounded; default: return Icons.warning_amber_rounded; } }
}

class _StatusBadge extends StatelessWidget {
  final String status; const _StatusBadge({required this.status});
  @override Widget build(BuildContext context) {
    Color c; switch(status){ case 'Presente':c=AppColors.success;break; case 'Ausente':c=AppColors.error;break; case 'Tardanza':c=AppColors.warning;break; default:c=AppColors.textTertiary; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)));
  }
}

class _TipoBadge extends StatelessWidget {
  final String tipo; const _TipoBadge({required this.tipo});
  @override Widget build(BuildContext context) {
    Color c; switch(tipo){ case 'ENTRADA':c=AppColors.success;break; case 'SALIDA':c=AppColors.primary;break; default:c=AppColors.warning; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(tipo, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)));
  }
}

class _StatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: Column(children: [Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)), Text(label, style: AppTextStyles.labelSmall)])));
}
