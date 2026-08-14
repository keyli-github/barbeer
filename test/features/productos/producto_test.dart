import 'package:barbeer/features/productos/data/models/producto.dart' as modern;
import 'package:barbeer/features/productos/data/productos_repository.dart'
    as catalog;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Producto imagenUrl', () {
    test('reintenta solo la imagen después de crear el producto', () async {
      final session = catalog.ProductCreationSession();
      var createCalls = 0;
      var uploadCalls = 0;

      Future<catalog.Producto> create() async {
        createCalls++;
        return const catalog.Producto(
          id: 'product-1',
          codigo: 'CER-1',
          nombre: 'Cerveza',
          categoria: 'Bebidas',
          categoriaId: 'cat-1',
          unidad: 'unidad',
          precioVenta: 10,
          precioCosto: 5,
          disponiblePos: true,
          activo: true,
          margin: 50,
        );
      }

      Future<void> upload(String id) async {
        uploadCalls++;
        expect(id, 'product-1');
        if (uploadCalls == 1) throw Exception('upload failed');
      }

      await expectLater(
        session.submit(create: create, uploadImage: upload),
        throwsException,
      );
      expect(session.createdId, 'product-1');

      await session.submit(create: create, uploadImage: upload);
      expect(createCalls, 1);
      expect(uploadCalls, 2);
    });

    test('parsea imagenUrl del contrato del backend', () {
      final producto = catalog.Producto.fromJson({
        'id': 'p1',
        'nombre': 'Cerveza',
        'imagenUrl': '/api/uploads/cerveza.jpg',
      });

      expect(producto.imagenUrl, '/api/uploads/cerveza.jpg');
      expect(producto.imageUrl, producto.imagenUrl);
    });

    test('conserva null para que la UI muestre el fallback', () {
      final producto = catalog.Producto.fromJson({
        'id': 'p1',
        'nombre': 'Cerveza',
      });

      expect(producto.imagenUrl, isNull);
    });

    test('incluye imagenUrl recortada en create y update', () {
      const payload = modern.ProductoPayload(
        codigo: 'CER-1',
        nombre: 'Cerveza',
        descripcion: '',
        categoriaId: 'cat-1',
        unidad: 'unidad',
        precioVenta: 10,
        precioCosto: 5,
        disponiblePos: true,
        activo: true,
        imagenUrl: ' https://example.com/cerveza.jpg ',
      );

      expect(
        payload.toCreateJson()['imagenUrl'],
        'https://example.com/cerveza.jpg',
      );
      expect(
        payload.toUpdateJson()['imagenUrl'],
        'https://example.com/cerveza.jpg',
      );
    });

    test('permite enviar una URL vacía para restaurar el fallback', () {
      const payload = modern.ProductoPayload(
        codigo: 'CER-1',
        nombre: 'Cerveza',
        descripcion: '',
        categoriaId: 'cat-1',
        unidad: 'unidad',
        precioVenta: 10,
        precioCosto: 5,
        disponiblePos: true,
        activo: true,
        imagenUrl: '',
      );

      expect(payload.toUpdateJson(), containsPair('imagenUrl', ''));
    });
  });
}
