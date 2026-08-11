import 'package:barbeer/features/auditoria/presentation/screens/auditoria_screen.dart';
import 'package:barbeer/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:barbeer/features/kardex/data/kardex_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit username reads the nested usuario response', () {
    expect(
      auditUsername({
        'usuario': {'id': 'user-1', 'username': 'maria'},
      }),
      'maria',
    );
    expect(auditUsername({'usuario': null}), 'Sistema');
  });

  test('sale and annulment kardex types have correct semantics', () {
    expect(kardexIsSalida('SALIDA_VENTA'), isTrue);
    expect(kardexIsEntrada('SALIDA_VENTA'), isFalse);
    expect(kardexTipoLabel('SALIDA_VENTA'), 'VENTA');
    expect(kardexIsEntrada('ENTRADA_ANULACION'), isTrue);
    expect(kardexIsSalida('ENTRADA_ANULACION'), isFalse);
    expect(kardexTipoLabel('ENTRADA_ANULACION'), 'ANULACIÓN');
  });

  test('dashboard parses codigoSede and retains explicit module errors', () {
    final sede = DashboardSede.fromMap({
      'id': 'sede-1',
      'nombre': 'Centro',
      'codigoSede': 'CENT',
      'activo': true,
    });
    const data = DashboardData(errors: {'inventario': 'Sin conexión'});

    expect(sede.codigoSede, 'CENT');
    expect(data.hasError('inventario'), isTrue);
    expect(data.hasError('productos'), isFalse);
  });
}
