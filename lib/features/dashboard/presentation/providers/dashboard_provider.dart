import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventario/data/models/inventario.dart';
import '../../../caja/data/caja_repository.dart';

// ─── Modelos ──────────────────────────────────────────────────────────────────

class DashboardSede {
  final String id, nombre, codigo;
  final bool activo;
  const DashboardSede({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.activo,
  });
  factory DashboardSede.fromMap(Map<String, dynamic> m) => DashboardSede(
    id: m['id'] as String? ?? '',
    nombre: m['nombre'] as String? ?? '',
    codigo: m['codigo'] as String? ?? '',
    activo: m['activo'] as bool? ?? true,
  );
}

class DashboardData {
  // Sede seleccionada
  final List<DashboardSede> sedes;
  final String? selectedSedeId;

  // KPIs
  final double ventasHoy;
  final int ventasCountHoy;
  final double ventasAyer;
  final int cajaAperturas;
  final CajaSesion? cajaActual;
  final int stockBajo; // alerta + critico
  final int sedesActivas;
  final int sedesTotal;

  // Gráfica — últimos 7 días (7 puntos fijos para el periodo 7D)
  final List<double> ventasSemana; // 7 valores, 0=hace6días 6=hoy
  final double ventasSemanaAnterior;

  // Gráfica dinámica por periodo (usada cuando el usuario cambia el selector)
  final List<double> chartPoints; // N puntos según periodo
  final List<String> chartLabels; // etiquetas del eje X
  final double chartTotal; // total del periodo
  final double chartPrevTotal; // total periodo anterior (para %)
  final bool chartLoading;

  // Actividad reciente
  final List<Map<String, dynamic>> audit;

  // Estado de carga
  final bool loading;
  final String? error;

  // Stats mes (vendedora/cajero)
  final int misVentasMes;
  final double misTotalesMes;

  // Compras resumen
  final int comprasPendientes;
  final double comprasMontoTotal;

  // Asistencia resumen
  final int asistenciaPresentes;
  final int asistenciaTotal;

  const DashboardData({
    this.sedes = const [],
    this.selectedSedeId,
    this.ventasHoy = 0,
    this.ventasCountHoy = 0,
    this.ventasAyer = 0,
    this.cajaAperturas = 0,
    this.cajaActual,
    this.stockBajo = 0,
    this.sedesActivas = 0,
    this.sedesTotal = 0,
    this.ventasSemana = const [0, 0, 0, 0, 0, 0, 0],
    this.ventasSemanaAnterior = 0,
    this.chartPoints = const [],
    this.chartLabels = const [],
    this.chartTotal = 0,
    this.chartPrevTotal = 0,
    this.chartLoading = false,
    this.audit = const [],
    this.loading = true,
    this.error,
    this.misVentasMes = 0,
    this.misTotalesMes = 0,
    this.comprasPendientes = 0,
    this.comprasMontoTotal = 0,
    this.asistenciaPresentes = 0,
    this.asistenciaTotal = 0,
  });

  DashboardData copyWith({
    List<DashboardSede>? sedes,
    String? selectedSedeId,
    bool clearSede = false,
    double? ventasHoy,
    int? ventasCountHoy,
    double? ventasAyer,
    int? cajaAperturas,
    CajaSesion? cajaActual,
    bool clearCaja = false,
    int? stockBajo,
    int? sedesActivas,
    int? sedesTotal,
    List<double>? ventasSemana,
    double? ventasSemanaAnterior,
    List<double>? chartPoints,
    List<String>? chartLabels,
    double? chartTotal,
    double? chartPrevTotal,
    bool? chartLoading,
    List<Map<String, dynamic>>? audit,
    bool? loading,
    String? error,
    bool clearError = false,
    int? misVentasMes,
    double? misTotalesMes,
    int? comprasPendientes,
    double? comprasMontoTotal,
    int? asistenciaPresentes,
    int? asistenciaTotal,
  }) => DashboardData(
    sedes: sedes ?? this.sedes,
    selectedSedeId: clearSede ? null : (selectedSedeId ?? this.selectedSedeId),
    ventasHoy: ventasHoy ?? this.ventasHoy,
    ventasCountHoy: ventasCountHoy ?? this.ventasCountHoy,
    ventasAyer: ventasAyer ?? this.ventasAyer,
    cajaAperturas: cajaAperturas ?? this.cajaAperturas,
    cajaActual: clearCaja ? null : (cajaActual ?? this.cajaActual),
    stockBajo: stockBajo ?? this.stockBajo,
    sedesActivas: sedesActivas ?? this.sedesActivas,
    sedesTotal: sedesTotal ?? this.sedesTotal,
    ventasSemana: ventasSemana ?? this.ventasSemana,
    ventasSemanaAnterior: ventasSemanaAnterior ?? this.ventasSemanaAnterior,
    chartPoints: chartPoints ?? this.chartPoints,
    chartLabels: chartLabels ?? this.chartLabels,
    chartTotal: chartTotal ?? this.chartTotal,
    chartPrevTotal: chartPrevTotal ?? this.chartPrevTotal,
    chartLoading: chartLoading ?? this.chartLoading,
    audit: audit ?? this.audit,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    misVentasMes: misVentasMes ?? this.misVentasMes,
    misTotalesMes: misTotalesMes ?? this.misTotalesMes,
    comprasPendientes: comprasPendientes ?? this.comprasPendientes,
    comprasMontoTotal: comprasMontoTotal ?? this.comprasMontoTotal,
    asistenciaPresentes: asistenciaPresentes ?? this.asistenciaPresentes,
    asistenciaTotal: asistenciaTotal ?? this.asistenciaTotal,
  );

  // % de variación ventas hoy vs ayer
  double get variacionVsAyer =>
      ventasAyer > 0 ? ((ventasHoy - ventasAyer) / ventasAyer) * 100 : 0;

  // Total semana
  double get totalSemana => ventasSemana.fold(0, (a, b) => a + b);

  // % variación semana
  double get variacionSemana => ventasSemanaAnterior > 0
      ? ((totalSemana - ventasSemanaAnterior) / ventasSemanaAnterior) * 100
      : 0;

  DashboardSede? get selectedSede =>
      sedes.where((s) => s.id == selectedSedeId).firstOrNull;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DashboardNotifier extends StateNotifier<DashboardData> {
  final ApiClient _api;
  final Set<String> _perms;
  final String? _userSedeId;

  DashboardNotifier(this._api, this._perms, this._userSedeId)
    : super(const DashboardData()) {
    load();
  }

  bool _has(String p) => _perms.contains(p);

  Future<void> selectSede(String? sedeId) async {
    state = state.copyWith(
      selectedSedeId: sedeId,
      loading: true,
      clearError: true,
    );
    await _loadData(sedeId ?? _userSedeId);
  }

  Future<void> loadChartForPeriod(String period) async {
    state = state.copyWith(chartLoading: true);
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final sedeId = state.selectedSedeId ?? _userSedeId;

    int days;
    switch (period) {
      case '1M':
        days = 30;
        break;
      case '3M':
        days = 90;
        break;
      case '6M':
        days = 180;
        break;
      case '1A':
        days = 365;
        break;
      default:
        days = 7;
    }

    final inicio = hoy.subtract(Duration(days: days - 1));
    final prevInicio = inicio.subtract(Duration(days: days));

    final (int buckets, String fmt) = switch (period) {
      '1M' => (4, 'semana'),
      '3M' => (3, 'mes'),
      '6M' => (6, 'mes'),
      '1A' => (12, 'mes'),
      _ => (7, 'dia'),
    };

    final points = List<double>.filled(buckets, 0);
    final prevPoints = List<double>.filled(buckets, 0);

    if (_has('ventas:leer-propias') || _has('ventas:leer')) {
      try {
        final endpoint = _has('ventas:leer-propias')
            ? ApiConstants.misVentas
            : ApiConstants.ventas;
        final q = <String, dynamic>{'limite': 500, 'pagina': 1};
        if (sedeId != null && _has('ventas:leer')) q['sedeId'] = sedeId;
        final r = await _api.get(endpoint, queryParameters: q);
        final ventas = List.from((r.data as Map)['data'] ?? []);
        for (final v in ventas) {
          if (v is! Map) continue;
          final total = (v['total'] as num?)?.toDouble() ?? 0;
          if ((v['estado'] as String? ?? '') == 'ANULADA') continue;
          DateTime? dt;
          try {
            dt = DateTime.parse(v['createdAt'] as String? ?? '');
          } catch (_) {}
          if (dt == null) continue;
          final d = DateTime(dt.year, dt.month, dt.day);
          if (!d.isBefore(inicio) && !d.isAfter(hoy)) {
            final idx = _bucketIdx(d, inicio, buckets, fmt);
            if (idx >= 0 && idx < buckets) points[idx] += total;
          }
          if (!d.isBefore(prevInicio) && d.isBefore(inicio)) {
            final idx = _bucketIdx(d, prevInicio, buckets, fmt);
            if (idx >= 0 && idx < buckets) prevPoints[idx] += total;
          }
        }
      } catch (_) {}
    }

    state = state.copyWith(
      chartPoints: points,
      chartLabels: _labels(inicio, buckets, fmt),
      chartTotal: points.fold<double>(0, (a, b) => a + b),
      chartPrevTotal: prevPoints.fold<double>(0, (a, b) => a + b),
      chartLoading: false,
    );
  }

  int _bucketIdx(DateTime d, DateTime start, int buckets, String fmt) {
    if (fmt == 'dia') return d.difference(start).inDays.clamp(0, buckets - 1);
    if (fmt == 'semana')
      return (d.difference(start).inDays ~/ 7).clamp(0, buckets - 1);
    return ((d.year - start.year) * 12 + (d.month - start.month)).clamp(
      0,
      buckets - 1,
    );
  }

  List<String> _labels(DateTime start, int buckets, String fmt) {
    const dn = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const mn = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    if (fmt == 'dia')
      return List.generate(
        buckets,
        (i) => dn[start.add(Duration(days: i)).weekday - 1],
      );
    if (fmt == 'semana') return List.generate(buckets, (i) => 'S${i + 1}');
    return List.generate(buckets, (i) => mn[(start.month - 1 + i) % 12]);
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);

    // Cargar sedes si tiene permiso
    if (_has('establecimientos:leer')) {
      try {
        final r = await _api.get(
          ApiConstants.establishments,
          queryParameters: {'pagina': 1, 'limite': 100},
        );
        final list = (r.data as Map)['data'] as List? ?? [];
        final sedes = list
            .whereType<Map>()
            .map((m) => DashboardSede.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        state = state.copyWith(sedes: sedes);
      } catch (_) {}
    }

    await _loadData(state.selectedSedeId ?? _userSedeId);
  }

  Future<void> _loadData(String? sedeId) async {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    final ayer = hoy.subtract(const Duration(days: 1));
    final hace7 = hoy.subtract(const Duration(days: 6));
    final hace14 = hoy.subtract(const Duration(days: 13));

    // ── Ventas ────────────────────────────────────────────────────────────────
    double ventasHoy = 0, ventasAyer = 0;
    int countHoy = 0;
    final semana = List<double>.filled(7, 0);
    double semanaAnterior = 0;
    int misVentasMes = 0;
    double misTotalesMes = 0;

    final canLeerPropias = _has('ventas:leer-propias');
    final canLeerTodas = _has('ventas:leer');
    final mes = DateTime(now.year, now.month, 1);

    if (canLeerPropias || canLeerTodas) {
      try {
        final endpoint = canLeerPropias
            ? ApiConstants.misVentas
            : ApiConstants.ventas;
        final q = <String, dynamic>{'limite': 200, 'pagina': 1};
        if (sedeId != null && canLeerTodas) q['sedeId'] = sedeId;
        final r = await _api.get(endpoint, queryParameters: q);
        final ventas = List.from((r.data as Map)['data'] ?? []);
        for (final v in ventas) {
          if (v is! Map) continue;
          final total = (v['total'] as num?)?.toDouble() ?? 0;
          if ((v['estado'] as String? ?? '') == 'ANULADA') continue;
          DateTime? dt;
          try {
            dt = DateTime.parse(v['createdAt'] as String? ?? '');
          } catch (_) {}
          if (dt == null) continue;
          final d = DateTime(dt.year, dt.month, dt.day);
          if (!d.isBefore(hoy)) {
            ventasHoy += total;
            countHoy++;
          }
          if (d == ayer) {
            ventasAyer += total;
          }
          if (!d.isBefore(mes)) {
            misVentasMes++;
            misTotalesMes += total;
          }
          // Semana actual
          if (!d.isBefore(hace7)) {
            final idx = d.difference(hace7).inDays;
            if (idx >= 0 && idx < 7) semana[idx] += total;
          }
          // Semana anterior
          if (!d.isBefore(hace14) && d.isBefore(hace7)) {
            semanaAnterior += total;
          }
        }
      } catch (_) {}
    }

    // ── Caja ──────────────────────────────────────────────────────────────────
    CajaSesion? cajaActual;
    int cajaAperturas = 0;
    if (_has('caja:leer')) {
      try {
        final q = <String, dynamic>{};
        if (sedeId != null) q['sedeId'] = sedeId;
        final r = await _api.get(ApiConstants.cajaActual, queryParameters: q);
        if (r.data != null && r.data is Map) {
          cajaActual = CajaSesion.fromJson(
            Map<String, dynamic>.from(r.data as Map),
          );
        }
      } catch (_) {}
      // Contar aperturas de hoy
      try {
        final q = <String, dynamic>{'limite': 1, 'pagina': 1};
        if (sedeId != null) q['sedeId'] = sedeId;
        final r = await _api.get(
          ApiConstants.cajaHistorial,
          queryParameters: q,
        );
        cajaAperturas = (r.data as Map?)?['total'] as int? ?? 0;
      } catch (_) {}
    }

    // ── Inventario ────────────────────────────────────────────────────────────
    int stockBajo = 0;
    if (_has('inventario:leer')) {
      try {
        final q = <String, dynamic>{};
        if (sedeId != null) q['sedeId'] = sedeId;
        final r = await _api.get(
          ApiConstants.inventoryResumen,
          queryParameters: q,
        );
        final inv = InventarioResumen.fromJson(
          Map<String, dynamic>.from(r.data as Map),
        );
        stockBajo = inv.alerta + inv.critico;
      } catch (_) {}
    }

    // ── Sedes activas ─────────────────────────────────────────────────────────
    int sedesActivas = 0, sedesTotal = 0;
    if (_has('establecimientos:leer') && state.sedes.isNotEmpty) {
      sedesTotal = state.sedes.length;
      sedesActivas = state.sedes.where((s) => s.activo).length;
    }

    // ── Audit ─────────────────────────────────────────────────────────────────
    List<Map<String, dynamic>> audit = [];
    if (_has('audit:leer')) {
      try {
        final r = await _api.get(
          ApiConstants.audit,
          queryParameters: {'pagina': 1, 'limite': 6},
        );
        audit = List.from(
          (r.data as Map)['data'] ?? [],
        ).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      } catch (_) {}
    }

    // ── Compras resumen ───────────────────────────────────────────────────────
    int comprasPendientes = 0;
    double comprasMontoTotal = 0;
    if (_has('compras:leer')) {
      try {
        final q = <String, dynamic>{};
        if (sedeId != null) q['sedeId'] = sedeId;
        final r = await _api.get(
          ApiConstants.purchasesResumen,
          queryParameters: q,
        );
        final data = Map<String, dynamic>.from(r.data as Map);
        comprasPendientes = (data['pendientes'] as num?)?.toInt() ?? 0;
        comprasMontoTotal = (data['montoPendiente'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
    }

    // ── Asistencia resumen ────────────────────────────────────────────────────
    int asistenciaPresentes = 0, asistenciaTotal = 0;
    if (_has('asistencia:leer')) {
      try {
        final r = await _api.get(ApiConstants.attendanceResumen);
        final data = Map<String, dynamic>.from(r.data as Map);
        asistenciaPresentes = (data['presente'] as num?)?.toInt() ?? 0;
        asistenciaTotal = (data['totalEmpleados'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    state = state.copyWith(
      ventasHoy: ventasHoy,
      ventasCountHoy: countHoy,
      ventasAyer: ventasAyer,
      cajaActual: cajaActual,
      clearCaja: cajaActual == null,
      cajaAperturas: cajaAperturas,
      stockBajo: stockBajo,
      sedesActivas: sedesActivas,
      sedesTotal: sedesTotal,
      ventasSemana: semana,
      ventasSemanaAnterior: semanaAnterior,
      audit: audit,
      misVentasMes: misVentasMes,
      misTotalesMes: misTotalesMes,
      comprasPendientes: comprasPendientes,
      comprasMontoTotal: comprasMontoTotal,
      asistenciaPresentes: asistenciaPresentes,
      asistenciaTotal: asistenciaTotal,
      loading: false,
      clearError: true,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardData>((ref) {
      final auth = ref.watch(authProvider);
      final perms = auth.permisos.toSet();
      final sedeId = auth.user?.sedeId;
      return DashboardNotifier(ApiClient.instance, perms, sedeId);
    });
