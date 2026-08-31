# Apply Progress: Mobile-Web Parity

**Status**: All active tasks are complete (14/14); focused remediations #1–#8 applied. Baseline 309 → 320 → 327 tests.
**Mode**: Strict TDD
**Delivery**: Autonomous `stacked-to-main` remediation slices; no branch or delivery operation was performed.

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
- [x] 4.4 WU11 added exact backup schedule/history contracts, SHA-256 verified downloads, and permission-gated route wiring; 12/12 focused and 230/230 full tests passed.
- [x] 4.5 WU12 added parity route/destination closure evidence; focused tests and the 237/237 full suite passed.

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

Historical test summary: WU1 wrote 2; WU2 wrote 5; WU3 added 3; WU3a continued 3; WU3b expanded 2; WU4 wrote 3; WU5 wrote 3; WU6 wrote 7; WU7 wrote 9; WU8 wrote 14; WU9 wrote 19; WU10 wrote 9; Remediation#5 wrote 9. Current Flutter suite: 277/277 passed.

## Focused Remediation: Account Creation and Charged Sales

Production Cobros now creates exact backend accounts with permission, validation, loading, conflict/error, success, and refresh behavior. Nueva Venta now drives the real selector through loading/empty/retry, supports `Cargar diferencia a cuenta`, sends authoritative `cuentaId`/`cuentaMonto`, preserves rejected drafts, and uses the same semantics on compact mobile and wide desktop layouts. Selector access is hidden without `cuentas:crear` or `ventas:crear`.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Focused remediation | `cuentas_test.dart`; `nueva_venta_view_test.dart` | Widget/integration | 20/20 passed before new RED | Unauthorized selector action test exited 1 because production rendered the action | Permission gate test 1/1 passed | Exact account-form labels, duplicate 409, invalid 400, busy/success/refresh; authorized desktop and mobile; loading/empty/retry; exact charge payload and rejected-draft preservation | Permission gate kept transport unreachable; focused 21/21 and full 246/246 passed |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/cuentas/cuentas_test.dart test/features/ventas/nueva_venta_view_test.dart` → exit 0, 21/21 passed. |
| Runtime harness | Production widget/repository account form and charged-sale rejection scenarios → exit 0, 1/1 each; exact POST bodies and retained cart/account state asserted. |
| Affected/full | `flutter test test/features/cuentas test/features/ventas` → 59/59; `flutter test` → 246/246, both exit 0. |
| Rollback boundary | Revert only the account create repository/notifier/screen/model hunks, `cuenta_selector.dart`, Nueva Venta account hunks, and the two focused test hunks; retain all unrelated parity work. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:d309e2a837c154b5ed2d6e76f8e5ffa270f3c3764b120eab388aa6eece9c220d
lineage_id: ""
generation: 0
fix_batch: 0
focused_tests: passed
runtime_harness: passed
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:d309e2a837c154b5ed2d6e76f8e5ffa270f3c3764b120eab388aa6eece9c220d","lineage_id":"","generation":0,"fix_batch":0,"commands":[{"command":"flutter test test/features/cuentas/cuentas_test.dart test/features/ventas/nueva_venta_view_test.dart","exit_code":0,"result":"21 of 21 focused tests passed"},{"command":"flutter test test/features/cuentas test/features/ventas","exit_code":0,"result":"59 of 59 affected tests passed"},{"command":"flutter test","exit_code":0,"result":"246 of 246 tests passed"}],"runtime_harness":{"status":"passed","command":"flutter test test/features/cuentas/cuentas_test.dart --plain-name production account form; flutter test test/features/ventas/nueva_venta_view_test.dart --plain-name charged-sale selector","result":"Both production widget and repository scenarios passed with exact backend bodies and rejected draft retention","na_reason":""},"rollback":{"boundary":"Account create repository notifier screen model widget, Nueva Venta account integration, and their two focused test files","evidence":"Reverting only those paths removes this remediation without removing unrelated parity work"}}
```

## Focused Remediation: Wallet/Refresh/Annulment Charged-Sale Parity

Fixed `_DesktopCartPanel` layout overflow when wallet+receipt+account+error show simultaneously. Wrapping the bottom section in `Flexible` and assigning `flex: 3` to the items list prevents content from starving the cart items area. Added two production behavior tests: (1) post-success partial refresh confirms sale result renders with account detail and stock-refresh warning without retrying the sale, (2) wallet 400 rejection confirms billetera payment selection, receipt analysis panel, account charge, cart items, and error message+code are all preserved after backend rejection.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Wallet/refresh/annulment | `nueva_venta_view_test.dart` | Widget | 54/54 passed before new RED | Wallet rejection test exited 1 — RenderFlex overflow starved items list, cart item key not found | Layout fix (`Flexible` + `flex: 3`) → 56/56 focused and 250/250 full passed | Post-success partial refresh with account result; wallet rejection with billetera+receipt+account+cart preservation | No refactor needed; minimal production fix |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/ventas/nueva_venta_view_test.dart test/features/ventas/ventas_test.dart` → exit 0, 56/56 passed. |
| Runtime harness | Production widget wallet+receipt+account rejection scenario with exact 400 error+code rendering, cart/state preservation → exit 0; post-success partial refresh with stock warning → exit 0. |
| Affected/full | `flutter test test/features/ventas` → 56/56; `flutter test` → 250/250, both exit 0. |
| Rollback boundary | Revert only the `Flexible`/`flex: 3` hunks in `_DesktopCartPanel`, the `_WalletRejectedRepository` class, the two new `testWidgets` blocks, and the 4 `ensureVisible` lines added to the existing wallet test; retain all prior remediation and parity work. |
| Authored line count | ~196 additions+deletions: production fix (5 lines in nueva_venta_view.dart) + tests (191 lines in nueva_venta_view_test.dart). Within 400-line cap. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4
lineage_id: ""
generation: 0
fix_batch: 1
focused_tests: passed
runtime_harness: passed
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4","lineage_id":"","generation":0,"fix_batch":1,"commands":[{"command":"flutter test test/features/ventas/nueva_venta_view_test.dart test/features/ventas/ventas_test.dart","exit_code":0,"result":"56 of 56 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"250 of 250 tests passed"}],"runtime_harness":{"status":"passed","command":"flutter test test/features/ventas/nueva_venta_view_test.dart --plain-name 'post-success partial refresh'; flutter test test/features/ventas/nueva_venta_view_test.dart --plain-name 'wallet 400 rejection'","result":"Both new tests exercise production NuevaVentaView widget through submit, rejection, and refresh paths","na_reason":""},"rollback":{"boundary":"Flexible wrapper and flex:3 in _DesktopCartPanel, _WalletRejectedRepository class, two new testWidgets, and ensureVisible additions to existing wallet test","evidence":"Reverting only those hunks removes this remediation without removing prior parity or account-creation work"}}
```

## Focused Remediation: Permission Editor and PIN-Stock Integration

Production Usuarios now exposes a SUPERADMIN-only `PermissionEditorSheet` for any user: loads effective permissions grouped by module (GET), renders inherited/granted/revoked states, toggles individual permission overrides, module-level bulk toggle, and atomic PUT replacement with loading/403/404 error states. Inventario now uses `PinStockAdjustSheet` with `validatePin` before `adjustStock`: handles 429 throttle, incorrect PIN, and success flows. Stock quantity only changes after backend confirmation.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Permission editor | `usuario_authorization_test.dart` | Widget | 23/23 before RED | Exit 1, 0 loaded: missing `PermissionEditorSheet`, `PinStockAdjustSheet` | 31/31 passed | Load+group; toggle individual; module bulk toggle; 403 error; 404 error | Compressed 414→239 new lines; 258/258 full |
| PIN stock adjust | `usuario_authorization_test.dart` | Widget | Same 23/23 | Same RED above | Same 31/31 | Valid PIN→success; wrong PIN→error; 429 throttle | Same refactor pass |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/usuarios/usuario_authorization_test.dart` → exit 0, 31/31 passed |
| Full suite | `flutter test` → exit 0, 258/258 passed |
| Rollback boundary | Remove `permission_editor_sheet.dart`, `pin_stock_adjust_sheet.dart`; revert `_PinAdjustWrapper` and import in `inventario_screen.dart`; revert `_showPermissions`, import, and `onEditPermissions` in `usuarios_screen.dart`; revert 8 new tests and 4 import lines in `usuario_authorization_test.dart`. Retain all prior remediation and parity work. |
| Authored lines | 498 authored changed lines (497 additions + 1 deletion: 239 new-file additions + 258 existing-file additions + 1 existing-file deletion). Within 800-line budget; exceeds 400 preferred because two complete production widgets + 8 widget tests. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4
lineage_id: ""
generation: 0
fix_batch: 2
focused_tests: passed
runtime_harness: passed
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4","lineage_id":"","generation":0,"fix_batch":2,"commands":[{"command":"flutter test test/features/usuarios/usuario_authorization_test.dart","exit_code":0,"result":"31 of 31 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"258 of 258 tests passed"}],"runtime_harness":{"status":"passed","command":"flutter test test/features/usuarios/usuario_authorization_test.dart --plain-name 'permission editor widget'; flutter test test/features/usuarios/usuario_authorization_test.dart --plain-name 'PIN stock widget'","result":"Permission editor loads/groups/toggles/errors through production widget; PIN stock validates then adjusts through production widget","na_reason":""},"rollback":{"boundary":"permission_editor_sheet.dart, pin_stock_adjust_sheet.dart, _PinAdjustWrapper in inventario_screen, _showPermissions and onEditPermissions in usuarios_screen, 8 new tests in usuario_authorization_test","evidence":"Reverting only those paths removes this remediation without removing prior parity or account-creation or wallet/refresh work"}}
```

## Focused Remediation #4: Caja Movement Semantics and Dashboard Audit Parity

### Blocker 7: Caja movement semantics
**Problem**: Flutter required `concepto` even when an `etiqueta` (label) was selected, and derived staff requirement from label direction instead of backend `personalTipo`.
**Fix**: (1) Made `concepto` optional in `cajaMovimientoPayload` — omitted when empty and etiquetaId is present, matching the web's OR-validation. (2) Added `personalTipo` field to both Etiqueta models (etiquetas module + ventas module). (3) Replaced `_requierePersonal` direction-based check with `cajaRequiresStaff(personalTipo:)`. (4) Updated form validator to accept concepto OR etiqueta.

### Blocker 8: Dashboard recent activity
**Problem**: Provider fetched `limite: 6` but UI showed "Ver todo" only when `audit.length > 8` — link was unreachable.
**Fix**: (1) Extracted `dashboardAuditLimit = 8` constant matching web parity. (2) Changed fetch limit from 6 to 8. (3) Changed "Ver todo" condition from `audit.length > 8` to `audit.isNotEmpty`, matching the web's unconditional display. (4) Renamed `_Activity` to public `DashboardRecentActivity` for testability.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Caja concepto optional | `caja_test.dart` | Unit | 258/258 | Exit 1, nullable param missing | 268/268 | null, empty, trimmed, with+without etiquetaId (4 cases) | N/A — clean |
| Etiqueta personalTipo | `caja_test.dart` | Unit | Same | Same RED | Same GREEN | present CARGO + absent null (2 cases) | N/A |
| cajaRequiresStaff | `caja_test.dart` | Unit | Same | Same RED | Same GREEN | CARGO, PAGO, null, default (4 cases) | N/A |
| Dashboard audit limit | `dashboard_test.dart` | Unit+Widget | Same | Same RED | Same GREEN | constant=8, 6 items, 1 item (3 cases) | N/A |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/caja/caja_test.dart test/features/dashboard/dashboard_test.dart` → exit 0, 42/42 |
| Full suite | `flutter test` → exit 0, 268/268 |
| Rollback boundary | Revert `personalTipo` from both Etiqueta models (`etiqueta.dart` + `venta_models.dart`); restore `concepto` as `required String` in `cajaMovimientoPayload`, `registrarMovimiento` (provider+repository); restore `_requierePersonal` direction logic in `caja_screen.dart`; restore validator text; restore `limite: 6` and `audit.length > 8` in dashboard; rename `DashboardRecentActivity` back to `_Activity`; remove 10 new tests from test files. |
| Authored lines | ~140 authored changed lines. Within 250-line target. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4
lineage_id: ""
generation: 0
fix_batch: 3
focused_tests: passed
runtime_harness: passed
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4","lineage_id":"","generation":0,"fix_batch":3,"commands":[{"command":"flutter test test/features/caja/caja_test.dart test/features/dashboard/dashboard_test.dart","exit_code":0,"result":"42 of 42 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"268 of 268 tests passed"}],"runtime_harness":{"status":"passed","command":"flutter test test/features/caja/caja_test.dart --plain-name 'Blocker 7'; flutter test test/features/dashboard/dashboard_test.dart --plain-name 'Blocker 8'","result":"Concepto optional when etiquetaId present; personalTipo parsed and used for staff; audit limit=8; Ver todo always visible","na_reason":""},"rollback":{"boundary":"personalTipo in etiqueta.dart+venta_models.dart; concepto nullable in caja_repository+caja_provider; _requierePersonal in caja_screen; validator text in caja_screen; limite+condition in dashboard_provider+dashboard_screen; DashboardRecentActivity rename; 10 new tests in caja_test+dashboard_test","evidence":"Reverting only those paths removes this remediation without removing prior parity or account/wallet/permission work"}}
```

## Focused Remediation #5: Report Downloads Contract-Invalid and Backup Partial States

### Blocker 5: Report downloads contract-invalid
**Problem**: `reportes_repository.dart` fabricated `contentType: 'application/octet-stream'` and `filename: 'reporte.$formato'` in the production path, discarding server `Content-Disposition` and `Content-Type` headers. The `validateArtifact` function rejects `application/octet-stream` for `.xlsx` files, making report downloads fail the MIME contract. `exportCajaReport` existed in the repository but had no notifier method — unreachable from the UI layer.
**Fix**: (1) Created `lib/core/network/http_header_utils.dart` with `parseContentDispositionFilename` pure function and `HttpBytesResponse` class. (2) Added `ApiClient.getBytesResponse()` that returns headers alongside bytes. (3) Updated both `exportReport` and `exportCajaReport` production paths to use server-provided filename and content-type, with `mimeTypeForFilename` fallback. (4) Added `ReportesNotifier.exportCajaReport()` with authorization gate.

### Blocker 6: Backup metadata and partial states
**Problem**: `respaldos_repository.dart` `downloadArtifact` returned raw `Uint8List`; `respaldos_screen.dart` fabricated filename and content-type from hardcoded mappings. `_State.error` was a single field — schedule and history errors overwrote each other with no section-specific retry.
**Fix**: (1) Changed `downloadArtifact` return type to `BackupDownloadResult` (bytes + filename + contentType). Production path parses server headers via `getBytesResponse`; test seam uses `mimeTypeForFilename` fallback. (2) Split `_State.error` into `scheduleError`/`runsError` with independent clearing in `loadAll()`/`refreshRuns()`. (3) Added error + retry UI to both `_ScheduleCard` and `_HistoryCard`.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| parseContentDispositionFilename | `reportes_test.dart` | Unit | 268/268 | Stub returns null → quoted/unquoted assertions fail | Regex impl → 16/16 | quoted, unquoted, null, empty, no-filename (5 cases) | N/A — clean |
| Artifact MIME validation | `reportes_test.dart` | Unit | Same | N/A — passes immediately (proves the existing bug) | Same | server MIME valid vs fabricated octet-stream invalid (2 cases) | N/A |
| exportCajaReport | `reportes_test.dart` | Unit | Same | Stub does nothing → state stays null | Notifier impl → 16/16 | authorized+success, unauthorized+403 (2 cases) | N/A |
| BackupDownloadResult | `respaldos_test.dart` | Unit | Same | Old return type → .bytes/.filename fail | New type → 14/14 | JSON + XLSX MIMEs, short/long runIds (3 cases) | Safe substring for short IDs |
| Independent error isolation | `respaldos_test.dart` | Unit | Same | N/A — already independent at repo level | Same | schedule-down + runs-ok; runs-down + schedule-ok (2 cases) | N/A |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/reportes/reportes_test.dart test/features/respaldos/respaldos_test.dart` → exit 0, 30/30 |
| Full suite | `flutter test` → exit 0, 277/277 |
| Rollback boundary | Revert `lib/core/network/http_header_utils.dart` (delete); revert `getBytesResponse` from `api_client.dart`; revert `reportes_repository.dart` to `getBytes` + fabricated values; remove `exportCajaReport` from `reportes_provider.dart`; remove `BackupDownloadResult` from `respaldo_models.dart`; revert `respaldos_repository.dart` to return `Uint8List`; revert `respaldos_screen.dart` error split + download metadata; revert 9 new/changed tests. |
| Authored lines | ~256 authored changed lines (production ~150 + tests ~106). Within 400-line hard max. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4
lineage_id: ""
generation: 0
fix_batch: 4
focused_tests: passed
runtime_harness: passed
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4","lineage_id":"","generation":0,"fix_batch":4,"commands":[{"command":"flutter test test/features/reportes/reportes_test.dart test/features/respaldos/respaldos_test.dart","exit_code":0,"result":"30 of 30 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"277 of 277 tests passed"}],"runtime_harness":{"status":"passed","command":"flutter test test/features/reportes/reportes_test.dart --plain-name 'parseContentDispositionFilename'; flutter test test/features/reportes/reportes_test.dart --plain-name 'caja export'; flutter test test/features/respaldos/respaldos_test.dart --plain-name 'downloadArtifact returns result'","result":"Content-Disposition parsing extracts quoted/unquoted filenames; caja export authorized+unauthorized; backup download returns metadata with correct MIME","na_reason":""},"rollback":{"boundary":"http_header_utils.dart (delete), getBytesResponse in api_client, server-header parsing in reportes_repository, exportCajaReport in reportes_provider, BackupDownloadResult in respaldo_models, downloadArtifact return type in respaldos_repository, error split+download metadata in respaldos_screen, 9 new/changed tests","evidence":"Reverting only those paths removes this remediation without removing prior parity or caja/dashboard/permission/account/wallet work"}}
```

## Focused Remediation #6: Normative Current-Module Parity Matrix

### Blocker 6 (verify-report Blocker 1): Unproved module parity matrix
**Problem**: Products/categories, inventory/Kardex, purchases/providers, attendance/QR/shifts, sucursales lacked any passing test covering authorization rules, backend contract field names, or module-specific parsing. The spec requires a normative matrix with evidence per module.
**Fix**: Added 32 focused proof tests across 5 test files proving: (1) production `fromJson` correctly maps all declared backend field names; (2) production `RouteAccessPolicy.canAccess` returns the correct allow/deny for each module's permission string; (3) derived properties (`cruzaMedianoche`, `horaInicioLabel`) compute correctly from backend data.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Inventario+Kardex matrix | `inventario_test.dart` | Unit | 277/277 before | Test file absent (0 tests) → no coverage for contract or auth | 22/22 focused → exit 0 | ALERTA + CRITICO estados; inventory permission grant/deny; kardex grant/deny | N/A — pre-existing production code |
| Asistencia+QR+Turnos matrix | `asistencia_test.dart` | Unit | Same | Test file absent (0 tests) | Same focused run | Turno day/night shift + cruzaMedianoche; absent sede fields; ENTRADA+SALIDA marcaje; full resumen sum | N/A |
| Sucursales matrix | `sucursales_test.dart` | Unit | Same | Test file absent (0 tests) | Same focused run | establecimientos:leer grant; establecimientos:gestionar alone denies; no permission denies | N/A |
| Categorias+Productos matrix | `producto_test.dart` | Unit | Same | Pre-existing 4 tests, no auth/category tests | 47/47 focused → exit 0 | inactive category; SUPERADMIN both routes; VENDEDORA denied both | N/A |
| Compras+Proveedor matrix | `compras_test.dart` | Unit | Same | Pre-existing 9 tests, no auth tests | Same focused run | nested proveedor as string; absent estado defaults; ALMACENERO grant; CAJERO denied | N/A |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Focused test | `flutter test test/features/inventario/inventario_test.dart test/features/asistencia/asistencia_test.dart test/features/sucursales/sucursales_test.dart test/features/productos/producto_test.dart test/features/compras/compras_test.dart` → exit 0, 47/47 passed |
| Full suite | `flutter test` → exit 0, 309/309 passed |
| Runtime harness | N/A — all tests are pure unit/model/auth tests with no widget or HTTP boundary |
| Rollback boundary | Delete `test/features/inventario/inventario_test.dart`, `test/features/asistencia/asistencia_test.dart`, `test/features/sucursales/sucursales_test.dart`; revert imports and new groups in `producto_test.dart` and `compras_test.dart`. No production code changed. |
| Authored lines | 565 (167 + 207 + 60 + 70 + 61). Within 800-line budget. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4
lineage_id: ""
generation: 0
fix_batch: 5
focused_tests: passed
runtime_harness: N/A
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:86ecdcf2f7154b942eafbca770314b51db7152e33402525efd831ba47908c4b4","lineage_id":"","generation":0,"fix_batch":5,"commands":[{"command":"flutter test test/features/inventario/inventario_test.dart test/features/asistencia/asistencia_test.dart test/features/sucursales/sucursales_test.dart test/features/productos/producto_test.dart test/features/compras/compras_test.dart","exit_code":0,"result":"47 of 47 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"309 of 309 tests passed"}],"runtime_harness":{"status":"N/A","command":"","result":"","na_reason":"All tests are pure unit/model/auth tests. No widget render, HTTP call, or platform boundary exists in this work unit."},"rollback":{"boundary":"Delete inventario_test.dart, asistencia_test.dart, sucursales_test.dart; revert import+group additions in producto_test.dart and compras_test.dart","evidence":"No production code was changed; reverting only these test files/hunks removes this remediation without affecting prior work"}}
```

## Focused Remediation #7: Annulment coverage, PIN lifecycle, Caja export, TDD trivial replacements

### Sub-Blocker A: Annulment recargo+reversal (Scenarios 14 and 29)
**Scenario 14**: Added `ventaHasVisibleRecargo(Venta v)` pure function to `venta_models.dart`. Returns `false` when `isAnulada`, preventing recargo exposure on annulled sales. Tests: annulled+active+no-recargo (3 cases).
**Scenario 29**: Tests prove `ApiConstants.anularVenta(id)` uses the canonical `/ventas/{id}/anular` endpoint and that annulled charged-sale responses preserve `cuentaId`/`cuentaMonto` for reversal audit.

### Sub-Blocker B: PIN lifecycle coverage (Scenarios 35 and 36)
**Scenario 36**: Widget test proves that when `validatePin` returns `success:false`, the error message "PIN incorrecto. Intenta de nuevo." does NOT contain the entered PIN digits in any `Text` widget.
**Scenario 35**: 2 widget tests for `PinManagementSheet` (via `showPinManagementSheet`): happy path renders title+usernames+roles; search input filters users by username.

### Sub-Blocker C: Caja export screen caller (Scenarios 43 and 44)
**Scenario 43**: Unit test proves `ReportesNotifier.exportCajaReport` calls `ApiConstants.reportCajaExport(sessionId)` when authorized; unauthorized call returns 403 without transport.
**Scenario 44**: Minimum wiring added to `_DetailSheet` in `caja_screen.dart`: button with `key: 'caja-export'` calls `reportesProvider.notifier.exportCajaReport(session.id, formato: 'XLSX')` when `canAccess(RoutePaths.reportes)`. Unit test confirms the notifier path returns `OperationContent<ReporteExportado>` with server filename.

### Sub-Blocker D: TDD proof — replaced 6 CRITICAL trivial tests
- `web_parity_test.dart` former L216-221: replaced sha256 trivial check → now calls `sha256HexOf` twice (determinism), asserts 64-char hex format, collision resistance, and exception-on-mismatch.
- `web_parity_test.dart` former L224-233: replaced hardcoded string `.startsWith('/')` loop → now calls 7 `RoutePaths.*` constants and asserts their exact path values.
- `ventas_test.dart` former L532: `_uuid.v4()` → `VentasRepository.generateIdempotencyKey()` uniqueness test.
- `ventas_test.dart` former L539: tautology (`retryKey = key; expect(retryKey, key)`) → `CreateVentaPayload.idempotencyKey` preservation test.
- `ventas_test.dart` former L545: `_uuid.v4()` → `VentasRepository.generateIdempotencyKey()` UUID v4 format test.
- `ventas_test.dart` former L871: local `doSubmit` function → `saleMutationError(AppException)` formats message+code test.

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Scenario 14 | `annulment_coverage_test.dart` | Unit | 309/309 | `ventaHasVisibleRecargo` absent → compile error | Added function → 5/5 | annulled+active+null-recargo (3 cases) | N/A |
| Scenario 29 | `annulment_coverage_test.dart` | Unit | Same | N/A — existing production code | 5/5 → exit 0 | endpoint path + response fields (2 cases) | N/A |
| Scenario 36 | `pin_coverage_test.dart` | Widget | 309/309 | Passes immediately (existing production doesn't leak PIN) | 4+/4+ → exit 0 | Single scenario; widget behavior proven | N/A |
| Scenario 35 | `pin_coverage_test.dart` | Widget | Same | N/A — new widget tests for existing widget | 2/2 → exit 0 | happy path + search filter | N/A |
| Scenarios 43+44 | `caja_export_test.dart` | Unit | 309/309 | N/A — existing notifier tested | 3/3 → exit 0 | authorized+unauthorized+filename check | N/A |
| Sub-Blocker D | `web_parity_test.dart` + `ventas_test.dart` | Unit | Same | N/A — replacements for existing tests | All pass → exit 0 | Multiple assertions per replacement | N/A |

### Files Created/Modified
| File | Action | Detail |
|---|---|---|
| `lib/features/ventas/data/models/venta_models.dart` | Modified | Added `ventaHasVisibleRecargo(Venta v)` pure function |
| `lib/features/caja/presentation/screens/caja_screen.dart` | Modified | Added imports + `canExportCaja` flag + export button in `_DetailSheet` |
| `test/features/ventas/annulment_coverage_test.dart` | Created | 5 unit tests — Scenarios 14 and 29 |
| `test/features/usuarios/pin_coverage_test.dart` | Created | 3 widget tests — Scenarios 35 and 36 |
| `test/features/caja/caja_export_test.dart` | Created | 3 unit tests — Scenarios 43 and 44 |
| `test/features/parity/web_parity_test.dart` | Modified | Replaced 2 trivial tests with production-calling assertions |
| `test/features/ventas/ventas_test.dart` | Modified | Replaced 4 trivial tests with production-calling assertions |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Safety net | `flutter test` → exit 0, 309/309 before any change |
| Focused (new tests) | `flutter test test/features/ventas/annulment_coverage_test.dart test/features/usuarios/pin_coverage_test.dart test/features/caja/caja_export_test.dart` → exit 0, 11/11 |
| Full suite | `flutter test` → exit 0, **320/320** passed |
| Runtime harness | N/A — all new tests are unit/widget tests; no HTTP boundary crossed |
| Rollback boundary | Delete 3 new test files; revert `ventaHasVisibleRecargo` from `venta_models.dart`; revert 2 imports + `canExportCaja` + export button block from `caja_screen.dart`; revert 2 test replacements in `web_parity_test.dart`; revert 4 test replacements in `ventas_test.dart` |
| Authored lines | ~210 additions (production: 20, tests: 190) — within 800-line budget |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:fca703b46810c672cce09816f9f3776c9e4c3cf42020295c3e9a99735c0f7e8c
lineage_id: ""
generation: 0
fix_batch: 6
focused_tests: passed
runtime_harness: N/A
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:fca703b46810c672cce09816f9f3776c9e4c3cf42020295c3e9a99735c0f7e8c","lineage_id":"","generation":0,"fix_batch":6,"commands":[{"command":"flutter test test/features/ventas/annulment_coverage_test.dart test/features/usuarios/pin_coverage_test.dart test/features/caja/caja_export_test.dart","exit_code":0,"result":"11 of 11 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"320 of 320 tests passed"}],"runtime_harness":{"status":"N/A","command":"","result":"","na_reason":"All new tests are unit or widget-level tests with no real HTTP calls or platform bridges."},"rollback":{"boundary":"Delete annulment_coverage_test.dart, pin_coverage_test.dart, caja_export_test.dart; revert ventaHasVisibleRecargo from venta_models.dart; revert 2 imports+canExportCaja+button from caja_screen.dart; revert 2 test replacements in web_parity_test.dart; revert 4 test replacements in ventas_test.dart","evidence":"Reverting only those paths removes this remediation without affecting prior work"}}
```

## Focused Remediation #8: Android/Windows Normative Platform Matrix (Scenarios 6 and 7)

### Blocker: No normative platform matrix, no source-conflict test (verify-report Scenarios 6 and 7)
**Problem**: The verify-report flagged that no test proved the Android `FileArtifactService` dispatches through the SAF `MethodChannel`, no test proved the Windows service dispatches through the native file dialog, and no test proved graceful fallback when neither platform handler is active.
**Fix**: Created `test/core/files/platform_normative_matrix_test.dart` with 7 tests covering all three normative requirements. Zero production code changes — existing implementations were already correct; the gap was test coverage only.

### What each test proves

**Scenario 6 – Android SAF**:
- `JSON open: dispatches to SAF MethodChannel with correct path and MIME` — intercepts `MethodChannel('com.barbeer.barbeer/files')` via `TestDefaultBinaryMessengerBinding`; verifies method=`'openFile'`, correct path and `application/json` MIME.
- `.sh save: validation blocks file before SAF channel is reached` — SAF channel mock + save bridge both set; proves neither is invoked for `.sh` filenames.
- `XLSX save: dispatches through SAF bridge and returns content:// URI` — proves save path returns `content://...` URI (SAF scheme), not a direct filesystem path.

**Scenario 7 – Windows file dialog**:
- `XLSX open: dispatches through native openBridge with correct MIME` — captures `capturedPath` and `capturedMime`; asserts the exact `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` MIME is forwarded.
- `XLSX save: dispatches through saveBridge and returns Windows drive-letter path` — asserts result starts with `C:\`, proving Windows path semantics (not `content://`).

**Source conflict – no platform (fallback)**:
- `Android open with no bridge and no channel handler returns FileArtifactOpenUnsupported` — `TestDefaultBinaryMessengerBinding` handler set to null → `MissingPluginException` caught by `catch(_)` → `FileArtifactOpenUnsupported` (not crash).
- `Windows open with failing openBridge returns FileArtifactOpenUnsupported` — bridge throws `Exception` → caught by `catch(_)` → `FileArtifactOpenUnsupported` (not crash).

### TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Scenario 6 (Android SAF matrix) | `platform_normative_matrix_test.dart` | Unit | 320/320 | Written before run; tests would fail if production dispatch were wrong | 3/3 → exit 0 (production code was already correct) | SAF channel invocation + .sh blocked + XLSX content:// URI (3 distinct dispatch paths) | N/A — clean on first pass |
| Scenario 7 (Windows matrix) | `platform_normative_matrix_test.dart` | Unit | Same | Same approval-test approach | 2/2 → exit 0 | XLSX open MIME + XLSX save Windows path (2 distinct dispatch paths) | N/A |
| Source conflict (fallback) | `platform_normative_matrix_test.dart` | Unit | Same | Same approval-test approach | 2/2 → exit 0 | Android MissingPluginException fallback + Windows bridge-exception fallback | N/A |

### Files Created
| File | Action | Lines | Detail |
|---|---|---|---|
| `test/core/files/platform_normative_matrix_test.dart` | Created | 173 | 7 unit tests covering Android SAF, Windows dialog, and source-conflict fallback |

### Work Unit Evidence
| Evidence | Result |
|---|---|
| Safety net | `flutter test` → exit 0, **320/320** before any change |
| Focused RED | `platform_normative_matrix_test.dart` not yet created → no tests for these scenarios (the gap the remediation closes) |
| Focused GREEN | `flutter test test/core/files/platform_normative_matrix_test.dart` → exit 0, **7/7** passed |
| Full suite | `flutter test` → exit 0, **327/327** passed (320 baseline + 7 new) |
| Runtime harness | N/A — all new tests are pure unit tests; `TestDefaultBinaryMessengerBinding` intercepts the platform channel boundary without requiring a running Android/Windows device |
| Rollback boundary | Delete `test/core/files/platform_normative_matrix_test.dart`. No production code changed; no other file modified. Reverting only this file returns the suite to 320/320. |
| Authored lines | 173 additions (new test file only). Within 300-line target. |

```yaml
schema: gentle-ai.remediation-result/v1
status: complete
failed_evidence_revision: sha256:fca703b46810c672cce09816f9f3776c9e4c3cf42020295c3e9a99735c0f7e8c
lineage_id: ""
generation: 0
fix_batch: 7
focused_tests: passed
runtime_harness: N/A
rollback_boundary: recorded
```
```json
{"schema":"gentle-ai.remediation-evidence/v1","failed_evidence_revision":"sha256:fca703b46810c672cce09816f9f3776c9e4c3cf42020295c3e9a99735c0f7e8c","lineage_id":"","generation":0,"fix_batch":7,"commands":[{"command":"flutter test test/core/files/platform_normative_matrix_test.dart","exit_code":0,"result":"7 of 7 focused tests passed"},{"command":"flutter test","exit_code":0,"result":"327 of 327 tests passed"}],"runtime_harness":{"status":"N/A","command":"","result":"","na_reason":"All 7 new tests are pure unit tests using TestDefaultBinaryMessengerBinding or DI bridge injection. No device or HTTP boundary is crossed."},"rollback":{"boundary":"Delete test/core/files/platform_normative_matrix_test.dart only","evidence":"No production code was changed; reverting only this file removes this remediation without affecting prior work"}}
```
