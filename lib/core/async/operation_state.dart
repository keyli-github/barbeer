import '../errors/app_exception.dart';

sealed class OperationState<T> {
  const OperationState();
}

final class OperationLoading<T> extends OperationState<T> {
  const OperationLoading();
}

final class OperationContent<T> extends OperationState<T> {
  final T data;

  const OperationContent(this.data);
}

final class OperationEmpty<T> extends OperationState<T> {
  const OperationEmpty();
}

final class OperationRecoverableError<T> extends OperationState<T> {
  final AppException error;

  const OperationRecoverableError(this.error);
}

final class OperationPartial<T> extends OperationState<T> {
  final T data;
  final Map<String, AppException> errors;

  const OperationPartial({required this.data, required this.errors});
}
