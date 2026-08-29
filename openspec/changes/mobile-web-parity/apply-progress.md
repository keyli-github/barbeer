# Apply Progress: Mobile-Web Parity

**Status**: Active tasks 2.1 and 2.2 are complete; the former backend WU1 was explicitly reverted by maintainer scope decision, and the protected Flutter baseline remains intact.
**Mode**: Strict TDD
**Delivery**: The latest active mobile slice (formerly WU3, now mobile WU2) remains independently reversible under `stacked-to-main`; no branch or delivery operation was performed.

## Completed Active Tasks
- [x] 2.1 Added exact Dio error normalization and five distinct shared operation states under Strict TDD.
- [x] 2.2 Added centralized role/effective-permission access rules, splash-safe deep-link guards, unknown-route denial, and a state-preserving 403 authorization-refresh seam under Strict TDD.

## Reverted Historical Backend Work
- Former task 1.1 added list/detail RED tests for persisted `total`, `recargoMonto`, and `recargoMotivo`.
- Former task 1.2 mapped those persisted fields in `VentasReadService.toResponse`.
- Former task 1.3 reviewed the service/spec pair and reran its focused test.
- Maintainer scope decision superseded that work: all edits were reverted, `C:\Users\key\backend_bar` is clean at `077d9cb` and equals `origin/main`, and no backend/server work is active or required.

## Changed Files
- `backend_bar/src/modules/ventas/ventas-read.service.spec.ts` — historical focused cases; reverted and absent from the current diff.
- `backend_bar/src/modules/ventas/ventas-read.service.ts` — historical mapping; reverted and absent from the current diff.
- `barbeer/openspec/changes/mobile-web-parity/tasks.md` — removed former backend tasks from active work.
- `barbeer/test/features/ventas/ventas_test.dart` — backend-supported wallet and analyzed-receipt expectations.
- `barbeer/test/features/shell/desktop_shell_test.dart` — Riverpod/shared-preferences fixtures and current accordion semantics.
- `barbeer/test/features/auth/login_screen_test.dart` — semantic responsive-login assertions.
- `barbeer/test/features/ventas/nueva_venta_view_test.dart` — redesigned grid and payment-action assertions.
- `barbeer/lib/features/auth/presentation/screens/login_screen.dart` — compact security-footer flex fix only.
- `barbeer/lib/features/ventas/presentation/screens/nueva_venta_view.dart` — total/payment label flex fixes only.
- `barbeer/lib/core/async/operation_state.dart` — loading, content, empty, recoverable-error, and partial-result variants.
- `barbeer/lib/core/errors/app_exception.dart` — preserved backend path and validation details.
- `barbeer/lib/core/network/api_client.dart` — pure Dio error mapper preserving normalized backend fields.
- `barbeer/test/core/network/api_client_error_test.dart` — five focused contract/state tests.
- `barbeer/lib/core/navigation/route_access_policy.dart` — centralized route/action rules and pure guard decisions.
- `barbeer/lib/core/navigation/app_destinations.dart` — navigation visibility delegates to the centralized policy.
- `barbeer/lib/core/routes/router_refresh_notifier.dart` — retained deep-link and auth-refresh notification seam.
- `barbeer/lib/core/routes/route_paths.dart` — declared guarded future capability roots.
- `barbeer/lib/core/routes/app_router.dart` — splash, login, forced-password, denial, and pending deep-link redirects.
- `barbeer/lib/features/auth/presentation/providers/auth_provider.dart` — shared action checks and state-preserving authorization refresh.
- `barbeer/lib/features/shell/presentation/screens/shell_screen.dart` — role-aware destination filtering; `desktop_shell.dart` remained untouched.
- `barbeer/test/core/navigation/route_access_policy_test.dart` — unit and widget guard/access matrix.

## TDD Cycle Evidence
| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Former 1.1 (reverted) | `ventas-read.service.spec.ts` | Unit | 3/3 passed, 26.689 s | 2 failed/3 passed, 4.953 s | 5/5 passed after former 1.2 | List 15 vs 10; detail 27.5 vs 20 | Historical only; reverted |
| Former 1.2 (reverted) | `ventas-read.service.spec.ts` | Unit | 3/3 baseline | Tests from former 1.1 failed first | 5/5 passed, 4.743 s | Distinct list/detail values | Historical only; reverted |
| Former 1.3 (reverted) | `ventas-read.service.spec.ts` | Unit | 5/5 before refactor | Preserved former 1.1 RED | 5/5 passed | Two response paths | Historical only; reverted |
| Baseline: ventas | `ventas_test.dart` | Unit/widget | Audit baseline failed | Stale `SALIDA` and legacy manual-operation expectations | 35/35 passed | Required/optional receipt paths | Test-only contract drift corrected; no production change |
| Baseline: shell | `desktop_shell_test.dart` | Widget | Audit baseline failed | Missing provider-backed theme fixture | 2/2 passed | Light/collapse and dark-theme fixtures | Current accordion/user-menu semantics retained |
| Baseline: login | `login_screen_test.dart` | Widget | Audit: deterministic 60 px overflow | After semantic test correction: 3 passed, 1 failed on compact footer | 4/4 passed | Compact, wide, tall, visibility toggle | No further refactor; focused suite stayed green |
| Baseline: sale view | `nueva_venta_view_test.dart` | Widget | Audit: deterministic 3.2/0.25 px overflows | After redesigned expectations: 3 passed, 8 failed on overflows | 11/11 passed | Desktop/mobile, payment, retries, receipt states | No further refactor; focused suite stayed green |
| 2.1 | `api_client_error_test.dart` | Unit | 141/141 passed before RED | Exit 1, 0 tests loaded: missing operation-state types, `mapDioException`, and AppException path/details | 5/5 passed | 409 business metadata, 400 two-detail validation, 429 exact throttling, and all five state variants | Scoped format of four WU2 files; 5/5 passed afterward |
| 2.2 | `route_access_policy_test.dart`; existing navigation/shell tests | Unit/widget | 146/146 passed before RED | Exit 1, 0 tests loaded: missing policy/notifier APIs, future route roots, and 403 refresh seam | Initial focused GREEN 5/5; final focused suite 13/13 | Role+permission allow/deny, known allow/deny, unknown deny, pending deep link, 6 widget guard scenarios, and 403 success/failure preservation | Scoped format of 8 WU3 files; focused 13/13 and full 149/149 remained green |

Historical test summary: former backend WU1 wrote 2 tests before being reverted; former WU2 wrote 5 tests; former WU3 added 3 focused tests containing the access and widget matrices. The baseline correction updated existing behavioral assertions without adding test cases. Final recorded Flutter suite after former WU3: 149/149 passed.

## Former WU1 Work Unit Evidence (Historical, Reverted)
The following evidence is retained only as audit history. It is not current implementation, active task completion, or a prerequisite. The maintainer explicitly reverted the backend service/spec changes and prohibited backend edits, commits, pushes, and deployments.

| Evidence | Result |
|---|---|
| Focused test | `pnpm test -- ventas-read.service.spec.ts` → exit 0; 1 suite, 5 tests passed, 0 snapshots; 4.130 s. |
| Runtime harness | Deployed unauthenticated `GET /ventas?pagina=1&limite=1` returned HTTP 401 `No autorizado.` Authenticated fixture validation is blocked/N/A because no runtime auth variables or test credentials are available; the repository harness requires mandatory passwords. No deployment claimed. |
| Reversion result | The service/spec pair and active task marks were reverted; `C:\Users\key\backend_bar` is clean and `HEAD == origin/main == 077d9cb77948af863f8749174f923301709ec5ce`. |
| Historical authored line count | 113 changed lines at the time: backend 64 additions + 8 deletions, task marks 3 additions + 3 deletions, and progress bookkeeping. |

## Protected Baseline Correction Evidence

| Evidence | Result |
|---|---|
| Focused tests | In required final order: `flutter test test/features/ventas/ventas_test.dart` → exit 0, 35/35; `flutter test test/features/shell/desktop_shell_test.dart` → exit 0, 2/2; `flutter test test/features/auth/login_screen_test.dart` → exit 0, 4/4; `flutter test test/features/ventas/nueva_venta_view_test.dart` → exit 0, 11/11. |
| Full test | `flutter test` → exit 0, 141/141 passed; executed exactly once after final focused GREEN. Existing non-fatal wallet-dropdown tap warnings remain. |
| Runtime harness | N/A — this correction changes widget layout/test fixtures only and introduces no runtime/network boundary; credentialed device E2E is outside the audited baseline correction. |
| Rollback boundary | Revert only the four test files plus the footer `Flexible` hunk in `login_screen.dart` and the payment-label/total-label `Flexible`/`Expanded` hunks in `nueva_venta_view.dart`. The reverted backend work is absent; unrelated responsive redesign remains intact. |
| Authored line count | 238 code/test changed lines: 125 additions + 113 deletions. Artifact bookkeeping excluded. This remains below the native 300-line correction limit. |
| Formatter | Scoped `dart format --output=none --set-exit-if-changed` inspected only the six intentional files and reported pre-existing whole-file format drift; no broad rewrite was applied. `git diff --check` passed. |

### Protected Hash Proof

Before snapshot used per-file SHA-256 because audit observation #73 retained only aggregate `cd061f98d731f1ba950872408c08858e734e9c715c9c78b3500a13e7b56a85be`. Reproduced manifest aggregate was `a59686f20dccaed91623fd24f51884bce1197b21d122a681057f79a5c04d4c0a`; final aggregate is `7aa0b6e2c7348efc88b161ac26b2a226bfe23274ec37ada33c286f02772e536d` solely because of the two approved production hunks.

- Intentional: `login_screen.dart` `ee0a4fbe7ce605570288110df33c5bfa969360605b8058b71b2f35496b47c600` → `d2dc49881aaab99a00289a6205885da830ae046accf3a0298827f1de51ad8d94`.
- Intentional: `nueva_venta_view.dart` `4410adbf260fc9d946052342a8b22bafb46bcae50df262f81331948a58c5fdd2` → `6871b691b660bb5256e2f3af33753a94c22c3c13df7905837713f4138b7b041f`.
- Unchanged before/after: `api_constants.dart` `05cc9d27`; `asistencia_screen.dart` `a12e4b79`; `auditoria_screen.dart` `d027ffa6`; `change_password_screen.dart` `da4a5733`; `caja_screen.dart` `8342f9d8`; `movimientos_screen.dart` `de2d83b3`; `categorias_screen.dart` `b1716121`; `compras_screen.dart` `1ffb8706`; `dashboard_screen.dart` `cb0eacd9`; `inventario_screen.dart` `15cc3c0d`; `kardex_screen.dart` `f19d6e08`.
- Unchanged before/after: `perfil_screen.dart` `165c9024`; `permisos_screen.dart` `6572c793`; `productos_screen.dart` `b5e770c9`; `desktop_shell.dart` `fae08a27`; `sucursales_screen.dart` `2a6050dc`; `conciliar_venta_screen.dart` `f6957fbd`; `historial_ventas_view.dart` `fcf43119`; `venta_detail_screen.dart` `6fc93b8d`; `ventas_screen.dart` `9a0f5eea`; `responsive_helper.dart` `6aa5b966`.

No protected file was reset, stashed, globally formatted, staged, committed, pushed, or overwritten. Backend files were not touched during this correction.

## WU2 Work Unit Evidence

| Evidence | Result |
|---|---|
| Safety net | `flutter test` before RED → exit 0; 141/141 passed. Existing non-fatal wallet-dropdown tap warnings remained. |
| RED | `flutter test test/core/network/api_client_error_test.dart` → exit 1; 0 tests loaded because the test referenced missing `operation_state.dart`, `mapDioException`, and AppException `path`/`details`. |
| GREEN | Same focused command → exit 0; 5/5 passed after minimal production implementation. |
| REFACTOR | `dart format` targeted only the four WU2 files; focused command rerun → exit 0, 5/5 passed. |
| Full test | `flutter test` once after final focused GREEN → exit 0; 146/146 passed. Existing non-fatal wallet-dropdown tap warnings remained. |
| Runtime harness | N/A — WU2 is a pure Dio-error mapping and immutable state-type foundation with no runtime, device, route, persistence, or network boundary. |
| Rollback boundary | Revert only `operation_state.dart`, the AppException path/details additions, the `mapDioException` replacement in `api_client.dart`, `api_client_error_test.dart`, and task/progress marks. The protected baseline correction and unrelated features remain intact. |
| Authored line count | 263 code/test changed lines: 208 additions + 55 deletions. OpenSpec/Engram bookkeeping excluded; below the 300-line WU2 limit. |
| Diff hygiene | `git diff --check` on the four WU2 files passed. No dependencies, protected screens, backend files, or delivery state changed. |

### WU2 Protected Hash Proof

Before and after WU2, the 23-file manifest SHA-256 was `ca9895941b3d8227f812161405047de8727880028759efb243bd2a8d24e06860`; tracked protected binary-diff SHA-256 was `a78a4b1b1b13ebdf3ee0fcd3a1a0d1f50beef577842bc488c9a70a32b7985144` over 222,762 characters. Every protected file remained byte-identical:

- `api_constants.dart` `05cc9d2779ed0d4d2833879f7402777395eada862ad5786eb9c46d172ea80f74`; `asistencia_screen.dart` `a12e4b79b09e6d11a4c3e8acf8678506611aca3c97f6278d46d50e6103634623`; `auditoria_screen.dart` `d027ffa6b6b835b257c712492a28b8f1506752bd7b1e9748a06902c27ed914c5`.
- `change_password_screen.dart` `da4a5733b31e9ed64baee42235c8adf12013402948530b9bfc493326d1e911ba`; `login_screen.dart` `d2dc49881aaab99a00289a6205885da830ae046accf3a0298827f1de51ad8d94`; `caja_screen.dart` `8342f9d83590d71b575f1eddd5729389f08c96575bd72bb0c421d6b15d41ebf1`.
- `movimientos_screen.dart` `de2d83b377eb51cc3adaa9c73bef968b7ba5d39a456ba382f06dc051f9101d34`; `categorias_screen.dart` `b1716121c4a2b191cd8068d52fd9497d570be1597a4c41ae9a0bd3f5a97e278b`; `compras_screen.dart` `1ffb8706925a9cdb2b4e136de6b796b5bd8cbacaf2ae707c84e0b7e117e46d78`.
- `dashboard_screen.dart` `cb0eacd9195f38f7d1fe771bcc41546fbaf0647495cfe498738cc87b8e4fc3bf`; `inventario_screen.dart` `15cc3c0daeaeb05b9833863f2e683cbf89f40511b008bc12170f9917cd4b041b`; `kardex_screen.dart` `f19d6e08a7a583e7b02691d34774c51c9303690c5b36b192aeebffa75c08c09c`.
- `perfil_screen.dart` `165c90249e5245b3ed70dbb171b6b59f4e5354f9fe20bc88f90cafd2de81c178`; `permisos_screen.dart` `6572c7932a1b1f1c9a2edac262ac845c0ecbbc1be572f462c0ae2c4faa984ca0`; `productos_screen.dart` `b5e770c99936a089a0602b2ed42dae4629136f61f836d855fff44da1e9266110`.
- `desktop_shell.dart` `fae08a27034de47ebbdb9ee96532230e515437d2f32d1fd1e805ed69901f0501`; `sucursales_screen.dart` `2a6050dc3b2d7689c71063aa162aa86ab625c54627afaf04981821eb0228129b`; `conciliar_venta_screen.dart` `f6957fbd22597152d58d8fd652174a1ca1c696b1246e7b5a42d02c69ce4f2573`.
- `historial_ventas_view.dart` `fcf4311992119d69236f7e2f6a42fb7b4e77df5dd1c89ae069f5fdacc0fe5711`; `nueva_venta_view.dart` `6871b691b660bb5256e2f3af33753a94c22c3c13df7905837713f4138b7b041f`; `venta_detail_screen.dart` `6fc93b8d2e0335a4158e3b51398dae8fb409d6b42cb5377125f06453500b10b9`.
- `ventas_screen.dart` `9a0f5eeae2fe842c2bda5bb0abc90b456774c34a7352847094531301586d7d14`; `responsive_helper.dart` `6aa5b966fa39ee1b56899b8474351af1bbd2e1af987594135dce64cfd0e26f2d`.

## WU3 Work Unit Evidence

| Evidence | Result |
|---|---|
| Safety net | `flutter test` before RED → exit 0; 146/146 passed. Existing non-fatal wallet-dropdown tap warnings remained. |
| RED | `flutter test test/core/navigation/route_access_policy_test.dart` → exit 1; 0 tests loaded because `route_access_policy.dart`, `router_refresh_notifier.dart`, future guarded route roots, and `refreshAuthorizationAfterForbidden` did not exist. |
| GREEN | Same isolated command → exit 0; initial 5/5 passed after minimal implementation. |
| REFACTOR / focused | `dart format` targeted only 8 WU3 files; `flutter test test/core/navigation test/features/shell/shell_screen_test.dart` → exit 0; 13/13 passed. |
| Full test | `flutter test` once after final focused GREEN → exit 0; 149/149 passed. Existing non-fatal wallet-dropdown tap warnings remained. |
| Runtime harness | Widget deep-link/access matrix in `route_access_policy_test.dart` passed unresolved→`SPLASH`, forced-password→`CHANGE PASSWORD`, unauthenticated→`LOGIN`, authorized known→protected content, denied known→`UNAUTHORIZED`, and unknown protected→`UNAUTHORIZED`; denied scenarios asserted protected markers were absent before settle. |
| Rollback boundary | Revert only `route_access_policy.dart`, `app_destinations.dart`, `router_refresh_notifier.dart`, `route_paths.dart`, `app_router.dart`, `auth_provider.dart`, `shell_screen.dart`, `route_access_policy_test.dart`, and task/progress marks. Active task 2.1, protected responsive work, and `desktop_shell.dart` remain intact. |
| Authored line count | 373 code/test changed lines: 339 additions + 34 deletions. OpenSpec/Engram bookkeeping excluded; below the WU3 380-line limit. |
| Diff hygiene | Scoped `git diff --check` passed. No dependency, backend, protected screen, delivery, or deployment state changed. |

### WU3 Protected Hash Proof

Before RED and after verification, the 23-file manifest SHA-256 was `670e1aebcede5fec3e82385ca49c7af688572be8dee766aeb7f417373e84d088`; tracked protected binary-diff SHA-256 was `585e5e2d4cd14f48a08ad9b4a3ee94b04a0e8af1354a7c211fe713c3f46866fb` over 228,408 characters. Every protected file remained byte-identical, including `desktop_shell.dart` `fae08a27034de47ebbdb9ee96532230e515437d2f32d1fd1e805ed69901f0501` and `responsive_helper.dart` `6aa5b966fa39ee1b56899b8474351af1bbd2e1af987594135dce64cfd0e26f2d`.

## Remaining
Tasks 3.1–4.5 remain pending. Two of 13 active tasks are complete across 12 mobile work units. The latest active mobile slice is ready for independent review; no work may edit, commit, push, or deploy outside `C:\Users\key\barbeer`.
