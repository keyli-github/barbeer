import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/productos/data/productos_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list forwards bounded search and backend catalog filters', () async {
    String? requestedPath;
    Map<String, dynamic>? requestedQuery;
    final repository = ProductosRepository(
      ApiClient.instance,
      request: (path, query) async {
        requestedPath = path;
        requestedQuery = query;
        return {
          'data': [
            {
              'id': 'product-1',
              'codigo': 'SKU-1',
              'nombre': 'Negative stock item',
              'categoria': 'Drinks',
              'categoriaId': 'category-1',
              'unidad': 'unit',
              'precioVenta': 12,
              'disponiblePos': true,
              'activo': true,
              'stockDisponible': -2,
            },
          ],
          'total': 51,
          'pagina': 2,
          'limite': 50,
          'totalPaginas': 2,
        };
      },
    );

    final page = await repository.list(
      pagina: 2,
      limite: 50,
      q: 'lager',
      activo: 'true',
      disponiblePos: 'true',
      sedeId: 'sede-1',
    );

    expect(requestedPath, '/productos');
    expect(requestedQuery, {
      'pagina': 2,
      'limite': 50,
      'q': 'lager',
      'activo': 'true',
      'disponiblePos': 'true',
      'sedeId': 'sede-1',
    });
    expect(page.pagina, 2);
    expect(page.totalPaginas, 2);
    expect(page.data.single.stockDisponible, -2);
    expect(page.data.single.precioCosto, isNull);
  });
}
