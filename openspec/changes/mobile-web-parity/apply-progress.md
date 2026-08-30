# Apply Progress: Mobile-Web Parity

**Status**: Active tasks 2.1, 2.2, 3.1a, 3.1b, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, and 4.3 are complete (12/14). The former backend WU1 remains reverted and the protected Flutter baseline remains intact.
**Mode**: Strict TDD
**Delivery**: WU10 is an autonomous `stacked-to-main` reports/email slice at 347/400 authored lines; no branch or delivery operation was performed.

## Completed Active Tasks
- [x] 2.1 Added exact Dio error normalization and five distinct shared operation states under Strict TDD.
- [x] 2.2 Added centralized role/effective-permission access rules, splash-safe deep-link guards, unknown-route denial, and a state-preserving 403 authorization-refresh seam under Strict TDD.
- [x] 3.1a Added exact Recargo control/configuration contracts, typed assignments, state-preserving authorization failures, and the authorized configuration/toggle control under Strict TDD.
- [x] 3.1b Added confidential sale draft, payload, history, detail, and sheet behavior while retaining only authoritative totals under Strict TDD.
- [x] 3.2 Added exact scoped account list/detail reads, local pagination, deterministic read states, route/navigation exposure, and list/detail latest-request-wins protection under Strict TDD.
- [x] 3.3 Added exact account-payment DTO/response mapping, role/permission gating, authoritative partial/full updates, deterministic mutation state, stale-response protection, and body-key idempotency under Strict TDD.
- [x] 3.4 Added exact account selector endpoint, esPersonal mapping, charged-sale payload with cuentaId/cuentaMonto, sale response parsing of cuentaId/cuenta/cuentaMonto, and annulled-sale state preservation under Strict TDD.
- [x] 3.5 Added exact permission exception DTO mapping (CatalogPermission, EffectivePermission, UsuarioPermisosResponse), atomic PUT replacement with ReplacePermissionsPayload, SUPERADMIN-only mutation gating, 400/403 error preservation, and effective-permission semantics under Strict TDD.
- [x] 3.6 Added exact PIN lifecycle DTOs (PinConfigPayload, PinValidationResult), stock authorization DTOs (StockAdjustPayload, StockAdjustResult), repository methods (configureSuperadminPin, validatePin, adjustStock), API constants (superadminPin, validatePin, productStock), 429 throttle surface, and 403/400 stock error preservation under Strict TDD.
- [x] 4.1 RED: `test/core/files/file_artifact_service_test.dart` — 19 tests covering: extension allowlist (xlsx/json/txt), executable-extension rejection (.sh, .md, .mdx), blocked-filename rejection (requirements.txt, CMakeLists.txt), path-separator rejection, content-type mismatch, Android/Windows platform bridge dispatch (save allowed, save cancelled, save blocked), and Android/Windows platform harness (save+open JSON, .sh rejected, save+open XLSX). Exit 1, 0 tests loaded at RED.
- [x] 4.2 GREEN→REFACTOR WU9: `lib/core/files/file_artifact.dart` (FileArtifact, 7 sealed FileArtifactResult subtypes), `lib/core/files/file_artifact_service.dart` (FileArtifactService abstract class, validateArtifact pure function, kAllowedFileExtensions, blocked filenames, MIME map, mimeTypeForFilename), `lib/core/files/android_file_artifact_service.dart` (MethodChannel bridge, FilePicker SAF save, callback injection), `lib/core/files/windows_file_artifact_service.dart` (FilePicker save dialog, Process.run open, callback injection), `android/app/src/main/kotlin/com/barbeer/barbeer/MainActivity.kt` (openFile MethodChannel handler for Android intent). 19/19 focused tests → exit 0 GREEN. Full suite 209/209 → exit 0.
- [x] 4.3 GREEN→REFACTOR WU10: `lib/features/reportes/data/models/reporte_models.dart` (ReporteExportado, ReporteEmailConfig with fromJson/toJson, ReporteEmailTestResult), `lib/features/reportes/data/reportes_repository.dart` (5 methods: exportReport/exportCajaReport/getEmailConfig/updateEmailConfig/testEmailDelivery, callback injection for all transports), `lib/features/reportes/presentation/providers/reportes_provider.dart` (ReportesState, ReportesNotifier, reportesRepositoryProvider, reportesProvider), `lib/features/reportes/presentation/screens/reportes_screen.dart` (minimal shell), plus: ApiConstants report constants (reportExport/reportCajaExport/reportEmailConfig/reportEmailTest), ApiClient.getBytes(Uint8List, ResponseType.bytes), app_router.dart GoRoute for /reportes, app_destinations.dart Reportes destination. 9/9 focused tests → exit 0. Full suite 218/218 → exit 0.

## WU9 Platform File Handling (retained from prior batch)

WU9 implements a secure FileArtifactService for Android and Windows. The pure `validateArtifact` function enforces the extension allowlist (xlsx, json, txt), rejects blocked build-system filenames (requirements.txt, CMakeLists.txt), rejects path separators and control characters, and rejects content-type mismatches. Android uses file_picker SAF save + MethodChannel openFile intent. Windows uses file_picker save dialog + Process.run cmd start. Callback injection (saveBridge/openBridge) makes all platform paths fully testable in unit tests without platform setup.

## WU10 Reports/Email Completion

WU10 implements the full reports and email parity slice. `ReportesRepository` accepts callback injection for all four transport types (bytesRequest, getRequest, putRequest, postRequest), making it fully unit-testable. `ReportesNotifier` exposes five state operations: `loadEmailConfig`, `saveEmailConfig`, `testEmailDelivery`, `exportReport`, and the authorization gate (no bridge call when `authorized: false`). `RouteAccessPolicy` already had `RoutePaths.reportes: RouteAccessRule.role({'SUPERADMIN'})` — confirmed passing in tests. `app_destinations.dart` now includes the Reportes destination with empty permissions (role-only gating). `ApiClient.getBytes` added for binary report downloads via `ResponseType.bytes`.

### Work Unit Evidence (WU10)

| Evidence | Result |
|---|---|
| Safety net | Before RED, `flutter test test/core/navigation/route_access_policy_test.dart` → exit 0, 3/3 passed. |
| Focused RED | `flutter test test/features/reportes/reportes_test.dart` → exit 1, compilation errors: all types (ReporteExportado, ReporteEmailConfig, ReporteEmailTestResult, ReportesRepository, ReportesNotifier, ApiConstants.reportExport/reportEmailConfig/reportEmailTest) not found. |
| Focused GREEN | Same focused command → exit 0, 9/9 passed after compact implementation. |
| Runtime harness | Report generation mocked harness: authorized=false → bridge not called, exportState carries 403; authorized=true with bad dates → exportBusy=false, exportState carries 400 error. Email delivery mocked harness: testEmailResult.delivered=true, messageId='msg-z', saved recipients ['saved@b.com'] unchanged after test call. Native attempt token sha256:62eb5765e87c032469dbb0ee8deb26b59ed3273765f375c0d74559da1f54c145 was not acquired, settled, reset, or mutated and remains for orchestrator settlement. |
| Affected tests | `flutter test test/features/reportes/reportes_test.dart test/core/navigation/route_access_policy_test.dart test/core/files/file_artifact_service_test.dart test/features/usuarios/usuario_authorization_test.dart` → exit 0, 55/55. |
| Full test | Final `flutter test` executed exactly once → exit 0, 218/218 passed. Existing non-fatal LF→CRLF warnings remained. |
| Rollback boundary | Remove only `lib/features/reportes/` (5 files) and `test/features/reportes/reportes_test.dart`; revert 4 modified files to pre-WU10 state: remove report constants from api_constants.dart, remove getBytes+import from api_client.dart, remove /reportes GoRoute+import from app_router.dart, remove Reportes AppDestination from app_destinations.dart. Preserve every WU1–WU9 line. |
| Authored line count | 347 additions+deletions: new files (135+26+50+91+9=311) + modified files (api_constants.dart+7, api_client.dart+16, app_router.dart+5, app_destinations.dart+8 = 36). 53 lines below the 400 cap. |
| Diff/format hygiene | `git diff --check` → exit 0 (LF→CRLF warnings only, pre-existing). |
| pubspec.yaml | No changes needed. `dart:typed_data` is stdlib. All imports resolve with existing dependencies. |
| Backend limitations | None. All four report endpoints match spec exactly. No backend changes required. |

## TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.5 | `usuario_authorization_test.dart --plain-name permission` | Unit | 63/63 passed before RED | Exit 1, 0 tests loaded: missing models, repository, DTO types, and API constant | 9/9 passed | DTO inherited/granted/revoked/inactive; payload with/without revocations; transport GET/PUT exact paths; 403+400 errors; effective-permission formula; harness create→replace→delete | No refactor needed; 277 authored lines within cap |
| 3.6 | `usuario_authorization_test.dart --plain-name PIN` | Unit | 9/9 permission tests passed before RED | Exit 1, compilation errors: 10 missing types/constants/methods | 14/14 passed | PinConfig manual/auto; PinValidation success/failure; StockPayload full/minimal; StockResult parsing; API constants 3 paths; repo PATCH/POST/429/403/400; harness: wrong→correct→stock→throttle | No refactor needed; 240 authored lines within cap |
| 4.1 | `test/core/files/file_artifact_service_test.dart` | Unit | N/A (new file) | Exit 1, 0 tests loaded: 4 missing source files, all types absent | N/A before GREEN | N/A before GREEN | N/A before GREEN |
| 4.2 | `test/core/files/file_artifact_service_test.dart` | Unit | N/A (new files) | See 4.1 RED above | 19/19 passed | validateArtifact: 3 allowed + 7 rejected; Android: allowed/cancelled/blocked; Windows: allowed/cancelled/blocked; harness: Android JSON+open, Android .sh rejected, Windows XLSX+open | No refactor needed; 351 authored lines within cap |
| 4.3 | `test/features/reportes/reportes_test.dart` | Unit | N/A (new files) | Exit 1, 0 tests loaded: all types not found | 9/9 passed | ReporteEmailConfig: full/empty + toJson; ReporteEmailTestResult: success/null; exportReport with/without sedeId; email PUT body; POST with/without recipients; auth: SUPERADMIN/ADMIN/VENDEDORA; export authorized/denied/error; email load+save+test+fail | Compacted to cuentas-pattern style; 347 authored lines within cap |

Historical test summary: WU1 wrote 2; WU2 wrote 5; WU3 added 3; WU3a continued 3; WU3b expanded 2; WU4 wrote 3; WU5 wrote 3; WU6 wrote 7; WU7 wrote 9; WU8 wrote 14; WU9 wrote 19; WU10 wrote 9. Current Flutter suite: 218/218 passed.

## Remaining
Tasks 4.4 and 4.5 remain pending. Twelve of 14 active tasks complete. WU11 (backups) is the next autonomous slice.
