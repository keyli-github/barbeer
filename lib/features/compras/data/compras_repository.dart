import '../../../core/network/api_client.dart';

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
    id: j['id'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    categoria: (j['categoria'] as String?)?.isEmpty ?? true ? null : j['categoria'] as String?,
    contacto: (j['contacto'] as String?)?.isEmpty ?? true ? null : j['contacto'] as String?,
    telefono: (j['telefono'] as String?)?.isEmpty ?? true ? null : j['telefono'] as String?,
    email: (j['email'] as String?)?.isEmpty ?? true ? null : j['email'] as String?,
    activo: j['activo'] as bool? ?? true,
    ordenes: (j['ordenes'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
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
    id: j['id'] as String? ?? '',
    productoId: j['productoId'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    producto: j['producto'] as String? ?? '',
    cantidad: (j['cantidad'] as num?)?.toDouble() ?? 0,
    costoUnit: (j['costoUnit'] as num?)?.toDouble() ?? 0,
    subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
  );
}

class Compra {
  final String id, orden, fecha, proveedor, proveedorId, estado, solicitadoPor, notas;
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
    id: j['id'] as String? ?? '',
    orden: j['orden'] as String? ?? '',
    fecha: j['fecha'] as String? ?? '',
    proveedor: j['proveedor'] as String? ?? '',
    proveedorId: j['proveedorId'] as String? ?? '',
    estado: j['estado'] as String? ?? 'PENDIENTE',
    solicitadoPor: j['solicitadoPor'] as String? ?? '',
    notas: j['notas'] as String? ?? '',
    articulos: (j['articulos'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toDouble() ?? 0,
    eta: j['eta'] as String?,
    recibidaAt: j['recibidaAt'] as String?,
    items: j['items'] is List
        ? (j['items'] as List)
            .map((e) => CompraItem.fromJson(Map<String, dynamic>.from(e as Map)))
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
    totalOrdenes: (j['totalOrdenes'] as num?)?.toInt() ?? 0,
    pendientes: (j['pendientes'] as num?)?.toInt() ?? 0,
    recibidas: (j['recibidas'] as num?)?.toInt() ?? 0,
    montoPendiente: (j['montoPendiente'] as num?)?.toDouble() ?? 0,
  );
}

class ComprasPage<T> {
  final List<T> data;
  final int total, pagina, totalPaginas;
  const ComprasPage({required this.data, required this.total, required this.pagina, required this.totalPaginas});
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
    final r = await _api.get('/compras/proveedores', queryParameters: {
      'pagina': pagina,
      'limite': limite,
      if (q != null && q.isNotEmpty) 'q': q,
      if (activo != null) 'activo': activo,
    });
    final json = Map<String, dynamic>.from(r.data as Map);
    return ComprasPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Proveedor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Proveedor> createProveedor({
    required String nombre,
    String? categoria,
    String? contacto,
    String? telefono,
    String? email,
  }) async {
    final r = await _api.post('/compras/proveedores', data: {
      'nombre': nombre,
      if (categoria?.trim().isNotEmpty ?? false) 'categoria': categoria!.trim(),
      if (contacto?.trim().isNotEmpty ?? false) 'contacto': contacto!.trim(),
      if (telefono?.trim().isNotEmpty ?? false) 'telefono': telefono!.trim(),
      if (email?.trim().isNotEmpty ?? false) 'email': email!.trim(),
    });
    return Proveedor.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Proveedor> updateProveedor(String id, Map<String, dynamic> data) async {
    final r = await _api.patch('/compras/proveedores/$id', data: data);
    return Proveedor.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  // ── Órdenes de compra ────────────────────────────────────────
  Future<ComprasPage<Compra>> listCompras({
    int pagina = 1,
    int limite = 15,
    String? q,
    String? estado,
    String? proveedorId,
  }) async {
    final r = await _api.get('/compras', queryParameters: {
      'pagina': pagina,
      'limite': limite,
      if (q != null && q.isNotEmpty) 'q': q,
      if (estado != null) 'estado': estado,
      if (proveedorId != null) 'proveedorId': proveedorId,
    });
    final json = Map<String, dynamic>.from(r.data as Map);
    return ComprasPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Compra.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<ComprasResumen> resumen({String? estado}) async {
    final r = await _api.get('/compras/resumen', queryParameters: {
      if (estado != null) 'estado': estado,
    });
    return ComprasResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Compra> getCompra(String id) async {
    final r = await _api.get('/compras/$id');
    return Compra.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Compra> createCompra({
    required String proveedorId,
    required List<Map<String, dynamic>> items,
    String? eta,
    String? notas,
  }) async {
    final r = await _api.post('/compras', data: {
      'proveedorId': proveedorId,
      'items': items,
      if (eta != null) 'eta': eta,
      if (notas?.trim().isNotEmpty ?? false) 'notas': notas!.trim(),
    });
    return Compra.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Compra> cambiarEstado(String id, String estado) async {
    final r = await _api.patch('/compras/$id/estado', data: {'estado': estado});
    return Compra.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}
