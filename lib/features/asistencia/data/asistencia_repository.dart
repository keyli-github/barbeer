import '../../../core/network/api_client.dart';

// ── Turno model ──────────────────────────────────────────────────────────────

class Turno {
  final String id;
  final String sedeId;
  final String nombre;
  final int horaInicio; // minutos desde medianoche (480 = 08:00)
  final int horaFin;
  final int margenTardanza;
  final bool activo;

  const Turno({
    required this.id,
    required this.sedeId,
    required this.nombre,
    required this.horaInicio,
    required this.horaFin,
    required this.margenTardanza,
    required this.activo,
  });

  factory Turno.fromJson(Map<String, dynamic> j) => Turno(
    id: j['id'] as String? ?? '',
    sedeId: j['sedeId'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    horaInicio: (j['horaInicio'] as num?)?.toInt() ?? 0,
    horaFin: (j['horaFin'] as num?)?.toInt() ?? 0,
    margenTardanza: (j['margenTardanza'] as num?)?.toInt() ?? 15,
    activo: j['activo'] as bool? ?? true,
  );

  String get horaInicioLabel => _minutesToHHMM(horaInicio);
  String get horaFinLabel => _minutesToHHMM(horaFin);
  bool get cruzaMedianoche => horaFin < horaInicio;

  static String _minutesToHHMM(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class TurnoPage {
  final List<Turno> data;
  final int total, pagina, totalPaginas;
  const TurnoPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

// ── QR Kiosco response ───────────────────────────────────────────────────────

class QrKioscoResponse {
  final String token;
  final String sedeId;
  final String fecha;
  final int expiraEnSegundos;

  const QrKioscoResponse({
    required this.token,
    required this.sedeId,
    required this.fecha,
    required this.expiraEnSegundos,
  });

  factory QrKioscoResponse.fromJson(Map<String, dynamic> j) => QrKioscoResponse(
    token: j['token'] as String? ?? '',
    sedeId: j['sedeId'] as String? ?? '',
    fecha: j['fecha'] as String? ?? '',
    expiraEnSegundos: (j['expiraEnSegundos'] as num?)?.toInt() ?? 300,
  );
}

// ── Marcaje QR response ──────────────────────────────────────────────────────

class MarcajeQrResponse {
  final String tipo; // 'ENTRADA' | 'SALIDA'
  final String username;
  final String estado;
  final String? turno;
  final String hora;
  final double? horasTrabajadas;
  final String mensaje;

  const MarcajeQrResponse({
    required this.tipo,
    required this.username,
    required this.estado,
    this.turno,
    required this.hora,
    this.horasTrabajadas,
    required this.mensaje,
  });

  factory MarcajeQrResponse.fromJson(Map<String, dynamic> j) =>
      MarcajeQrResponse(
        tipo: j['tipo'] as String? ?? 'ENTRADA',
        username: j['username'] as String? ?? '',
        estado: j['estado'] as String? ?? '',
        turno: j['turno'] as String?,
        hora: j['hora'] as String? ?? '',
        horasTrabajadas: (j['horasTrabajadas'] as num?)?.toDouble(),
        mensaje: j['mensaje'] as String? ?? 'Asistencia registrada',
      );
}

class AsistenciaPlanilla {
  final String usuarioId, username, rol, fecha, estado;
  final String? sedeId,
      sedeName,
      asistenciaId,
      turno,
      horaEntrada,
      horaSalida,
      notas;
  final double? horasTrabajadas;

  const AsistenciaPlanilla({
    required this.usuarioId,
    required this.username,
    required this.rol,
    required this.fecha,
    required this.estado,
    this.sedeId,
    this.sedeName,
    this.asistenciaId,
    this.turno,
    this.horaEntrada,
    this.horaSalida,
    this.notas,
    this.horasTrabajadas,
  });

  factory AsistenciaPlanilla.fromJson(Map<String, dynamic> j) =>
      AsistenciaPlanilla(
        usuarioId: j['usuarioId'] as String? ?? '',
        username: j['username'] as String? ?? '',
        rol: j['rol'] as String? ?? '',
        fecha: j['fecha'] as String? ?? '',
        estado: j['estado'] as String? ?? 'AUSENTE',
        sedeId: (j['sede'] as Map?)?['id'] as String?,
        sedeName: (j['sede'] as Map?)?['nombre'] as String?,
        asistenciaId: j['asistenciaId'] as String?,
        turno: j['turno'] as String?,
        horaEntrada: j['horaEntrada'] as String?,
        horaSalida: j['horaSalida'] as String?,
        notas: j['notas'] as String?,
        horasTrabajadas: (j['horasTrabajadas'] as num?)?.toDouble(),
      );
}

class AsistenciaResumen {
  final String fecha;
  final int totalEmpleados, presente, tardanza, diaLibre, ausente;
  const AsistenciaResumen({
    required this.fecha,
    required this.totalEmpleados,
    required this.presente,
    required this.tardanza,
    required this.diaLibre,
    required this.ausente,
  });
  factory AsistenciaResumen.fromJson(Map<String, dynamic> j) =>
      AsistenciaResumen(
        fecha: j['fecha'] as String? ?? '',
        totalEmpleados: (j['totalEmpleados'] as num?)?.toInt() ?? 0,
        presente: (j['presente'] as num?)?.toInt() ?? 0,
        tardanza: (j['tardanza'] as num?)?.toInt() ?? 0,
        diaLibre: (j['diaLibre'] as num?)?.toInt() ?? 0,
        ausente: (j['ausente'] as num?)?.toInt() ?? 0,
      );
}

class AsistenciaPage {
  final List<AsistenciaPlanilla> data;
  final int total, pagina, totalPaginas;
  const AsistenciaPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class AsistenciaRepository {
  final ApiClient _api;
  const AsistenciaRepository(this._api);

  Future<AsistenciaPage> list({
    int pagina = 1,
    int limite = 25,
    String? fecha,
    String? usuarioId,
  }) async {
    final r = await _api.get(
      '/asistencia',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (fecha != null) 'fecha': fecha,
        if (usuarioId != null) 'usuarioId': usuarioId,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return AsistenciaPage(
      data: (json['data'] as List? ?? [])
          .map(
            (e) => AsistenciaPlanilla.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<AsistenciaResumen> resumen({String? fecha}) async {
    final r = await _api.get(
      '/asistencia/resumen',
      queryParameters: {if (fecha != null) 'fecha': fecha},
    );
    return AsistenciaResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Map<String, dynamic>> crear({
    required String usuarioId,
    String? fecha,
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  }) async {
    final r = await _api.post(
      '/asistencia',
      data: {
        'usuarioId': usuarioId,
        if (fecha != null) 'fecha': fecha,
        if (estado != null) 'estado': estado,
        if (turno?.trim().isNotEmpty ?? false) 'turno': turno!.trim(),
        if (horaEntrada != null) 'horaEntrada': horaEntrada,
        if (horaSalida != null) 'horaSalida': horaSalida,
        if (notas?.trim().isNotEmpty ?? false) 'notas': notas!.trim(),
      },
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> editar(
    String id, {
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  }) async {
    final r = await _api.patch(
      '/asistencia/$id',
      data: {
        if (estado != null) 'estado': estado,
        if (turno != null) 'turno': turno,
        if (horaEntrada != null) 'horaEntrada': horaEntrada,
        if (horaSalida != null) 'horaSalida': horaSalida,
        if (notas != null) 'notas': notas,
      },
    );
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> eliminar(String id) => _api.delete('/asistencia/$id');

  // ── QR Kiosco ──────────────────────────────────────────────────────────────

  Future<QrKioscoResponse> qrKiosco({String? sedeId}) async {
    final r = await _api.get(
      '/asistencia/qr-kiosco',
      queryParameters: {if (sedeId != null) 'sedeId': sedeId},
    );
    return QrKioscoResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<MarcajeQrResponse> marcar(String token) async {
    final r = await _api.post('/asistencia/marcar', data: {'qrToken': token});
    return MarcajeQrResponse.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

// ── Turnos repository ────────────────────────────────────────────────────────

class TurnosRepository {
  final ApiClient _api;
  const TurnosRepository(this._api);

  Future<TurnoPage> list({
    int pagina = 1,
    int limite = 25,
    String? sedeId,
    bool? soloActivos,
  }) async {
    final r = await _api.get(
      '/turnos',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (sedeId != null) 'sedeId': sedeId,
        if (soloActivos != null) 'soloActivos': soloActivos,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return TurnoPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Turno.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Turno> crear({
    required String sedeId,
    required String nombre,
    required int horaInicio,
    required int horaFin,
    int margenTardanza = 15,
    bool activo = true,
  }) async {
    final r = await _api.post(
      '/turnos',
      data: {
        'sedeId': sedeId,
        'nombre': nombre,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'margenTardanza': margenTardanza,
        'activo': activo,
      },
    );
    return Turno.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Turno> editar(
    String id, {
    String? nombre,
    int? horaInicio,
    int? horaFin,
    int? margenTardanza,
    bool? activo,
  }) async {
    final r = await _api.patch(
      '/turnos/$id',
      data: {
        if (nombre != null) 'nombre': nombre,
        if (horaInicio != null) 'horaInicio': horaInicio,
        if (horaFin != null) 'horaFin': horaFin,
        if (margenTardanza != null) 'margenTardanza': margenTardanza,
        if (activo != null) 'activo': activo,
      },
    );
    return Turno.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<void> eliminar(String id) => _api.delete('/turnos/$id');
}
