import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../caja/data/caja_repository.dart';
import '../../../compras/data/compras_repository.dart';
import '../../../inventario/data/models/inventario.dart';
import '../../../kardex/data/kardex_repository.dart';
import '../../../productos/data/productos_repository.dart';

/// Matches the web dashboard's audit fetch limit.
const dashboardAuditLimit = 8;

class DashboardSede {
  final String id, nombre, codigoSede;
  final String? direccion;
  final int usuarios;
  final bool activo;

  const DashboardSede({
    required this.id,
    required this.nombre,
    required this.codigoSede,
    this.direccion,
    this.usuarios = 0,
    required this.activo,
  });

  factory DashboardSede.fromMap(Map<String, dynamic> map) => DashboardSede(
    id: map['id'] as String? ?? '',
    nombre: map['nombre'] as String? ?? '',
    codigoSede: map['codigoSede'] as String? ?? map['codigo'] as String? ?? '',
    direccion: map['direccion'] as String?,
    usuarios: ((map['_count'] as Map?)?['usuarios'] as num?)?.toInt() ?? 0,
    activo: map['activo'] as bool? ?? true,
  );
}

class DashboardKardexPoint {
  final String label;
  final int entradas;
  final int salidas;

  const DashboardKardexPoint({
    required this.label,
    required this.entradas,
    required this.salidas,
  });
}

class DashboardData {
  final List<DashboardSede> sedes;
  final String? selectedSedeId;
  final int? categoriasTotal;
  final ProductosResumen? productos;
  final InventarioResumen? inventario;
  final KardexResumen? kardex;
  final int? rolesTotal;
  final int? usuariosTotal;
  final int? sesionesTotal;
  final double ventasHoy;
  final int ventasCountHoy;
  final double ventasAyer;
  final CajaSesion? cajaActual;
  final CajaSesion? cajaConDiferencia;
  final int stockBajo;
  final int sedesActivas;
  final int sedesTotal;
  final List<double> ventasSemana;
  final List<DashboardKardexPoint> kardexSemana;
  final double ventasSemanaAnterior;
  final List<double> chartPoints;
  final List<String> chartLabels;
  final double chartTotal;
  final double chartPrevTotal;
  final bool chartLoading;
  final List<Map<String, dynamic>> audit;
  final bool loading;
  final Map<String, String> errors;
  final int misVentasMes;
  final double misTotalesMes;
  final int comprasPendientes;
  final double comprasMontoTotal;
  final ComprasResumen? compras;
  final int asistenciaPresentes;
  final int asistenciaTotal;
  final int asistenciaTardanzas;
  final int asistenciaAusentes;
  final int asistenciaDiaLibre;
  final Map<String, int> usuariosPorRol;

  const DashboardData({
    this.sedes = const [],
    this.selectedSedeId,
    this.categoriasTotal,
    this.productos,
    this.inventario,
    this.kardex,
    this.rolesTotal,
    this.usuariosTotal,
    this.sesionesTotal,
    this.ventasHoy = 0,
    this.ventasCountHoy = 0,
    this.ventasAyer = 0,
    this.cajaActual,
    this.cajaConDiferencia,
    this.stockBajo = 0,
    this.sedesActivas = 0,
    this.sedesTotal = 0,
    this.ventasSemana = const [0, 0, 0, 0, 0, 0, 0],
    this.kardexSemana = const [],
    this.ventasSemanaAnterior = 0,
    this.chartPoints = const [],
    this.chartLabels = const [],
    this.chartTotal = 0,
    this.chartPrevTotal = 0,
    this.chartLoading = false,
    this.audit = const [],
    this.loading = true,
    this.errors = const {},
    this.misVentasMes = 0,
    this.misTotalesMes = 0,
    this.comprasPendientes = 0,
    this.comprasMontoTotal = 0,
    this.compras,
    this.asistenciaPresentes = 0,
    this.asistenciaTotal = 0,
    this.asistenciaTardanzas = 0,
    this.asistenciaAusentes = 0,
    this.asistenciaDiaLibre = 0,
    this.usuariosPorRol = const {},
  });

  DashboardData copyWith({
    List<DashboardSede>? sedes,
    String? selectedSedeId,
    bool clearSede = false,
    int? categoriasTotal,
    ProductosResumen? productos,
    InventarioResumen? inventario,
    KardexResumen? kardex,
    int? rolesTotal,
    int? usuariosTotal,
    int? sesionesTotal,
    double? ventasHoy,
    int? ventasCountHoy,
    double? ventasAyer,
    CajaSesion? cajaActual,
    bool clearCaja = false,
    CajaSesion? cajaConDiferencia,
    bool clearCajaConDiferencia = false,
    int? stockBajo,
    int? sedesActivas,
    int? sedesTotal,
    List<double>? ventasSemana,
    List<DashboardKardexPoint>? kardexSemana,
    double? ventasSemanaAnterior,
    List<double>? chartPoints,
    List<String>? chartLabels,
    double? chartTotal,
    double? chartPrevTotal,
    bool? chartLoading,
    List<Map<String, dynamic>>? audit,
    bool? loading,
    Map<String, String>? errors,
    int? misVentasMes,
    double? misTotalesMes,
    int? comprasPendientes,
    double? comprasMontoTotal,
    ComprasResumen? compras,
    int? asistenciaPresentes,
    int? asistenciaTotal,
    int? asistenciaTardanzas,
    int? asistenciaAusentes,
    int? asistenciaDiaLibre,
    Map<String, int>? usuariosPorRol,
  }) => DashboardData(
    sedes: sedes ?? this.sedes,
    selectedSedeId: clearSede ? null : selectedSedeId ?? this.selectedSedeId,
    categoriasTotal: categoriasTotal ?? this.categoriasTotal,
    productos: productos ?? this.productos,
    inventario: inventario ?? this.inventario,
    kardex: kardex ?? this.kardex,
    rolesTotal: rolesTotal ?? this.rolesTotal,
    usuariosTotal: usuariosTotal ?? this.usuariosTotal,
    sesionesTotal: sesionesTotal ?? this.sesionesTotal,
    ventasHoy: ventasHoy ?? this.ventasHoy,
    ventasCountHoy: ventasCountHoy ?? this.ventasCountHoy,
    ventasAyer: ventasAyer ?? this.ventasAyer,
    cajaActual: clearCaja ? null : cajaActual ?? this.cajaActual,
    cajaConDiferencia: clearCajaConDiferencia
        ? null
        : cajaConDiferencia ?? this.cajaConDiferencia,
    stockBajo: stockBajo ?? this.stockBajo,
    sedesActivas: sedesActivas ?? this.sedesActivas,
    sedesTotal: sedesTotal ?? this.sedesTotal,
    ventasSemana: ventasSemana ?? this.ventasSemana,
    kardexSemana: kardexSemana ?? this.kardexSemana,
    ventasSemanaAnterior: ventasSemanaAnterior ?? this.ventasSemanaAnterior,
    chartPoints: chartPoints ?? this.chartPoints,
    chartLabels: chartLabels ?? this.chartLabels,
    chartTotal: chartTotal ?? this.chartTotal,
    chartPrevTotal: chartPrevTotal ?? this.chartPrevTotal,
    chartLoading: chartLoading ?? this.chartLoading,
    audit: audit ?? this.audit,
    loading: loading ?? this.loading,
    errors: errors ?? this.errors,
    misVentasMes: misVentasMes ?? this.misVentasMes,
    misTotalesMes: misTotalesMes ?? this.misTotalesMes,
    comprasPendientes: comprasPendientes ?? this.comprasPendientes,
    comprasMontoTotal: comprasMontoTotal ?? this.comprasMontoTotal,
    compras: compras ?? this.compras,
    asistenciaPresentes: asistenciaPresentes ?? this.asistenciaPresentes,
    asistenciaTotal: asistenciaTotal ?? this.asistenciaTotal,
    asistenciaTardanzas: asistenciaTardanzas ?? this.asistenciaTardanzas,
    asistenciaAusentes: asistenciaAusentes ?? this.asistenciaAusentes,
    asistenciaDiaLibre: asistenciaDiaLibre ?? this.asistenciaDiaLibre,
    usuariosPorRol: usuariosPorRol ?? this.usuariosPorRol,
  );

  double get variacionVsAyer =>
      ventasAyer > 0 ? ((ventasHoy - ventasAyer) / ventasAyer) * 100 : 0;
  double get totalSemana => ventasSemana.fold(0, (a, b) => a + b);
  bool hasError(String key) => errors.containsKey(key);
  DashboardSede? get selectedSede =>
      sedes.where((sede) => sede.id == selectedSedeId).firstOrNull;
}

class DashboardNotifier extends StateNotifier<DashboardData> {
  final ApiClient _api;
  final Set<String> _perms;
  final String? _sedeId;
  int _request = 0;
  bool _loaded = false;

  DashboardNotifier(this._api, this._perms, this._sedeId)
    : super(DashboardData(selectedSedeId: _sedeId)) {
    load();
  }

  bool _has(String permission) => _perms.contains(permission);

  String _message(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> load() async {
    final request = ++_request;
    state = state.copyWith(loading: !_loaded, errors: const {});
    final errors = <String, String>{};
    final tasks = <Future<void>>[];

    List<DashboardSede> sedes = const [];
    int? categoriasTotal;
    ProductosResumen? productos;
    InventarioResumen? inventario;
    KardexResumen? kardex;
    int? rolesTotal;
    int? usuariosTotal;
    int? sesionesTotal;
    CajaSesion? cajaActual;
    CajaSesion? cajaConDiferencia;
    var ventasHoy = 0.0;
    var ventasAyer = 0.0;
    var ventasCountHoy = 0;
    var misVentasMes = 0;
    var misTotalesMes = 0.0;
    var comprasPendientes = 0;
    var comprasMontoTotal = 0.0;
    ComprasResumen? compras;
    var asistenciaPresentes = 0;
    var asistenciaTotal = 0;
    var asistenciaTardanzas = 0;
    var asistenciaAusentes = 0;
    var asistenciaDiaLibre = 0;
    var usuariosPorRol = <String, int>{};
    var audit = <Map<String, dynamic>>[];
    final semana = List<double>.filled(7, 0);
    var kardexSemana = <DashboardKardexPoint>[];
    var semanaAnterior = 0.0;

    void add(String key, Future<void> Function() loader) {
      tasks.add(() async {
        try {
          await loader();
        } catch (error) {
          errors[key] = _message(error);
        }
      }());
    }

    if (_has('establecimientos:leer')) {
      add('sedes', () async {
        final response = await _api.get(
          ApiConstants.establishments,
          queryParameters: const {'pagina': 1, 'limite': 100},
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        sedes = (data['data'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => DashboardSede.fromMap(Map<String, dynamic>.from(item)),
            )
            .toList();
      });
    }

    if (_has('categorias:leer')) {
      add('categorias', () async {
        final response = await _api.get(
          ApiConstants.categories,
          queryParameters: const {'pagina': 1, 'limite': 1},
        );
        categoriasTotal = (response.data as Map)['total'] as int? ?? 0;
      });
    }

    if (_has('productos:leer')) {
      add('productos', () async {
        final response = await _api.get(ApiConstants.productsResumen);
        productos = ProductosResumen.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      });
    }

    if (_has('inventario:leer')) {
      add('inventario', () async {
        final response = await _api.get(
          ApiConstants.inventoryResumen,
          queryParameters: {if (_sedeId != null) 'sedeId': _sedeId},
        );
        inventario = InventarioResumen.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      });
    }

    if (_has('kardex:leer')) {
      add('kardex', () async {
        final response = await _api.get(
          ApiConstants.kardexResumen,
          queryParameters: {if (_sedeId != null) 'sedeId': _sedeId},
        );
        kardex = KardexResumen.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );

        final today = DateTime.now();
        final start = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(const Duration(days: 6));
        final daily = List.generate(
          7,
          (index) => {'entradas': 0, 'salidas': 0},
        );
        final listResponse = await _api.get(
          ApiConstants.kardex,
          queryParameters: {
            'pagina': 1,
            'limite': 100,
            'desde': _dateKey(start),
            'hasta': _dateKey(today),
            if (_sedeId != null) 'sedeId': _sedeId,
          },
        );
        final payload = Map<String, dynamic>.from(listResponse.data as Map);
        for (final row
            in (payload['data'] as List? ?? const []).whereType<Map>()) {
          final date = DateTime.tryParse(row['fecha']?.toString() ?? '');
          if (date == null) continue;
          final index = DateTime(
            date.year,
            date.month,
            date.day,
          ).difference(DateTime(start.year, start.month, start.day)).inDays;
          if (index < 0 || index >= daily.length) continue;
          if (row['tipo'] == 'ENTRADA')
            daily[index]['entradas'] = daily[index]['entradas']! + 1;
          if (row['tipo'] == 'SALIDA')
            daily[index]['salidas'] = daily[index]['salidas']! + 1;
        }
        const labels = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
        kardexSemana = List.generate(7, (index) {
          final date = start.add(Duration(days: index));
          return DashboardKardexPoint(
            label: labels[date.weekday % 7],
            entradas: daily[index]['entradas']!,
            salidas: daily[index]['salidas']!,
          );
        });
      });
    }

    if (_has('compras:leer')) {
      add('compras', () async {
        final response = await _api.get(
          ApiConstants.purchasesResumen,
          queryParameters: {if (_sedeId != null) 'sedeId': _sedeId},
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        compras = ComprasResumen.fromJson(data);
        comprasPendientes = compras!.pendientes;
        comprasMontoTotal = compras!.montoPendiente;
      });
    }

    if (_has('asistencia:leer')) {
      add('asistencia', () async {
        final response = await _api.get(
          ApiConstants.attendanceResumen,
          queryParameters: {if (_sedeId != null) 'sedeId': _sedeId},
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        asistenciaPresentes = (data['presente'] as num?)?.toInt() ?? 0;
        asistenciaTotal = (data['totalEmpleados'] as num?)?.toInt() ?? 0;
        asistenciaTardanzas = (data['tardanza'] as num?)?.toInt() ?? 0;
        asistenciaAusentes = (data['ausente'] as num?)?.toInt() ?? 0;
        asistenciaDiaLibre = (data['diaLibre'] as num?)?.toInt() ?? 0;
      });
    }

    if (_has('roles:leer')) {
      add('roles', () async {
        final response = await _api.get(
          ApiConstants.roles,
          queryParameters: const {'pagina': 1, 'limite': 100},
        );
        final data = Map<String, dynamic>.from(response.data as Map);
        final roles = (data['data'] as List? ?? const []).whereType<Map>();
        rolesTotal = (data['total'] as num?)?.toInt() ?? roles.length;
        usuariosTotal = roles.fold<int>(
          0,
          (total, role) =>
              total + ((role['_count'] as Map?)?['usuarios'] as int? ?? 0),
        );
        usuariosPorRol = {
          for (final role in roles)
            role['nombre']?.toString() ?? 'Rol':
                ((role['_count'] as Map?)?['usuarios'] as num?)?.toInt() ?? 0,
        };
      });
    }

    add('sesiones', () async {
      final response = await _api.get(ApiConstants.sessions);
      sesionesTotal = (response.data as List?)?.length ?? 0;
    });

    if (_has('audit:leer')) {
      add('audit', () async {
        final response = await _api.get(
          ApiConstants.audit,
          queryParameters: const {'pagina': 1, 'limite': dashboardAuditLimit},
        );
        audit = ((response.data as Map)['data'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    }

    if (_has('caja:leer') && _sedeId != null) {
      add('caja', () async {
        final response = await _api.get(
          ApiConstants.cajaActual,
          queryParameters: {'sedeId': _sedeId},
        );
        if (response.data is Map) {
          cajaActual = CajaSesion.fromJson(
            Map<String, dynamic>.from(response.data as Map),
          );
        }
      });
    }

    if (_has('caja:leer')) {
      add('caja-alerta', () async {
        final response = await _api.get(
          ApiConstants.cajaHistorial,
          queryParameters: {
            'pagina': 1,
            'limite': 5,
            'estado': 'CERRADA',
            if (_sedeId != null) 'sedeId': _sedeId,
          },
        );
        final payload = Map<String, dynamic>.from(response.data as Map);
        for (final row
            in (payload['data'] as List? ?? const []).whereType<Map>()) {
          final session = CajaSesion.fromJson(Map<String, dynamic>.from(row));
          if ((session.diferenciaCierre ?? 0) != 0) {
            cajaConDiferencia = session;
            break;
          }
        }
      });
    }

    final canReadOwnSales = _has('ventas:leer-propias');
    final canReadAllSales = _has('ventas:leer');
    if (canReadOwnSales || canReadAllSales) {
      add('ventas', () async {
        final ventas = await _loadSales(
          canReadAllSales ? ApiConstants.ventas : ApiConstants.misVentas,
          sedeId: canReadAllSales ? _sedeId : null,
        );
        final now = DateTime.now();
        final hoy = DateTime(now.year, now.month, now.day);
        final ayer = hoy.subtract(const Duration(days: 1));
        final hace7 = hoy.subtract(const Duration(days: 6));
        final hace14 = hoy.subtract(const Duration(days: 13));
        final mes = DateTime(now.year, now.month);
        for (final venta in ventas) {
          if ((venta['estado'] as String? ?? '') == 'ANULADA') continue;
          final date = DateTime.tryParse(venta['createdAt'] as String? ?? '');
          if (date == null) continue;
          final day = DateTime(date.year, date.month, date.day);
          final total = (venta['total'] as num?)?.toDouble() ?? 0;
          if (!day.isBefore(hoy)) {
            ventasHoy += total;
            ventasCountHoy++;
          }
          if (day == ayer) ventasAyer += total;
          if (!day.isBefore(mes)) {
            misVentasMes++;
            misTotalesMes += total;
          }
          if (!day.isBefore(hace7) && !day.isAfter(hoy)) {
            semana[day.difference(hace7).inDays] += total;
          }
          if (!day.isBefore(hace14) && day.isBefore(hace7)) {
            semanaAnterior += total;
          }
        }
      });
    }

    await Future.wait(tasks);
    if (request != _request) return;
    final stockBajo = inventario == null
        ? 0
        : inventario!.alerta + inventario!.critico;
    state = DashboardData(
      sedes: sedes,
      selectedSedeId: _sedeId,
      categoriasTotal: categoriasTotal,
      productos: productos,
      inventario: inventario,
      kardex: kardex,
      rolesTotal: rolesTotal,
      usuariosTotal: usuariosTotal,
      sesionesTotal: sesionesTotal,
      ventasHoy: ventasHoy,
      ventasCountHoy: ventasCountHoy,
      ventasAyer: ventasAyer,
      cajaActual: cajaActual,
      cajaConDiferencia: cajaConDiferencia,
      stockBajo: stockBajo,
      sedesActivas: sedes.where((sede) => sede.activo).length,
      sedesTotal: sedes.length,
      ventasSemana: semana,
      kardexSemana: kardexSemana,
      ventasSemanaAnterior: semanaAnterior,
      audit: audit,
      loading: false,
      errors: errors,
      misVentasMes: misVentasMes,
      misTotalesMes: misTotalesMes,
      comprasPendientes: comprasPendientes,
      comprasMontoTotal: comprasMontoTotal,
      compras: compras,
      asistenciaPresentes: asistenciaPresentes,
      asistenciaTotal: asistenciaTotal,
      asistenciaTardanzas: asistenciaTardanzas,
      asistenciaAusentes: asistenciaAusentes,
      asistenciaDiaLibre: asistenciaDiaLibre,
      usuariosPorRol: usuariosPorRol,
    );
    _loaded = true;
  }

  Future<List<Map<String, dynamic>>> _loadSales(
    String endpoint, {
    String? sedeId,
  }) async {
    final rows = <Map<String, dynamic>>[];
    var page = 1;
    var totalPages = 1;
    do {
      final response = await _api.get(
        endpoint,
        queryParameters: {
          'pagina': page,
          'limite': 100,
          if (sedeId != null) 'sedeId': sedeId,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      rows.addAll(
        (data['data'] as List? ?? const []).whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
      totalPages = (data['totalPaginas'] as num?)?.toInt() ?? 1;
      page++;
    } while (page <= totalPages);
    return rows;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> loadChartForPeriod(String period) async {
    state = state.copyWith(chartLoading: true);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = switch (period) {
      '1M' => 30,
      '3M' => 90,
      '6M' => 180,
      '1A' => 365,
      _ => 7,
    };
    final start = today.subtract(Duration(days: days - 1));
    final previousStart = start.subtract(Duration(days: days));
    final (buckets, format) = switch (period) {
      '1M' => (4, 'semana'),
      '3M' => (3, 'mes'),
      '6M' => (6, 'mes'),
      '1A' => (12, 'mes'),
      _ => (7, 'dia'),
    };
    final points = List<double>.filled(buckets, 0);
    final previous = List<double>.filled(buckets, 0);
    final errors = Map<String, String>.from(state.errors)..remove('grafica');
    try {
      final canReadAll = _has('ventas:leer');
      final ventas = await _loadSales(
        canReadAll ? ApiConstants.ventas : ApiConstants.misVentas,
        sedeId: canReadAll ? _sedeId : null,
      );
      for (final venta in ventas) {
        if ((venta['estado'] as String? ?? '') == 'ANULADA') continue;
        final date = DateTime.tryParse(venta['createdAt'] as String? ?? '');
        if (date == null) continue;
        final day = DateTime(date.year, date.month, date.day);
        final total = (venta['total'] as num?)?.toDouble() ?? 0;
        if (!day.isBefore(start) && !day.isAfter(today)) {
          points[_bucketIndex(day, start, buckets, format)] += total;
        }
        if (!day.isBefore(previousStart) && day.isBefore(start)) {
          previous[_bucketIndex(day, previousStart, buckets, format)] += total;
        }
      }
    } catch (error) {
      errors['grafica'] = _message(error);
    }
    state = state.copyWith(
      chartPoints: points,
      chartLabels: _labels(start, buckets, format),
      chartTotal: points.fold<double>(0, (total, value) => total + value),
      chartPrevTotal: previous.fold<double>(0, (total, value) => total + value),
      chartLoading: false,
      errors: errors,
    );
  }

  int _bucketIndex(DateTime day, DateTime start, int buckets, String format) {
    if (format == 'dia') {
      return day.difference(start).inDays.clamp(0, buckets - 1);
    }
    if (format == 'semana') {
      return (day.difference(start).inDays ~/ 7).clamp(0, buckets - 1);
    }
    return ((day.year - start.year) * 12 + day.month - start.month).clamp(
      0,
      buckets - 1,
    );
  }

  List<String> _labels(DateTime start, int buckets, String format) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const months = [
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
    if (format == 'dia') {
      return List.generate(
        buckets,
        (index) => days[start.add(Duration(days: index)).weekday - 1],
      );
    }
    if (format == 'semana') {
      return List.generate(buckets, (index) => 'S${index + 1}');
    }
    return List.generate(
      buckets,
      (index) => months[(start.month - 1 + index) % 12],
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardData>((ref) {
      final auth = ref.watch(authProvider);
      final selectedSedeId = ref.watch(globalSedeIdProvider);
      final effectiveSedeId = auth.user?.isSuperAdmin == true
          ? selectedSedeId
          : auth.user?.sedeId;
      return DashboardNotifier(
        ApiClient.instance,
        auth.permisos.toSet(),
        effectiveSedeId,
      );
    });
