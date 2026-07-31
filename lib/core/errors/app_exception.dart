class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  const AppException({required this.message, this.statusCode, this.code});
  @override
  String toString() => message;
}

class SessionExpiredException extends AppException {
  const SessionExpiredException()
      : super(
          message: 'Tu sesion ha expirado. Por favor inicia sesion nuevamente.',
          statusCode: 401,
          code: 'SESSION_EXPIRED',
        );
}

class NetworkException extends AppException {
  const NetworkException()
      : super(
          message: 'Sin conexion. Verifica tu red e intenta nuevamente.',
          code: 'NETWORK_ERROR',
        );
}

class ServerException extends AppException {
  const ServerException({String? message})
      : super(
          message: message ?? 'Error en el servidor. Intenta mas tarde.',
          statusCode: 500,
        );
}

class NotFoundException extends AppException {
  const NotFoundException({String? message})
      : super(message: message ?? 'Recurso no encontrado.', statusCode: 404);
}

class ConflictException extends AppException {
  const ConflictException({required String message})
      : super(message: message, statusCode: 409);
}

class ValidationException extends AppException {
  const ValidationException({required String message})
      : super(message: message, statusCode: 400);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({String? message})
      : super(message: message ?? 'No autorizado.', statusCode: 403);
}
