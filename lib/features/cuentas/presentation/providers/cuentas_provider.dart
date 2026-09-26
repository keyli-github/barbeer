import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/navigation/route_access_policy.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cuentas_repository.dart';
import '../../data/models/cuenta_models.dart';

class CuentasState {
  final List<Cuenta> items;
  final OperationState<List<Cuenta>> listState;
  final OperationState<CuentaDetalle>? detailState;
  final String? selectedId;
  final String search;
  final int page, pageSize;
  final bool collectionBusy, collectionSucceeded;
  final AppException? collectionError;
  const CuentasState(
      {this.items = const [],
      this.listState = const OperationLoading(),
      this.detailState,
      this.selectedId,
      this.search = '',
      this.page = 1,
      this.pageSize = 10,
      this.collectionBusy = false,
      this.collectionSucceeded = false,
      this.collectionError});
  int get totalPages =>
      items.isEmpty ? 1 : (items.length + pageSize - 1) ~/ pageSize;
  List<Cuenta> get pageItems =>
      items.skip((page - 1) * pageSize).take(pageSize).toList();
  CuentasState copy(
          {List<Cuenta>? items,
          OperationState<List<Cuenta>>? listState,
          OperationState<CuentaDetalle>? detailState,
          String? selectedId,
          int? page}) =>
      CuentasState(
          items: items ?? this.items,
          listState: listState ?? this.listState,
          detailState: detailState ?? this.detailState,
          selectedId: selectedId ?? this.selectedId,
          search: search,
          page: page ?? this.page,
          pageSize: pageSize,
          collectionBusy: collectionBusy,
          collectionSucceeded: collectionSucceeded,
          collectionError: collectionError);
  CuentasState collection(
      {required bool busy,
      bool succeeded = false,
      AppException? error,
      OperationState<CuentaDetalle>? detail,
      List<Cuenta>? items}) {
    final nextItems = items ?? this.items;
    return CuentasState(
        items: nextItems,
        listState: nextItems.isEmpty
            ? const OperationEmpty()
            : OperationContent(nextItems),
        detailState: detail ?? detailState,
        selectedId: selectedId,
        search: search,
        page: page,
        pageSize: pageSize,
        collectionBusy: busy,
        collectionSucceeded: succeeded,
        collectionError: error);
  }
}

class CuentasNotifier extends StateNotifier<CuentasState> {
  final CuentasRepository _repository;
  final bool authorized;
  final bool canCreate;
  final bool canCollect;
  final String? sedeId;
  final Future<void> Function()? onForbidden;
  final String Function() _keyFactory;
  int _listGeneration = 0, _detailGeneration = 0;
  Future<void>? _collectionFuture;
  String? _collectionFingerprint, _collectionKey;
  Future<CuentaDetalle>? _saldoFavorFuture;
  String? _saldoFavorFingerprint, _saldoFavorKey;
  CuentasNotifier(this._repository,
      {required this.authorized,
      required this.sedeId,
      this.canCreate = false,
      this.canCollect = false,
      this.onForbidden,
      String Function()? keyFactory,
      int pageSize = 10})
      : _keyFactory = keyFactory ?? const Uuid().v4,
        super(CuentasState(pageSize: pageSize));
  bool get canPayOutSaldoFavor => canCollect;

  Future<void> load({String? search}) async {
    final generation = ++_listGeneration;
    final query = (search ?? state.search).trim();
    final localError = !authorized
        ? const AppException(message: 'No autorizado.', statusCode: 403)
        : (sedeId?.isEmpty ?? true)
            ? const AppException(
                message: 'Debe seleccionar una sede', statusCode: 400)
            : null;
    if (localError != null) {
      state = CuentasState(
          listState: OperationRecoverableError(localError),
          search: query,
          pageSize: state.pageSize);
      return;
    }
    state = CuentasState(search: query, pageSize: state.pageSize);
    try {
      final items = await _repository.list(search: query, sedeId: sedeId!);
      if (generation != _listGeneration) return;
      state = CuentasState(
          items: items,
          listState:
              items.isEmpty ? const OperationEmpty() : OperationContent(items),
          search: query,
          pageSize: state.pageSize);
    } catch (error) {
      if (generation != _listGeneration) return;
      final exception = _exception(error);
      if (exception.statusCode == 403) await onForbidden?.call();
      if (generation == _listGeneration)
        state = CuentasState(
            listState: OperationRecoverableError(exception),
            search: query,
            pageSize: state.pageSize);
    }
  }

  Future<void> select(String id) async {
    final generation = ++_detailGeneration;
    state = state.copy(
        listState: _listState(),
        detailState: const OperationLoading(),
        selectedId: id);
    try {
      final detail = await _repository.detail(id, sedeId: sedeId!);
      if (generation == _detailGeneration)
        state = state.copy(detailState: OperationContent(detail));
    } catch (error) {
      if (generation != _detailGeneration) return;
      final exception = _exception(error);
      if (exception.statusCode == 403) await onForbidden?.call();
      if (generation == _detailGeneration)
        state = state.copy(
            listState: OperationPartial(
                data: state.items, errors: {'detail': exception}),
            detailState: OperationRecoverableError(exception));
    }
  }

  Future<Cuenta> create(
      {required String nombre, String? documento, String? telefono}) async {
    if (!canCreate)
      throw const AppException(message: 'No autorizado.', statusCode: 403);
    try {
      return await _repository.create(
          nombre: nombre, documento: documento, telefono: telefono);
    } catch (error) {
      final exception = _exception(error);
      if (exception.statusCode == 403) await onForbidden?.call();
      throw exception;
    }
  }

  Future<void> collect(
      {required double monto,
      required String medioPago,
      String? comprobanteAnalisisId}) {
    if (_collectionFuture != null) return _collectionFuture!;
    final future = _collect(monto, medioPago, comprobanteAnalisisId);
    _collectionFuture = future;
    future.whenComplete(() {
      if (identical(_collectionFuture, future)) _collectionFuture = null;
    });
    return future;
  }

  Future<CuentaDetalle> paySaldoFavor(
      {required String cuentaId, required double monto}) {
    if (!canPayOutSaldoFavor) {
      return Future.error(
          const AppException(message: 'No autorizado.', statusCode: 403));
    }
    final selectedSedeId = sedeId;
    if (selectedSedeId == null || selectedSedeId.isEmpty) {
      return Future.error(const AppException(
          message: 'Debe seleccionar una sede', statusCode: 400));
    }
    final accountIndex = state.items.indexWhere((item) => item.id == cuentaId);
    final account = accountIndex < 0 ? null : state.items[accountIndex];
    if (account == null || account.saldoEfectivoCaja <= 0) {
      return Future.error(const AppException(
          message: 'Esta cuenta no tiene saldo a favor', statusCode: 409));
    }
    final available = double.parse(account.saldoEfectivoCaja.toStringAsFixed(2));
    final cents = monto * 100;
    if (!monto.isFinite ||
        monto < 0.01 ||
        monto > 999999999.99 ||
        monto > available ||
        (cents - cents.round()).abs() > 0.000001) {
      return Future.error(const AppException(
          message: 'Ingresa un monto válido dentro del saldo a favor',
          statusCode: 400));
    }

    final fingerprint = '$cuentaId|${monto.toStringAsFixed(2)}|$selectedSedeId';
    if (_saldoFavorFuture != null) {
      if (_saldoFavorFingerprint == fingerprint) return _saldoFavorFuture!;
      return Future.error(const AppException(
          message: 'Ya hay una devolución en curso', statusCode: 409));
    }
    if (_saldoFavorFingerprint != fingerprint) {
      _saldoFavorFingerprint = fingerprint;
      _saldoFavorKey = _keyFactory();
    }
    final future = _paySaldoFavor(
        cuentaId: cuentaId,
        monto: monto,
        idempotencyKey: _saldoFavorKey!,
        sedeId: selectedSedeId);
    _saldoFavorFuture = future;
    void clearFuture() {
      if (identical(_saldoFavorFuture, future)) _saldoFavorFuture = null;
    }
    future.then<void>((_) => clearFuture(),
        onError: (Object error, StackTrace stackTrace) => clearFuture());
    return future;
  }

  Future<CuentaDetalle> _paySaldoFavor(
      {required String cuentaId,
      required double monto,
      required String idempotencyKey,
      required String sedeId}) async {
    try {
      final detail = await _repository.paySaldoFavor(cuentaId,
          monto: monto,
          medioPago: 'EFECTIVO',
          idempotencyKey: idempotencyKey,
          sedeId: sedeId);
      final updatedItems = state.items
          .map((item) => item.id == cuentaId
              ? item.withDebt(
                  saldo: detail.saldo,
                  cantidadPendientes:
                      detail.pendientes.length + detail.cargosPendientes.length,
                  saldoEfectivoCaja: detail.cuenta.saldoEfectivoCaja)
              : item)
          .toList();
      state = state.copy(
          items: updatedItems,
          listState: updatedItems.isEmpty
              ? const OperationEmpty()
              : OperationContent(updatedItems));
      if (state.selectedId == cuentaId) {
        state = state.copy(detailState: OperationContent(detail));
      }
      _saldoFavorFingerprint = null;
      _saldoFavorKey = null;
      return detail;
    } catch (error) {
      final exception = _exception(error);
      if (exception.statusCode == 403) await onForbidden?.call();
      throw exception;
    }
  }

  Future<void> _collect(
      double monto, String medioPago, String? comprobanteAnalisisId) async {
    final id = state.selectedId;
    if (!canCollect || id == null) {
      state = state.collection(
          busy: false,
          error:
              const AppException(message: 'No autorizado.', statusCode: 403));
      return;
    }
    final fingerprint =
        '$id|${monto.toStringAsFixed(2)}|$medioPago|${comprobanteAnalisisId ?? ''}|$sedeId';
    if (_collectionFingerprint != fingerprint) {
      _collectionFingerprint = fingerprint;
      _collectionKey = _keyFactory();
    }
    state = state.collection(busy: true);
    try {
      final detail = await _repository.collect(id,
          monto: monto,
          medioPago: medioPago,
          idempotencyKey: _collectionKey!,
          comprobanteAnalisisId: comprobanteAnalisisId,
          sedeId: sedeId);
      final updatedItems = detail.saldo <= .009
          ? state.items.where((item) => item.id != id).toList()
          : state.items
              .map((item) => item.id == id
                  ? item.withDebt(
                      saldo: detail.saldo,
                      cantidadPendientes: detail.pendientes.length)
                  : item)
              .toList();
      if (state.selectedId == id) {
        state = state.collection(
            busy: false,
            succeeded: true,
            detail: OperationContent(detail),
            items: updatedItems);
      } else {
        state =
            state.collection(busy: false, succeeded: true, items: updatedItems);
      }
      _collectionFingerprint = null;
      _collectionKey = null;
    } catch (error) {
      final exception = _exception(error);
      if (exception.statusCode == 403) await onForbidden?.call();
      state = state.collection(busy: false, error: exception);
    }
  }

  void setPage(int value) =>
      state = state.copy(page: value.clamp(1, state.totalPages));
  OperationState<List<Cuenta>> _listState() => state.items.isEmpty
      ? const OperationEmpty()
      : OperationContent(state.items);
  AppException _exception(Object error) =>
      error is AppException ? error : AppException(message: '$error');
}

final cuentasRepositoryProvider =
    Provider((_) => CuentasRepository(ApiClient.instance));
final cuentasProvider =
    StateNotifierProvider.autoDispose<CuentasNotifier, CuentasState>((ref) {
  final auth = ref.watch(authProvider), user = ref.watch(authProvider).user;
  final selectedSede = ref.watch(globalSedeIdProvider);
  final notifier = CuentasNotifier(ref.watch(cuentasRepositoryProvider),
      authorized: auth.canAccess(RoutePaths.cuentas),
      canCollect: auth.canPerform(const RouteAccessRule.both(
          {'SUPERADMIN', 'ADMIN'}, {'cuentas:editar'})),
      canCreate: user?.hasPermission('cuentas:crear') ?? false,
      sedeId: user?.isSuperAdmin == true ? selectedSede : user?.sedeId,
      onForbidden:
          ref.read(authProvider.notifier).refreshAuthorizationAfterForbidden);
  Future.microtask(notifier.load);
  return notifier;
});
