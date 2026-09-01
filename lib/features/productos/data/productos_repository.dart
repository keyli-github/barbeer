import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../../../core/network/api_client.dart';
import '../../categorias/data/categorias_repository.dart';

class Producto {
  final String id, codigo, nombre, categoriaId, unidad;
  final String categoria;
  final String? descripcion, presentacion, imagenUrl;
  final double precioVenta;
  /// null cuando el backend omite el campo (usuario sin productos:ver-utilidad).
  final double? precioCosto;
  final bool disponiblePos, activo;
  /// null cuando el backend omite el campo (usuario sin productos:ver-utilidad).
  final double? margin;
  final int? stockDisponible;

  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.categoriaId,
    required this.unidad,
    this.descripcion,
    this.presentacion,
    this.imagenUrl,
    required this.precioVenta,
    this.precioCosto,
    required this.disponiblePos,
    required this.activo,
    this.margin,
    this.stockDisponible,
  });

  factory Producto.fromJson(Map<String, dynamic> j) => Producto(
    id: j['id'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    // categoria puede llegar como String o como Map{nombre:...}
    categoria: j['categoria'] is Map
        ? ((j['categoria'] as Map)['nombre'] as String? ?? '')
        : j['categoria'] as String? ?? '',
    categoriaId: j['categoriaId'] as String? ?? '',
    unidad: j['unidad'] as String? ?? 'un',
    descripcion: j['descripcion'] as String?,
    presentacion: j['presentacion'] as String?,
    imagenUrl: j['imagenUrl'] as String?,
    precioVenta: (j['precioVenta'] as num?)?.toDouble() ?? 0,
    // null cuando el backend omite el campo (sin permiso ver-utilidad)
    precioCosto: j.containsKey('precioCosto')
        ? (j['precioCosto'] as num?)?.toDouble() ?? 0.0
        : null,
    disponiblePos: j['disponiblePos'] as bool? ?? false,
    activo: j['activo'] as bool? ?? true,
    margin: j.containsKey('margin')
        ? (j['margin'] as num?)?.toDouble() ?? 0.0
        : null,
    stockDisponible: (j['stockDisponible'] as num?)?.toInt(),
  );

  String? get imageUrl => imagenUrl;
}

class ProductosResumen {
  final int total, activos, enPos;
  final double valorCatalogo, margenPromedio;
  const ProductosResumen({
    required this.total,
    required this.activos,
    required this.enPos,
    required this.valorCatalogo,
    required this.margenPromedio,
  });
  factory ProductosResumen.fromJson(Map<String, dynamic> j) => ProductosResumen(
    total: (j['total'] as num?)?.toInt() ?? 0,
    activos: (j['activos'] as num?)?.toInt() ?? 0,
    enPos: (j['enPos'] as num?)?.toInt() ?? 0,
    valorCatalogo: (j['valorCatalogo'] as num?)?.toDouble() ?? 0,
    margenPromedio: (j['margenPromedio'] as num?)?.toDouble() ?? 0,
  );
}

class ProductosPage {
  final List<Producto> data;
  final int total, pagina, totalPaginas;
  const ProductosPage({
    required this.data,
    required this.total,
    required this.pagina,
    required this.totalPaginas,
  });
}

class ProductosRepository {
  final ApiClient _api;
  const ProductosRepository(this._api);

  Future<ProductosPage> list({
    int pagina = 1,
    int limite = 25,
    String? q,
    String? categoriaId,
    String? activo,
    String? sedeId,
  }) async {
    final r = await _api.get(
      '/productos',
      queryParameters: {
        'pagina': pagina,
        'limite': limite,
        if (q != null && q.isNotEmpty) 'q': q,
        'categoriaId': ?categoriaId,
        'activo': ?activo,
        'sedeId': ?sedeId,
      },
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return ProductosPage(
      data: (json['data'] as List? ?? [])
          .map((e) => Producto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pagina: (json['pagina'] as num?)?.toInt() ?? pagina,
      totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    );
  }

  Future<ProductosResumen> resumen() async {
    final r = await _api.get('/productos/resumen');
    return ProductosResumen.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> getById(String id, {String? sedeId}) async {
    final r = await _api.get(
      '/productos/$id',
      queryParameters: {'sedeId': ?sedeId},
    );
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> create({
    required String nombre,
    required String categoriaId,
    required double precioVenta,
    required double precioCosto,
    String? descripcion,
    String? imagenUrl,
  }) async {
    final r = await _api.post(
      '/productos',
      data: {
        'nombre': nombre,
        'categoriaId': categoriaId,
        'precioVenta': precioVenta,
        'precioCosto': precioCosto,
        if (descripcion?.trim().isNotEmpty ?? false)
          'descripcion': descripcion!.trim(),
        if (imagenUrl case final imagenUrl?) 'imagenUrl': imagenUrl.trim(),
        // disponiblePos y activo NO se envían al crear:
        // el backend los rechaza (no están en CreateProductoDto).
        // Usá PATCH /productos/:id para cambiarlos después.
      },
    );
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<Producto> update(String id, Map<String, dynamic> data) async {
    final r = await _api.patch('/productos/$id', data: data);
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<String> uploadImage(
    String id, {
    required Uint8List bytes,
    required String filename,
  }) async {
    final lower = filename.toLowerCase();
    final mediaType = lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
        ? MediaType('image', 'webp')
        : MediaType('image', 'jpeg');
    final response = await _api.postMultipart(
      '/productos/$id/imagen',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      }),
    );
    return (response.data as Map)['imagenUrl'] as String? ?? '';
  }

  Future<void> deleteImage(String id) => _api.delete('/productos/$id/imagen');

  Future<void> delete(String id) => _api.delete('/productos/$id');

  Future<Producto> toggle(String id, bool activo) async {
    final r = await _api.patch('/productos/$id', data: {'activo': activo});
    return Producto.fromJson(Map<String, dynamic>.from(r.data as Map));
  }

  Future<List<Categoria>> categorias({String? activo = 'true'}) async {
    final r = await _api.get(
      '/categorias',
      queryParameters: {'pagina': 1, 'limite': 100, 'activo': ?activo},
    );
    final json = Map<String, dynamic>.from(r.data as Map);
    return (json['data'] as List? ?? [])
        .map((e) => Categoria.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class ProductCreationSession {
  String? createdId;

  Future<void> submit({
    required Future<Producto> Function() create,
    required Future<void> Function(String id) uploadImage,
  }) async {
    createdId ??= (await create()).id;
    await uploadImage(createdId!);
  }
}
