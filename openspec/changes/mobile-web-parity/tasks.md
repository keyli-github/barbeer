# Tasks: Complete Mobile-Web Functional Parity

## Review Workload Forecast

|Field|Value|
|---|---|
|Estimated authored changes|4,740 lines|
|400-line budget risk|High|
|Chained PRs recommended|Yes|
|Delivery strategy|ask-on-risk|
|Mobile work units / PRs|13 / 13|
|Suggested split|PR 1 → PR 2 → … → PR 13|
|Chain strategy|stacked-to-main|

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Execution Protocol

Every WU is RED→GREEN→REFACTOR; `F` and final `V` mean `flutter test`. Before RED and after V, compare SHA-256/binary snapshots for the 22 dirty paths plus `lib/core/utils/responsive_helper.dart`. Non-collision hashes stay identical; only reviewed capability hunks may touch `api_constants.dart`, `desktop_shell.dart`, sales screens, `productos_screen.dart`, or `inventario_screen.dart`. Never reset, stash, globally format, or reconcile unrelated work; format WU files only. No work unit may edit, test, commit, push, or deploy outside `C:\Users\key\barbeer`; backend and web remain read-only authority.

### Suggested Work Units

|WU / PR|Goal; planned cap|Focused test|Runtime harness|Rollback|
|---|---|---|---|---|
|1 / 1|Async/error contracts; 300|`F test/core/network/api_client_error_test.dart`|N/A—pure mapping|core async/error|
|2 / 2|Access/guards; 380|`F test/core/navigation/route_access_policy_test.dart`|widget deep-link matrix|routes/navigation|
|3a / 3|Recargo control contract and authorization UI; 360|`flutter test test/features/recargo/recargo_test.dart --plain-name control`|mocked authorized/denied/config/toggle|WU3a paths/hunks only|
|3b / 4|Confidential sale invariants; 240|`flutter test test/features/recargo/recargo_test.dart --plain-name confidential`; `flutter test test/features/ventas/ventas_test.dart`|mocked hidden-state draft and normal-view|sales confidentiality hunks only|
|4 / 5|Account reads; 390|`F test/features/cuentas/cuentas_test.dart --plain-name read`|scoped search/detail|read route|
|5 / 6|Collections; 370|`F test/features/cuentas/cuentas_test.dart --plain-name collection`|partial/full payment|payment seam|
|6 / 7|Account sales; 400|`F test/features/parity/web_parity_test.dart --plain-name account`|charge/receipt/annul|sales seam|
|7 / 8|Permissions; 390|`F test/features/usuarios/usuario_authorization_test.dart --plain-name permission`|replace exceptions|permission seam|
|8 / 9|PIN/stock; 400|`F test/features/usuarios/usuario_authorization_test.dart --plain-name PIN`|throttled PIN/stock|authorization seam|
|9 / 10|Platform files; 390|`F test/core/files/file_artifact_service_test.dart`|Android/Windows save/open|file port/deps|
|10 / 11|Reports/email; 400|`F test/features/reportes/reportes_test.dart`|export/email test|report route|
|11 / 12|Backups; 400|`F test/features/respaldos/respaldos_test.dart`|schedule/history/download|backup route|
|12 / 13|Parity closure; 320|`F test/features/parity/web_parity_test.dart`|acceptance on both devices|evidence/routes|

## Phase 2: Shared Foundation

- [x] 2.1 WU1: test then implement `lib/core/async/operation_state.dart`, `lib/core/errors/app_exception.dart`, `lib/core/network/api_client.dart`, `test/core/network/api_client_error_test.dart`.
- [x] 2.2 WU2: test then implement `lib/core/navigation/{route_access_policy.dart,app_destinations.dart}`, `lib/core/routes/{router_refresh_notifier.dart,route_paths.dart,app_router.dart}`, `lib/features/auth/presentation/providers/auth_provider.dart`, `lib/features/shell/presentation/screens/shell_screen.dart`.

## Phase 3: Capability Slices

- [x] 3.1a WU3a: RED→GREEN→REFACTOR three API constants, `lib/features/recargo/` repository/provider/control sheet, smallest history/entry hooks, and contract/provider/toggle tests; remain unchecked until the control command and harness pass.
- [x] 3.1b WU3b (after 3.1a): RED→GREEN→REFACTOR surgical draft/submit/history/detail/sheet hooks and confidential view/draft tests; remain unchecked until Recargo confidentiality and affected ventas tests plus harness pass.
- [x] 3.2 WU4: test then implement `lib/features/cuentas/` reads with stale-response protection.
- [x] 3.3 WU5: extend `test/features/cuentas/cuentas_test.dart` and `lib/features/cuentas/` for idempotent payments.
- [x] 3.4 WU6: test then implement `lib/features/cuentas/presentation/widgets/cuenta_selector.dart` and account-sale hooks in `lib/features/ventas/`.
- [x] 3.5 WU7: test then implement permission exceptions in `lib/features/usuarios/`.
- [x] 3.6 WU8: extend user-authorization tests and `lib/features/{usuarios,productos,inventario}/` PIN/stock seams.

## Phase 4: Files and Closure

- [x] 4.1 RED in `test/core/files/file_artifact_service_test.dart`: `requirements.txt`, `CMakeLists.txt`, executable Markdown/MDX, `README.sh`; allow declared xlsx/json/txt only, never execute, reject executable/mismatched names.
- [x] 4.2 GREEN→REFACTOR WU9 in `lib/core/files/`, `pubspec.yaml`, and `android/app/src/main/kotlin/com/barbeer/barbeer/MainActivity.kt`.
- [x] 4.3 WU10: test then implement `lib/features/reportes/` and route/API wiring.
- [x] 4.4 WU11: test then implement `lib/features/respaldos/`, route/API wiring, and SHA-256 downloads.
- [x] 4.5 WU12: complete `test/features/parity/web_parity_test.dart`, `test/core/navigation/app_destinations_test.dart`, `integration_test/acceptance_test.dart`; record Android/Windows parity.
