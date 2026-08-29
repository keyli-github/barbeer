# Design: Complete Mobile-Web Functional Parity

## Technical Approach

Deliver mobile-only, contract-backed vertical slices with the existing feature-first Dio repositories, Riverpod `StateNotifierProvider`s, `go_router`, and current widgets. Order: (1) shared errors/guards, (2) recargo, (3) account reads, (4) collections/account sales, (5) permissions/PIN/stock, (6) reports/email/files, (7) backups. Each slice is independently reversible and split before apply when forecast above 400 authored lines.

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| Vertical `data/presentation` slices | Existing code sometimes embeds providers/repositories in screens | Follow local conventions; no architecture rewrite. |
| Current backend read contract | Omitted confidential fields can prevent exact visual parity | Consume exact fields currently returned. Never infer omitted recargo fields or recalculate historical financial totals. When an endpoint omits confidential fields, render only authoritative available values and record a parity limitation; never change `backend_bar`, web, or the deployed server. |
| Shared operation/error model | Adds core types | Normalize loading/content/empty/error/partial and preserve backend `message`, `statusCode`, `path`, `code`, and validation details in affected slices. |
| Central access policy | Adds one registry | Deny unknown protected routes; combine role plus effective permissions for navigation, deep links, and actions. Auth loading stays on splash; 403 restores prior UI and refreshes authorization. Backend remains mutation authority. |
| Platform file port | Two implementations | Existing `file_picker` saves; Android SAF/content-URI intent and Windows save dialog/`open_filex` open. `crypto` verifies backup SHA-256. |

## Data Flow

    Screen -> StateNotifier -> Repository -> ApiClient -> Backend
       ^          |              |                         |
       +---- authoritative state +---- FileArtifact -> platform adapter

DTOs map exact backend names without aliases. Sale/payment drafts retain one UUID through uncertain delivery and rotate only after confirmed success or changed intent. Post-success refresh failures become `partial`, never mutation retries. Request generations prevent stale account detail. Recargo state hides detail and blocks new positive recargos without recalculation. Backups expose scheduled runs only.

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/core/{async/operation_state.dart,navigation/route_access_policy.dart,routes/router_refresh_notifier.dart}`; `lib/core/files/{file_artifact.dart,file_artifact_service.dart,android_file_artifact_service.dart,windows_file_artifact_service.dart}` | Create (7) | Shared state, access, save/open contracts. |
| `lib/features/recargo/{data/recargo_control_repository.dart,presentation/providers/recargo_control_provider.dart,presentation/widgets/recargo_control_sheet.dart}`; `lib/features/cuentas/{data/models/cuenta_models.dart,data/cuentas_repository.dart,presentation/providers/cuentas_provider.dart,presentation/screens/cuentas_screen.dart,presentation/widgets/cuenta_selector.dart}` | Create (8) | Recargo and account slices. |
| `lib/features/{reportes,respaldos}/{data/models/*_models.dart,data/*_repository.dart,presentation/providers/*_provider.dart,presentation/screens/*_screen.dart}` | Create (8) | Export/email and backup slices. |
| `lib/features/usuarios/{data/models/usuario_permission_models.dart,data/usuario_admin_repository.dart,presentation/providers/usuario_admin_provider.dart,presentation/widgets/user_authorization_sheet.dart}` | Create (4) | Permission/PIN seam. |
| `test/core/{network/api_client_error_test.dart,navigation/route_access_policy_test.dart,files/file_artifact_service_test.dart}`; `test/features/{recargo/recargo_test.dart,cuentas/cuentas_test.dart,usuarios/usuario_authorization_test.dart,reportes/reportes_test.dart,respaldos/respaldos_test.dart}` | Create (8) | Focused RED tests. |
| `lib/core/{constants/api_constants.dart,errors/app_exception.dart,network/api_client.dart,navigation/app_destinations.dart,routes/{route_paths.dart,app_router.dart}}`; `lib/features/{auth/presentation/providers/auth_provider.dart,shell/presentation/screens/shell_screen.dart}`; `pubspec.yaml`; `android/app/src/main/kotlin/com/barbeer/barbeer/MainActivity.kt` | Modify (10) | Contracts, guard refresh, dependencies, Android open bridge. |
| `lib/features/ventas/{data/models/venta_models.dart,data/ventas_repository.dart,presentation/providers/ventas_provider.dart,presentation/screens/{nueva_venta_view.dart,historial_ventas_view.dart,venta_detail_screen.dart}}`; `lib/features/usuarios/presentation/screens/usuarios_screen.dart`; `lib/features/productos/{data/productos_repository.dart,presentation/screens/productos_screen.dart}`; `lib/features/inventario/presentation/providers/inventario_provider.dart` | Modify (10) | Minimal hooks and authoritative refreshes. |
| `test/features/parity/web_parity_test.dart`; `test/core/navigation/app_destinations_test.dart`; `integration_test/acceptance_test.dart` | Modify (3) | Regression and Android/Windows device evidence. |

Impact: 35 new, 23 modified, 0 deleted; all paths are under `C:\Users\key\barbeer`.

## Interfaces / Contracts

`FileArtifact(bytes, filename, contentType, expectedLength, expectedSha256?)` returns `saved(uri/path)`, `cancelled`, or typed failure. Reject separators/control characters and format/metadata mismatch. Verify report length and backup SHA-256 before save. Private backup bytes remain transient, uncached, and unlogged; open failure preserves save success.

## Testing Strategy

Per work unit: RED -> GREEN -> REFACTOR with focused `flutter test <file>`, then `flutter test`. Cover exact DTOs, five async states, idempotency, stale responses, denied mutations, unresolved/forced/direct/unknown routes, permission refresh, authoritative-field omissions, parity-limit records, and Android/Windows save/cancel/denial/path/integrity/open.

Before each slice, snapshot hashes and binary diffs for the protected 22 files plus `responsive_helper.dart`. Non-collision hashes stay identical; collision seams (`api_constants.dart`, `desktop_shell.dart`, sales screens, `productos_screen.dart`, `inventario_screen.dart`) receive reviewed capability hunks only. Never reset, stash, or whole-repo-format; format only slice files and compare the snapshot afterward.

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | Applicable | Allow endpoint-declared xlsx/json/txt only; never execute; reject executable/mismatched names | `requirements.txt`, `CMakeLists.txt`, executable Markdown/MDX, `README.sh` |
| Git repository selection | N/A—no Git automation | — | — |
| Commit state | N/A—no commit automation | — | — |
| Push state | N/A—no push automation | — | — |
| PR commands | N/A—no PR automation | — | — |

## Migration / Rollout

No data migration or server rollout. Start with shared foundation, then expose and rollback each tested mobile route/destination with its slice while preserving protected work.

## Open Questions

None blocking; backend and web mutations are not prerequisites and remain out of scope.
