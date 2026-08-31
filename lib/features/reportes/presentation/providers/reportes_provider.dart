import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/routes/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/reporte_models.dart';
import '../../data/reportes_repository.dart';
class ReportesState {
  final bool authorized, exportBusy, emailSaveBusy, emailTestBusy, emailSaveSucceeded;
  final OperationState<ReporteEmailConfig> emailConfigState;
  final OperationState<ReporteExportado>? exportState;
  final AppException? emailSaveError, emailTestError;
  final ReporteEmailTestResult? emailTestResult;
  const ReportesState({this.authorized = false, this.exportBusy = false,
    this.emailSaveBusy = false, this.emailTestBusy = false, this.emailSaveSucceeded = false,
    this.emailConfigState = const OperationLoading(), this.exportState,
    this.emailSaveError, this.emailTestError, this.emailTestResult});
  ReportesState copyWith({OperationState<ReporteEmailConfig>? emailConfigState,
    OperationState<ReporteExportado>? exportState, bool? exportBusy, bool? emailSaveBusy,
    bool? emailTestBusy, bool? emailSaveSucceeded, AppException? emailSaveError,
    AppException? emailTestError, ReporteEmailTestResult? emailTestResult,
    bool clearEmailSaveError = false, bool clearEmailTestError = false,
    bool clearEmailTestResult = false}) => ReportesState(
      authorized: authorized, exportBusy: exportBusy ?? this.exportBusy,
      emailSaveBusy: emailSaveBusy ?? this.emailSaveBusy,
      emailTestBusy: emailTestBusy ?? this.emailTestBusy,
      emailSaveSucceeded: emailSaveSucceeded ?? this.emailSaveSucceeded,
      emailConfigState: emailConfigState ?? this.emailConfigState,
      exportState: exportState ?? this.exportState,
      emailSaveError: clearEmailSaveError ? null : (emailSaveError ?? this.emailSaveError),
      emailTestError: clearEmailTestError ? null : (emailTestError ?? this.emailTestError),
      emailTestResult: clearEmailTestResult ? null : (emailTestResult ?? this.emailTestResult));
}
class ReportesNotifier extends StateNotifier<ReportesState> {
  final ReportesRepository _repository;
  final bool authorized;
  ReportesNotifier(this._repository, {required this.authorized})
      : super(ReportesState(authorized: authorized));
  Future<void> loadEmailConfig() async {
    state = state.copyWith(emailConfigState: const OperationLoading());
    try {
      state = state.copyWith(emailConfigState: OperationContent(await _repository.getEmailConfig()));
    } catch (e) {
      state = state.copyWith(emailConfigState: OperationRecoverableError(_ex(e)));
    }
  }
  Future<void> saveEmailConfig(List<String> recipients) async {
    state = state.copyWith(emailSaveBusy: true, emailSaveSucceeded: false, clearEmailSaveError: true);
    try {
      state = state.copyWith(emailConfigState: OperationContent(await _repository.updateEmailConfig(recipients)),
          emailSaveBusy: false, emailSaveSucceeded: true);
    } catch (e) {
      state = state.copyWith(emailSaveBusy: false, emailSaveError: _ex(e));
    }
  }
  Future<void> testEmailDelivery({List<String>? recipients}) async {
    state = state.copyWith(emailTestBusy: true, clearEmailTestError: true, clearEmailTestResult: true);
    try {
      state = state.copyWith(emailTestBusy: false,
          emailTestResult: await _repository.testEmailDelivery(recipients: recipients));
    } catch (e) {
      state = state.copyWith(emailTestBusy: false, emailTestError: _ex(e));
    }
  }
  Future<void> exportReport(String tipo, {required String formato, required String fechaInicio,
      required String fechaFin, String? sedeId}) async {
    if (!authorized) {
      state = state.copyWith(exportState: OperationRecoverableError(
          const AppException(message: 'No autorizado.', statusCode: 403)));
      return;
    }
    state = state.copyWith(exportBusy: true);
    try {
      state = state.copyWith(exportBusy: false, exportState: OperationContent(
          await _repository.exportReport(tipo, formato: formato,
              fechaInicio: fechaInicio, fechaFin: fechaFin, sedeId: sedeId)));
    } catch (e) {
      state = state.copyWith(exportBusy: false, exportState: OperationRecoverableError(_ex(e)));
    }
  }
  Future<void> exportCajaReport(String cajaId, {required String formato}) async {
    if (!authorized) {
      state = state.copyWith(exportState: OperationRecoverableError(
          const AppException(message: 'No autorizado.', statusCode: 403)));
      return;
    }
    state = state.copyWith(exportBusy: true);
    try {
      state = state.copyWith(exportBusy: false, exportState: OperationContent(
          await _repository.exportCajaReport(cajaId, formato: formato)));
    } catch (e) {
      state = state.copyWith(exportBusy: false, exportState: OperationRecoverableError(_ex(e)));
    }
  }
  AppException _ex(Object e) => e is AppException ? e : AppException(message: '$e');
}
final reportesRepositoryProvider = Provider((_) => ReportesRepository(ApiClient.instance));
final reportesProvider = StateNotifierProvider.autoDispose<ReportesNotifier, ReportesState>((ref) {
  final auth = ref.watch(authProvider);
  final notifier = ReportesNotifier(ref.watch(reportesRepositoryProvider),
      authorized: auth.canAccess(RoutePaths.reportes));
  Future.microtask(notifier.loadEmailConfig);
  return notifier;
});
