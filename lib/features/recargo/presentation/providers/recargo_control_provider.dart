import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../data/recargo_control_repository.dart';

class RecargoControlState {
  final RecargoControlData data;
  final AppException? error;
  const RecargoControlState({this.data = const RecargoControlData(), this.error});
  bool get oculto => data.oculto;
  bool get configurado => data.configurado;
  bool get puedeConfigurar => data.puedeConfigurar;
  bool get puedeCambiar => data.puedeCambiar;
}

class RecargoControlNotifier extends StateNotifier<RecargoControlState> {
  final RecargoControlRepository _repository;
  RecargoControlNotifier(this._repository) : super(const RecargoControlState());
  Future<void> load() => _replace(_repository.estado());
  Future<void> loadConfiguration() async {
    if (state.puedeConfigurar) await _replace(_repository.configuracion());
  }
  Future<void> guardar({String? clave, required Json responsables}) async {
    final invalidKey = clave != null && (clave.length < 6 || clave.length > 64);
    final incomplete = state.data.sedes.isEmpty || state.data.sedes.any(
      (sede) => !sede.usuarios.any((user) => user.id == responsables[sede.id]));
    if (invalidKey || (!state.configurado && clave == null) || incomplete) {
      _fail(const AppException(
        message: 'Complete la clave y responsables', statusCode: 400));
      return;
    }
    await _replace(_repository.guardarConfiguracion(
      clave: clave, responsables: responsables));
  }
  Future<void> cambiar({required String clave, required bool oculto}) async {
    try {
      final result = await _repository.cambiar(clave: clave, oculto: oculto);
      state = RecargoControlState(data: state.data.withHidden(result.oculto));
    } catch (error) { _fail(error); }
  }
  Future<void> _replace(Future<RecargoControlData> operation) async {
    try { state = RecargoControlState(data: await operation); }
    catch (error) { _fail(error); }
  }
  void _fail(Object error) => state = RecargoControlState(
    data: state.data,
    error: error is AppException ? error : AppException(message: '$error'),
  );
}

final recargoControlRepositoryProvider = Provider(
  (ref) => RecargoControlRepository(ApiClient.instance));
final recargoControlProvider = StateNotifierProvider<RecargoControlNotifier,
    RecargoControlState>((ref) => RecargoControlNotifier(
      ref.watch(recargoControlRepositoryProvider)));

bool shouldBlockPositiveRecargo({required bool oculto, num? monto}) =>
    oculto && (monto ?? 0) > 0;
({double? monto, String? motivo}) resolveRecargoDraft({
  required bool oculto, double? monto, String? motivo,
}) => shouldBlockPositiveRecargo(oculto: oculto, monto: monto)
    ? (monto: null, motivo: null) : (monto: monto, motivo: motivo);
