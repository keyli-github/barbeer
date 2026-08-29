import 'package:barbeer/core/async/operation_state.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapDioException', () {
    test('preserves normalized backend business error fields exactly', () {
      final exception = mapDioException(
        _responseError(
          statusCode: 409,
          data: const {
            'statusCode': 409,
            'message': 'La caja tiene ventas pendientes.',
            'path': '/api/caja/cerrar',
            'code': 'VENTAS_PENDIENTES',
          },
        ),
      );

      expect(exception.message, 'La caja tiene ventas pendientes.');
      expect(exception.statusCode, 409);
      expect(exception.path, '/api/caja/cerrar');
      expect(exception.code, 'VENTAS_PENDIENTES');
      expect(exception.details, isEmpty);
    });

    test('preserves every declared validation detail', () {
      final exception = mapDioException(
        _responseError(
          statusCode: 400,
          data: const {
            'statusCode': 400,
            'message': [
              'nombre no puede estar vacío.',
              'documento debe tener como máximo 20 caracteres.',
            ],
            'path': '/api/cuentas',
          },
        ),
      );

      expect(exception.message, 'nombre no puede estar vacío.');
      expect(exception.statusCode, 400);
      expect(exception.path, '/api/cuentas');
      expect(exception.code, isNull);
      expect(exception.details, const [
        'nombre no puede estar vacío.',
        'documento debe tener como máximo 20 caracteres.',
      ]);
    });

    test('does not replace an exact backend throttling message', () {
      final exception = mapDioException(
        _responseError(
          statusCode: 429,
          data: const {
            'statusCode': 429,
            'message': 'Reintenta después de 45 segundos.',
            'path': '/api/usuarios/validate-pin',
            'code': 'PIN_THROTTLED',
          },
        ),
      );

      expect(exception.message, 'Reintenta después de 45 segundos.');
      expect(exception.statusCode, 429);
      expect(exception.path, '/api/usuarios/validate-pin');
      expect(exception.code, 'PIN_THROTTLED');
    });
  });

  group('OperationState', () {
    test('distinguishes loading, content, and empty results', () {
      const loading = OperationLoading<List<int>>();
      const content = OperationContent<List<int>>([1, 2]);
      const empty = OperationEmpty<List<int>>();

      expect(loading, isA<OperationLoading<List<int>>>());
      expect(content, isA<OperationContent<List<int>>>());
      expect(content.data, const [1, 2]);
      expect(empty, isA<OperationEmpty<List<int>>>());
      expect({
        loading.runtimeType,
        content.runtimeType,
        empty.runtimeType,
      }, hasLength(3));
    });

    test('keeps recoverable errors distinct from partial results', () {
      const requestError = AppException(
        message: 'No se pudo cargar la cuenta.',
        statusCode: 503,
        path: '/api/cuentas/1',
      );
      const stockError = AppException(
        message: 'No se pudo cargar stock.',
        statusCode: 503,
        path: '/api/dashboard/stock',
      );
      const recoverable = OperationRecoverableError<Map<String, int>>(
        requestError,
      );
      const partial = OperationPartial<Map<String, int>>(
        data: {'ventas': 12},
        errors: {'stock': stockError},
      );

      expect(recoverable.error, same(requestError));
      expect(partial.data, const {'ventas': 12});
      expect(partial.errors['stock'], same(stockError));
      expect(recoverable.runtimeType, isNot(partial.runtimeType));
    });
  });
}

DioException _responseError({
  required int statusCode,
  required Map<String, dynamic> data,
}) {
  final request = RequestOptions(path: data['path'] as String);
  return DioException(
    requestOptions: request,
    response: Response<Map<String, dynamic>>(
      requestOptions: request,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
  );
}
