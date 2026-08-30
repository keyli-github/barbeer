import 'package:barbeer/core/async/operation_state.dart';
import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/errors/app_exception.dart';
import 'package:barbeer/core/navigation/route_access_policy.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/core/routes/route_paths.dart';
import 'package:barbeer/features/reportes/data/models/reporte_models.dart';
import 'package:barbeer/features/reportes/data/reportes_repository.dart';
import 'package:barbeer/features/reportes/presentation/providers/reportes_provider.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  group('DTO mapping', () {
    test('ReporteEmailConfig maps recipients, smtpConfigured, updatedAt for full and empty', () {
      final full = ReporteEmailConfig.fromJson(
          {'recipients': ['a@b.com', 'x@y.com'], 'smtpConfigured': true, 'updatedAt': '2026-01-01'});
      expect(full.recipients, ['a@b.com', 'x@y.com']);
      expect((full.smtpConfigured, full.updatedAt), (true, '2026-01-01'));
      expect(full.toJson().keys.toSet(), {'recipients'});
      expect(full.toJson(), isNot(contains('smtpConfigured')));
      final empty = ReporteEmailConfig.fromJson(
          {'recipients': [], 'smtpConfigured': false, 'updatedAt': null});
      expect((empty.recipients.length, empty.smtpConfigured, empty.updatedAt), (0, false, null));
    });
    test('ReporteEmailTestResult maps delivered and messageId for success and null', () {
      final ok = ReporteEmailTestResult.fromJson({'delivered': true, 'messageId': 'msg-abc'});
      expect((ok.delivered, ok.messageId), (true, 'msg-abc'));
      final fail = ReporteEmailTestResult.fromJson({'delivered': false, 'messageId': null});
      expect((fail.delivered, fail.messageId), (false, null));
    });
  });
  group('repository transport', () {
    test('exportReport and exportCajaReport hit exact paths with correct query keys', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final repo = ReportesRepository(ApiClient.instance, bytesRequest: (path, q) async {
        calls.add((path, q));
        return ReporteExportado(bytes: [1], contentType: 'application/json', filename: 'r.json');
      });
      await repo.exportReport('ventas', formato: 'xlsx', fechaInicio: '2026-01-01', fechaFin: '2026-01-31', sedeId: 's1');
      await repo.exportReport('movimientos', formato: 'json', fechaInicio: '2026-02-01', fechaFin: '2026-02-28');
      await repo.exportCajaReport('caja-uuid', formato: 'json');
      expect(calls[0].$1, ApiConstants.reportExport('ventas'));
      expect(calls[0].$2, {'formato': 'xlsx', 'fechaInicio': '2026-01-01', 'fechaFin': '2026-01-31', 'sedeId': 's1'});
      expect(calls[1].$2, isNot(contains('sedeId')));
      expect(calls[1].$2.keys, unorderedEquals(['formato', 'fechaInicio', 'fechaFin']));
      expect(calls[2].$1, ApiConstants.reportCajaExport('caja-uuid'));
      expect(calls[2].$2, {'formato': 'json'});
    });
    test('email GET reads config path; PUT and POST carry exact body keys and map response', () async {
      final gets = <String>[];
      Map<String, dynamic>? putBody, postWith, postEmpty;
      final repo = ReportesRepository(ApiClient.instance,
          getRequest: (path) async { gets.add(path); return {'recipients': ['a@b.com'], 'smtpConfigured': true, 'updatedAt': null}; },
          putRequest: (_, body) async { putBody = body; return {'recipients': body['recipients'], 'smtpConfigured': false, 'updatedAt': '2026-01-02'}; },
          postRequest: (_, body) async { body.containsKey('recipients') ? postWith = body : postEmpty = body; return {'delivered': true, 'messageId': 'id-1'}; });
      final config = await repo.getEmailConfig();
      expect(gets.single, ApiConstants.reportEmailConfig);
      expect(config.recipients, ['a@b.com']);
      final updated = await repo.updateEmailConfig(['x@y.com']);
      expect(putBody!['recipients'], ['x@y.com']);
      expect(updated.recipients, ['x@y.com']);
      final r1 = await repo.testEmailDelivery(recipients: ['t@u.com']);
      final r2 = await repo.testEmailDelivery();
      expect(postWith, {'recipients': ['t@u.com']});
      expect(postEmpty, isEmpty);
      expect((r1.delivered, r1.messageId, r2.delivered), (true, 'id-1', true));
    });
    test('403 on export and 500 on email test propagate as typed AppException', () async {
      await expectLater(
        ReportesRepository(ApiClient.instance,
            bytesRequest: (_, __) async => throw const AppException(message: 'No autorizado.', statusCode: 403))
            .exportReport('ventas', formato: 'xlsx', fechaInicio: '2026-01-01', fechaFin: '2026-01-31'),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 403)));
      await expectLater(
        ReportesRepository(ApiClient.instance,
            postRequest: (_, __) async => throw const AppException(message: 'SMTP error', statusCode: 500))
            .testEmailDelivery(),
        throwsA(isA<AppException>().having((e) => e.statusCode, 'statusCode', 500)));
    });
  });
  group('authorization and states', () {
    test('SUPERADMIN may access reportes; ADMIN and VENDEDORA are denied', () {
      expect(RouteAccessPolicy.canAccess(RoutePaths.reportes, role: 'SUPERADMIN', permissions: const {}), isTrue);
      expect(RouteAccessPolicy.canAccess(RoutePaths.reportes, role: 'ADMIN', permissions: const {}), isFalse);
      expect(RouteAccessPolicy.canAccess(RoutePaths.reportes, role: 'VENDEDORA', permissions: const {}), isFalse);
    });
    test('email config loads into OperationContent; save replaces it and marks succeeded', () async {
      Map<String, dynamic>? putBody;
      final repo = ReportesRepository(ApiClient.instance,
          getRequest: (_) async => {'recipients': ['a@b.com'], 'smtpConfigured': true, 'updatedAt': null},
          putRequest: (_, body) async { putBody = body; return {'recipients': ['x@y.com'], 'smtpConfigured': false, 'updatedAt': '2026-01-02'}; });
      final notifier = ReportesNotifier(repo, authorized: true);
      await notifier.loadEmailConfig();
      final loaded = notifier.state.emailConfigState as OperationContent<ReporteEmailConfig>;
      expect(loaded.data.recipients, ['a@b.com']);
      expect(loaded.data.smtpConfigured, isTrue);
      await notifier.saveEmailConfig(['x@y.com']);
      expect(putBody, {'recipients': ['x@y.com']});
      expect(notifier.state.emailSaveSucceeded, isTrue);
      expect((notifier.state.emailConfigState as OperationContent<ReporteEmailConfig>).data.recipients, ['x@y.com']);
    });
    test('email test success shows result; failed test exposes error without altering saved recipients', () async {
      final repo = ReportesRepository(ApiClient.instance,
          getRequest: (_) async => {'recipients': ['saved@b.com'], 'smtpConfigured': true, 'updatedAt': null},
          postRequest: (_, __) async => {'delivered': true, 'messageId': 'msg-z'});
      final notifier = ReportesNotifier(repo, authorized: true);
      await notifier.loadEmailConfig();
      await notifier.testEmailDelivery(recipients: ['test@t.com']);
      expect((notifier.state.emailTestResult?.delivered, notifier.state.emailTestResult?.messageId), (true, 'msg-z'));
      expect((notifier.state.emailConfigState as OperationContent<ReporteEmailConfig>).data.recipients, ['saved@b.com']);
      final failRepo = ReportesRepository(ApiClient.instance,
          getRequest: (_) async => {'recipients': ['a@b.com'], 'smtpConfigured': true, 'updatedAt': null},
          postRequest: (_, __) async => throw const AppException(message: 'SMTP fail', statusCode: 503));
      final failNotifier = ReportesNotifier(failRepo, authorized: true);
      await failNotifier.loadEmailConfig();
      await failNotifier.testEmailDelivery();
      expect(failNotifier.state.emailTestError?.statusCode, 503);
      expect((failNotifier.state.emailConfigState as OperationContent<ReporteEmailConfig>).data.recipients, ['a@b.com']);
    });
    test('denied export returns 403 without calling bytes bridge; bad dates give retryable error', () async {
      var bridgeCalled = false;
      final denied = ReportesNotifier(ReportesRepository(ApiClient.instance,
          bytesRequest: (_, __) async { bridgeCalled = true; return ReporteExportado(bytes: [], contentType: '', filename: ''); }),
          authorized: false);
      await denied.exportReport('ventas', formato: 'xlsx', fechaInicio: '2026-01-01', fechaFin: '2026-01-31');
      expect(bridgeCalled, isFalse);
      expect((denied.state.exportState as OperationRecoverableError<ReporteExportado>).error.statusCode, 403);
      final authorized = ReportesNotifier(ReportesRepository(ApiClient.instance,
          bytesRequest: (_, __) async => throw const AppException(message: 'Fechas invalidas', statusCode: 400)),
          authorized: true);
      await authorized.exportReport('ventas', formato: 'xlsx', fechaInicio: '2026-12-31', fechaFin: '2026-01-01');
      expect(authorized.state.exportBusy, isFalse);
      expect((authorized.state.exportState as OperationRecoverableError<ReporteExportado>).error.statusCode, 400);
    });
  });
}
