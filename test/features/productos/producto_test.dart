import 'package:barbeer/features/productos/data/models/producto.dart' as modern;
import 'package:barbeer/features/productos/data/productos_repository.dart'
    as catalog;
import 'package:barbeer/features/categorias/data/categorias_repository.dart'
    show Categoria;
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';
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

  group('Categoria backend contract', () {
    test('fromJson maps id, nombre, activo, and productosCount', () {
      final cat = Categoria.fromJson({
        'id': 'cat-1',
        'nombre': 'Bebidas',
        'descripcion': 'Bebidas alcohólicas y sin alcohol',
        'activo': true,
        'productosCount': 12,
      });

      expect(cat.id, 'cat-1');
      expect(cat.nombre, 'Bebidas');
      expect(cat.activo, isTrue);
      expect(cat.productosCount, 12);
    });

    test('inactive category maps activo false and zero productosCount', () {
      final inactiva = Categoria.fromJson({
        'id': 'cat-2',
        'nombre': 'Obsoletos',
        'activo': false,
        'productosCount': 0,
      });

      expect(inactiva.activo, isFalse);
      expect(inactiva.productosCount, 0);
    });
  });

  group('Products and categories authorization matrix', () {
    AuthState _auth(String rol, List<String> permisos) => AuthState(
      status: AuthStatus.authenticated,
      user: UserProfile(
        id: 'u1',
        username: 'test',
        rol: rol,
        nivel: 10,
        createdAt: '2026-01-01',
        permisos: permisos,
      ),
    );

    test('productos:leer grants access to /productos', () {
      expect(_auth('ADMIN', ['productos:leer']).canAccess('/productos'), isTrue);
    });

    test('categorias:leer grants access to /categorias', () {
      expect(
        _auth('ADMIN', ['categorias:leer']).canAccess('/categorias'),
        isTrue,
      );
    });

    test('no product permission denies /productos and /categorias', () {
      final auth = _auth('VENDEDORA', ['ventas:crear', 'ventas:leer-propias']);
      expect(auth.canAccess('/productos'), isFalse);
      expect(auth.canAccess('/categorias'), isFalse);
    });

    test('SUPERADMIN with productos:leer and categorias:leer can access both', () {
      final auth = _auth('SUPERADMIN', ['productos:leer', 'categorias:leer']);
      expect(auth.canAccess('/productos'), isTrue);
      expect(auth.canAccess('/categorias'), isTrue);
    });
  });
}
