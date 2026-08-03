import '../../../core/network/api_client.dart';

class AsistenciaPlanilla {
  final String usuarioId, username, rol, fecha, estado;
  final String? sedeId, sedeName, asistenciaId, turno, horaEntrada, horaSalida, notas;
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

  factory AsistenciaPlanilla.fromJson(Map<String, dynamic> j) => AsistenciaPlanilla(
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
  factory AsistenciaResumen.fromJson(Map<String, dynamic> j) => AsistenciaResumen(
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
  const AsistenciaPage({required this.data, required this.total, required this.pagina, required this.totalPaginas});
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
    final r = await _api.get('/asistencia', queryParameters: {
      'pagina': pagina,
      'limite': limite,
      if (fecha != null) 'fecha': fecha,
      if (usuarioId != null) 'usuarioId': usuarioId,
    });
    final json = Map<String, dynamic>.from(r.data as Map);
    return AsistenciaPage(
      data: (json['data'] as List? ?? [])
          .map((e) => AsistenciaPlanilla.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<AsistenciaResumen> resumen({String? fecha}) async {
    final r = await _api.get('/asistencia/resumen', queryParameters: {
      if (fecha != null) 'fecha': fecha,
    });
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
    final r = await _api.post('/asistencia', data: {
      'usuarioId': usuarioId,
      if (fecha != null) 'fecha': fecha,
      if (estado != null) 'estado': estado,
      if (turno?.trim().isNotEmpty ?? false) 'turno': turno!.trim(),
      if (horaEntrada != null) 'horaEntrada': horaEntrada,
      if (horaSalida != null) 'horaSalida': horaSalida,
      if (notas?.trim().isNotEmpty ?? false) 'notas': notas!.trim(),
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> editar(String id, {
    String? estado,
    String? turno,
    String? horaEntrada,
    String? horaSalida,
    String? notas,
  }) async {
    final r = await _api.patch('/asistencia/$id', data: {
      if (estado != null) 'estado': estado,
      if (turno != null) 'turno': turno,
      if (horaEntrada != null) 'horaEntrada': horaEntrada,
      if (horaSalida != null) 'horaSalida': horaSalida,
      if (notas != null) 'notas': notas,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> eliminar(String id) => _api.delete('/asistencia/$id');
}
