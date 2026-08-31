typedef Json = Map<String, dynamic>;
Json _json(Object? value) => Map<String, dynamic>.from(value as Map);
double _number(Object? value) => value is num ? value.toDouble() : double.parse(value as String);
class Cuenta {
  final String id, nombre, createdAt, updatedAt;
  final String? documento, telefono;
  final double saldo;
  final bool activo;
  final bool? esPersonal;
  final int? cantidadPendientes;
  const Cuenta({required this.id, required this.nombre, this.documento, this.telefono,
    required this.saldo, required this.activo, required this.cantidadPendientes,
    this.esPersonal, required this.createdAt, required this.updatedAt});
  factory Cuenta.fromJson(Json j) => Cuenta(
    id: j['id'] as String, nombre: j['nombre'] as String,
    documento: j['documento'] as String?, telefono: j['telefono'] as String?,
    saldo: _number(j['saldo']), activo: j['activo'] as bool,
    cantidadPendientes: (j['cantidadPendientes'] as num?)?.toInt(),
    esPersonal: j['esPersonal'] as bool?,
    createdAt: j['createdAt'] as String, updatedAt: j['updatedAt'] as String);
}
class CuentaMovimiento {
  final Json raw;
  CuentaMovimiento.fromJson(Json json) : raw = Map.unmodifiable(json);
  String get tipo => raw['tipo'] as String;
  double get monto => _number(raw['monto']);
  String? get referencia => raw['referencia'] as String?;
}
class CuentaPendienteItem {
  final String id;
  final double cantidad, precioUnitario, subtotal;
  final ({String id, String codigo, String nombre}) producto;
  CuentaPendienteItem.fromJson(Json j)
    : id = j['id'] as String, cantidad = _number(j['cantidad']),
      precioUnitario = _number(j['precioUnitario']), subtotal = _number(j['subtotal']),
      producto = (id: _json(j['producto'])['id'] as String,
        codigo: _json(j['producto'])['codigo'] as String,
        nombre: _json(j['producto'])['nombre'] as String);
}
class CuentaPendiente {
  final String id, codigo, fecha;
  final double montoPendiente, totalVenta;
  final double? recargoMonto;
  final String? recargoMotivo;
  final ({String id, String nombre}) sede;
  final List<CuentaPendienteItem> items;
  CuentaPendiente.fromJson(Json j)
    : id = j['id'] as String, codigo = j['codigo'] as String,
      fecha = j['fecha'] as String, montoPendiente = _number(j['montoPendiente']),
      totalVenta = _number(j['totalVenta']),
      recargoMonto = j['recargoMonto'] == null ? null : _number(j['recargoMonto']),
      recargoMotivo = j['recargoMotivo'] as String?,
      sede = (id: _json(j['sede'])['id'] as String,
        nombre: _json(j['sede'])['nombre'] as String),
      items = (j['items'] as List).map((value) =>
        CuentaPendienteItem.fromJson(_json(value))).toList();
}
class CuentaDetalle {
  final Cuenta cuenta;
  final List<CuentaMovimiento> movimientos;
  final List<CuentaPendiente> pendientes;
  const CuentaDetalle({required this.cuenta, required this.movimientos, required this.pendientes});
  factory CuentaDetalle.fromJson(Json j) => CuentaDetalle(
    cuenta: Cuenta.fromJson(j),
    movimientos: (j['movimientos'] as List).map((value) =>
      CuentaMovimiento.fromJson(_json(value))).toList(),
    pendientes: (j['pendientes'] as List).map((value) =>
      CuentaPendiente.fromJson(_json(value))).toList());
  String get id => cuenta.id; String get nombre => cuenta.nombre; double get saldo => cuenta.saldo;
}
