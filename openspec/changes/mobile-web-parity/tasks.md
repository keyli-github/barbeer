# Tasks: Complete Mobile-Web Functional Parity

## Review Workload Forecast

|Field|Value|
|---|---|
|Estimated authored changes|4,530 lines|
|400-line budget risk|High|
|Chained PRs recommended|Yes|
|Delivery strategy|ask-on-risk|
|Suggested split|PR 1 → PR 2 → … → PR 12|
|Chain strategy|stacked-to-main|

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Execution Protocol

Every WU is RED→GREEN→REFACTOR; `F` and final `V` mean `flutter test`. Before RED and after V, compare SHA-256/binary snapshots for the 22 dirty paths plus `lib/core/utils/responsive_helper.dart`. Non-collision hashes stay identical; only reviewed capability hunks may touch `api_constants.dart`, `desktop_shell.dart`, sales screens, `productos_screen.dart`, or `inventario_screen.dart`. Never reset, stash, globally format, or reconcile unrelated work; format WU files only. No work unit may edit, test, commit, push, or deploy outside `C:\Users\key\barbeer`; backend and web remain read-only authority.

### Suggested Work Units

|WU/PR|Goal; estimate|Focused test|Runtime harness|Rollback|
|---|---|---|---|---|
|1|Async/error contracts; 300|`F test/core/network/api_client_error_test.dart`|N/A—pure mapping|core async/error|
|2|Access/guards; 380|`F test/core/navigation/route_access_policy_test.dart`|widget deep-link matrix|routes/navigation|
|3|Recargo; 390|`F test/features/recargo/recargo_test.dart`|hidden/toggle sale|recargo hooks|
|4|Account reads; 390|`F test/features/cuentas/cuentas_test.dart --plain-name read`|scoped search/detail|read route|
|5|Collections; 370|`F test/features/cuentas/cuentas_test.dart --plain-name collection`|partial/full payment|payment seam|
|6|Account sales; 400|`F test/features/parity/web_parity_test.dart --plain-name account`|charge/receipt/annul|sales seam|
|7|Permissions; 390|`F test/features/usuarios/usuario_authorization_test.dart --plain-name permission`|replace exceptions|permission seam|
|8|PIN/stock; 400|`F test/features/usuarios/usuario_authorization_test.dart --plain-name PIN`|throttled PIN/stock|authorization seam|
|9|Platform files; 390|`F test/core/files/file_artifact_service_test.dart`|Android/Windows save/open|file port/deps|
|10|Reports/email; 400|`F test/features/reportes/reportes_test.dart`|export/email test|report route|
|11|Backups; 400|`F test/features/respaldos/respaldos_test.dart`|schedule/history/download|backup route|
|12|Parity closure; 320|`F test/features/parity/web_parity_test.dart`|acceptance on both devices|evidence/routes|

## Phase 2: Shared Foundation

- [x] 2.1 WU1: test then implement `lib/core/async/operation_state.dart`, `lib/core/errors/app_exception.dart`, `lib/core/network/api_client.dart`, `test/core/network/api_client_error_test.dart`.
- [x] 2.2 WU2: test then implement `lib/core/navigation/{route_access_policy.dart,app_destinations.dart}`, `lib/core/routes/{router_refresh_notifier.dart,route_paths.dart,app_router.dart}`, `lib/features/auth/presentation/providers/auth_provider.dart`, `lib/features/shell/presentation/screens/shell_screen.dart`.

## Phase 3: Capability Slices

- [ ] 3.1 WU3: test then implement `lib/features/recargo/{data/recargo_control_repository.dart,presentation/providers/recargo_control_provider.dart,presentation/widgets/recargo_control_sheet.dart}` and recargo hooks in `lib/features/ventas/`.
- [ ] 3.2 WU4: test then implement `lib/features/cuentas/` reads with stale-response protection.
- [ ] 3.3 WU5: extend `test/features/cuentas/cuentas_test.dart` and `lib/features/cuentas/` for idempotent payments.
- [ ] 3.4 WU6: test then implement `lib/features/cuentas/presentation/widgets/cuenta_selector.dart` and account-sale hooks in `lib/features/ventas/`.
- [ ] 3.5 WU7: test then implement permission exceptions in `lib/features/usuarios/`.
- [ ] 3.6 WU8: extend user-authorization tests and `lib/features/{usuarios,productos,inventario}/` PIN/stock seams.

## Phase 4: Files and Closure

- [ ] 4.1 RED in `test/core/files/file_artifact_service_test.dart`: `requirements.txt`, `CMakeLists.txt`, executable Markdown/MDX, `README.sh`; allow declared xlsx/json/txt only, never execute, reject executable/mismatched names.
- [ ] 4.2 GREEN→REFACTOR WU9 in `lib/core/files/`, `pubspec.yaml`, and `android/app/src/main/kotlin/com/barbeer/barbeer/MainActivity.kt`.
- [ ] 4.3 WU10: test then implement `lib/features/reportes/` and route/API wiring.
- [ ] 4.4 WU11: test then implement `lib/features/respaldos/`, route/API wiring, and SHA-256 downloads.
- [ ] 4.5 WU12: complete `test/features/parity/web_parity_test.dart`, `test/core/navigation/app_destinations_test.dart`, `integration_test/acceptance_test.dart`; record Android/Windows parity.
