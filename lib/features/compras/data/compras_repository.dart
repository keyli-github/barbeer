import '../../../core/network/api_client.dart';

String _stringValue(Object? value) => value is String ? value : '';

String? _optionalStringValue(Object? value) {
  final parsed = _stringValue(value).trim();
  return parsed.isEmpty ? null : parsed;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Map<String, dynamic> _mapValue(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};

List<Object?> _listValue(Object? value) => value is List ? value : const [];

class CompraSede {
  final String id, nombre;

  const CompraSede({required this.id, required this.nombre});

  factory CompraSede.fromJson(Map<String, dynamic> json) => CompraSede(
    id: _stringValue(json['id']),
    nombre: _stringValue(json['nombre']),
  );
}

class CompraCreateItem {
  final String productoId;
  final double cantidad, costoUnit, precioVenta;

  const CompraCreateItem({
    required this.productoId,
    required this.cantidad,
    required this.costoUnit,
    required this.precioVenta,
  });

  double get subtotal => cantidad * costoUnit;

  bool get isValid =>
      productoId.trim().isNotEmpty &&
      cantidad.isFinite &&
      cantidad > 0 &&
      _isValidMoney(costoUnit) &&
      _isValidMoney(precioVenta);

  static bool _isValidMoney(double value) =>
      value.isFinite &&
      value > 0 &&
      value <= 9999999999.99 &&
      ((value * 100) - (value * 100).round()).abs() < 0.000001;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'productoId': productoId.trim(),
    'cantidad': cantidad,
    'costoUnit': costoUnit,
    'precioVenta': precioVenta,
  };
}

CompraCreateItem? parseCompraCreateItem({
  required String productoId,
  required String cantidad,
  required String costoUnit,
  required String precioVenta,
}) {
  double? parse(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  final item = CompraCreateItem(
    productoId: productoId,
    cantidad: parse(cantidad) ?? double.nan,
    costoUnit: parse(costoUnit) ?? double.nan,
    precioVenta: parse(precioVenta) ?? double.nan,
  );
  return item.isValid ? item : null;
}

Map<String, dynamic> buildCompraCreateData({
  required String proveedorId,
  required String sedeId,
  required List<CompraCreateItem> items,
  String? eta,
  String? notas,
}) {
  final normalizedProveedorId = proveedorId.trim();
  final normalizedSedeId = sedeId.trim();
  if (normalizedProveedorId.isEmpty) {
    throw ArgumentError('proveedorId es requerido');
  }
  if (normalizedSedeId.isEmpty) throw ArgumentError('sedeId es requerido');
  if (items.isEmpty) throw ArgumentError('Se requiere al menos un item');
  if (items.any((item) => !item.isValid)) {
    throw ArgumentError('Todos los items deben tener valores validos');
  }
  return <String, dynamic>{
    'proveedorId': normalizedProveedorId,
    'sedeId': normalizedSedeId,
    'items': items.map((item) => item.toJson()).toList(),
    if (eta?.trim().isNotEmpty ?? false) 'eta': eta!.trim(),
    if (notas?.trim().isNotEmpty ?? false) 'notas': notas!.trim(),
  };
}

class Proveedor {
  final String id, nombre;
  final String? categoria, contacto, telefono, email;
  final bool activo;
  final int ordenes;
  final double total;

  const Proveedor({
    required this.id,
    required this.nombre,
    this.categoria,
    this.contacto,
    this.telefono,
    this.email,
    required this.activo,
    required this.ordenes,
    required this.total,
  });

  factory Proveedor.fromJson(Map<String, dynamic> j) => Proveedor(
    id: _stringValue(j['id']),
    nombre: _stringValue(j['nombre']),
    categoria: _optionalStringValue(j['categoria']),
    contacto: _optionalStringValue(j['contacto']),
    telefono: _optionalStringValue(j['telefono']),
    email: _optionalStringValue(j['email']),
    activo: j['activo'] == true,
    ordenes: _intValue(j['ordenes']),
    total: _doubleValue(j['total']),
  );
}

class CompraItem {
  final String id, productoId, codigo, producto;
  final double cantidad, costoUnit, subtotal;
  const CompraItem({
    required this.id,
    required this.productoId,
    required this.codigo,
    required this.producto,
    required this.cantidad,
    required this.costoUnit,
    required this.subtotal,
  });
  factory CompraItem.fromJson(Map<String, dynamic> j) => CompraItem(
    id: _stringValue(j['id']),
    productoId: _stringValue(j['productoId']),
    codigo: _stringValue(j['codigo']),
    // 'producto' puede venir como String o como Map {nombre:...}
    producto: j['producto'] is Map
        ? _stringValue((j['producto'] as Map)['nombre'])
        : _stringValue(j['producto']),
    cantidad: _doubleValue(j['cantidad']),
    costoUnit: _doubleValue(j['costoUnit']),
    subtotal: _doubleValue(j['subtotal']),
  );
}

class Compra {
  final String id,
      orden,
      fecha,
      proveedor,
      proveedorId,
      estado,
      solicitadoPor,
      notas;
  final int articulos;
  final double total;
  final String? eta, recibidaAt;
  final List<CompraItem>? items;

  const Compra({
    required this.id,
    required this.orden,
    required this.fecha,
    required this.proveedor,
    required this.proveedorId,
    required this.estado,
    required this.solicitadoPor,
    required this.notas,
    required this.articulos,
    required this.total,
    this.eta,
    this.recibidaAt,
    this.items,
  });

  factory Compra.fromJson(Map<String, dynamic> j) => Compra(
    id: _stringValue(j['id']),
    orden: _stringValue(j['orden']),
    fecha: _stringValue(j['fecha']),
    // 'proveedor' puede venir como String o como Map {nombre:...}
    proveedor: j['proveedor'] is Map
        ? _stringValue((j['proveedor'] as Map)['nombre'])
        : _stringValue(j['proveedor']),
    proveedorId: _stringValue(j['proveedorId']),
    estado: _stringValue(j['estado']).isEmpty
        ? 'PENDIENTE'
        : _stringValue(j['estado']),
    // 'solicitadoPor' puede venir como String o Map {username:...}
    solicitadoPor: j['solicitadoPor'] is Map
        ? _stringValue((j['solicitadoPor'] as Map)['username'])
        : _stringValue(j['solicitadoPor']),
    notas: _stringValue(j['notas']),
    articulos: _intValue(j['articulos']),
    total: _doubleValue(j['total']),
    eta: _optionalStringValue(j['eta']),
    recibidaAt: _optionalStringValue(j['recibidaAt']),
    items: j['items'] is List
        ? (j['items'] as List)
              .whereType<Map>()
              .map((e) => CompraItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : null,
  );
}

class ComprasResumen {
  final int totalOrdenes, pendientes, recibidas;
  final double montoPendiente;
  const ComprasResumen({
    required this.totalOrdenes,
    required this.pendientes,
    required this.recibidas,
    required this.montoPendiente,
  });
  factory ComprasResumen.fromJson(Map<String, dynamic> j) => ComprasResumen(
    totalOrdenes: _intValue(j['totalOrdenes']),
    pendientes: _intValue(j['pendientes']),
    recibidas: _intValue(j['recibidas']),
    montoPendiente: _doubleValue(j['montoPendiente']),
  );
}

class ComprasPage<T> {
  final List<T> data;
  final int total, pagina, totalPaginas;
  const ComprasPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class ComprasRepository {
  final ApiClient _api;
  const ComprasRepository(this._api);

  // ── Proveedores ──────────────────────────────────────────────
  Future<ComprasPage<Proveedor>> listProveedores({
    int pagina = 1,
    int limite = 20,
    String? q,
    String? activo,
  }) async {
    final r = await _api.get(
      '/compras/proveedores',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        'activo': ?activo,
      },
    );
    final json = _mapValue(r.data);
    return ComprasPage(
      data: _listValue(json['data'])
          .whereType<Map>()
          .map((e) => Proveedor.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _intValue(json['total']),
      pagina: _intValue(json['pagina']) == 0
          ? pagina
          : _intValue(json['pagina']),
      totalPaginas: _intValue(json['totalPaginas']) == 0
          ? 1
          : _intValue(json['totalPaginas']),
    );
  }

  Future<Proveedor> createProveedor({
    required String nombre,
    String? categoria,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    final r = await _api.post(
      '/compras/proveedores',
      data: {
        'nombre': nombre,
        if (categoria?.trim().isNotEmpty ?? false)
          'categoria': categoria!.trim(),
        if (contacto?.trim().isNotEmpty ?? false) 'contacto': contacto!.trim(),
        if (telefono?.trim().isNotEmpty ?? false) 'telefono': telefono!.trim(),
        if (email?.trim().isNotEmpty ?? false) 'email': email!.trim(),
      },
    );
    return Proveedor.fromJson(_mapValue(r.data));
  }

  Future<Proveedor> updateProveedor(
    String id,
    Map<String, dynamic> data,
  ) async {
    final r = await _api.patch('/compras/proveedores/$id', data: data);
    return Proveedor.fromJson(_mapValue(r.data));
  }

  Future<List<CompraSede>> listSedes({int pagina = 1, int limite = 100}) async {
    final r = await _api.get(
      '/establecimientos',
      queryParameters: {'pagina': pagina, 'limite': limite},
    );
    final json = _mapValue(r.data);
    return _listValue(json['data'])
        .whereType<Map>()
        .where((item) => item['activo'] == true)
        .map((item) => CompraSede.fromJson(Map<String, dynamic>.from(item)))
        .where((sede) => sede.id.isNotEmpty)
        .toList();
  }

  // ── Órdenes de compra ────────────────────────────────────────
  Future<ComprasPage<Compra>> listCompras({
    int pagina = 1,
    int limite = 15,
    String? q,
    String? estado,
    String? proveedorId,
    String? sedeId,
  }) async {
    final r = await _api.get(
      '/compras',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        'estado': ?estado,
        'proveedorId': ?proveedorId,
        'sedeId': ?sedeId,
      },
    );
    final json = _mapValue(r.data);
    return ComprasPage(
      data: _listValue(json['data'])
          .whereType<Map>()
          .map((e) => Compra.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _intValue(json['total']),
      pagina: _intValue(json['pagina']) == 0
          ? pagina
          : _intValue(json['pagina']),
      totalPaginas: _intValue(json['totalPaginas']) == 0
          ? 1
          : _intValue(json['totalPaginas']),
    );
  }

  Future<ComprasResumen> resumen({String? estado, String? sedeId}) async {
    final r = await _api.get(
      '/compras/resumen',
      queryParameters: {'estado': ?estado, 'sedeId': ?sedeId},
    );
    return ComprasResumen.fromJson(_mapValue(r.data));
  }

  Future<Compra> getCompra(String id) async {
    final r = await _api.get('/compras/$id');
    return Compra.fromJson(_mapValue(r.data));
  }

  Future<Compra> createCompra({
    required String proveedorId,
    required String sedeId,
    required List<CompraCreateItem> items,
    String? eta,
    String? notas,
  }) async {
    final r = await _api.post(
      '/compras',
      data: buildCompraCreateData(
        proveedorId: proveedorId,
        sedeId: sedeId,
        items: items,
        eta: eta,
        notas: notas,
      ),
    );
    return Compra.fromJson(_mapValue(r.data));
  }

  Future<Compra> cambiarEstado(String id, String estado) async {
    final r = await _api.patch('/compras/$id/estado', data: {'estado': estado});
    return Compra.fromJson(_mapValue(r.data));
  }
}
