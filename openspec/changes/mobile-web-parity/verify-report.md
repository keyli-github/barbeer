```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:5aedc79bb2685ce2c55f958046c79a5748e818bd34085cda40674b532befb676
verdict: fail
blockers: 9
critical_findings: 9
requirements: 9/36
scenarios: 22/68
test_command: flutter test
test_exit_code: 0
test_output_hash: sha256:4ec1fc8560a290dcf7a92259b6b4770ec25dca2bd60c66d5f1f6e9086f3e57b2
build_command: flutter build windows --release
build_exit_code: 0
build_output_hash: sha256:df3cfd59c457bf532acefa613694689280e778a44e348181d3a62205115e1bb7
```

## Verification Report

**Change**: mobile-web-parity  
**Version**: N/A  
**Mode**: Strict TDD  
**Artifact mode**: OpenSpec with Engram mirror

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 14 |
| Tasks complete | 14 |
| Tasks incomplete | 0 |
| Spec requirements | 36 |
| Spec scenarios | 68 |

`tasks.md` marks all 14 tasks complete. This conflicts with `apply-progress.md`, which still states 12/14 and says tasks 4.4 and 4.5 remain pending. Runtime and source verification below confirms that closure/device evidence and several UI integrations are not complete despite the checked task boxes.

### Build & Tests Execution

**Focused tests**: ✅ 87 passed, 0 failed

```text
flutter test test/features/auth/login_screen_test.dart test/features/ventas/ventas_test.dart test/features/caja/caja_test.dart test/features/parity/web_parity_test.dart
Exit: 0
Output SHA-256: 3c29a73a211e885c67a4d70c3054fa94bc202df1b594f278d442725cd46ddbf6
Note: two Ventas widget actions emitted non-fatal hit-test warnings.
```

**Full tests**: ✅ 237 passed, 0 failed

```text
flutter test
Exit: 0
Output SHA-256: 4ec1fc8560a290dcf7a92259b6b4770ec25dca2bd60c66d5f1f6e9086f3e57b2
```

**Coverage run**: ✅ 237 passed, 0 failed

```text
flutter test --coverage
Exit: 0
Output SHA-256: 675687d9fb80dd609b2f1b4f37abdb74f569cbf41aca90a2ab41ac9425e17d74
Generated: coverage/lcov.info
```

**Windows release build**: ✅ Passed

```text
flutter build windows --release
Exit: 0
Built: build\windows\x64\runner\Release\barbeer.exe
Output SHA-256: df3cfd59c457bf532acefa613694689280e778a44e348181d3a62205115e1bb7
```

**Android release build**: ✅ Passed with Kotlin plugin migration warning

```text
flutter build apk --release
Exit: 0
Built: build\app\outputs\flutter-apk\app-release.apk (80.5 MB)
Output SHA-256: 750dc71684958510e2839bf7c713ecb7e78b9b980ad7ef4dd0f2ad1d86847cdc
```

**Static analysis**: ❌ Exit 1

```text
flutter analyze
Exit: 1
225 issues found (warnings and informational diagnostics; no compilation error was reported).
Output SHA-256: 58332dc62491cce7fa0c2d0ad3280e8b0b2d6b093816d9c0e25f5b9f2d9b5b80
```

**Device acceptance**: ❌ Not executed. A physical Android 14 device and Windows target were detected, but `integration_test/acceptance_test.dart` requires external credentials and performs state-changing sale, precuadre, and forced-close operations. No safe credentialed test fixture or five requested screenshots were available, and production access was prohibited.

**Coverage**: ⚠️ Changed production files: 52.3% lines (2527/4832); configured threshold: 0%.

### Spec Compliance Matrix

| # | Requirement | Scenario | Runtime test/evidence | Result |
|---:|---|---|---|---|
| 1 | Exact API contracts | Exact request and response mapping | Contract tests pass, but report/backup response headers are discarded and current Ventas mapping is incomplete | ⚠️ PARTIAL |
| 2 | Exact API contracts | Backend rejects an invalid contract | `api_client_error_test.dart` preserves message, status, path, code, and validation details | ✅ COMPLIANT |
| 3 | Deterministic async states | Empty and retry states | Shared states and selected modules are tested; Backups suppresses its captured error in the UI | ⚠️ PARTIAL |
| 4 | Deterministic async states | Partial dashboard response | `web_parity_test.dart` checks error retention in the model, not rendered module/error behavior | ⚠️ PARTIAL |
| 5 | Current-module parity | Existing module regression | No complete current-module suite; Dashboard, Ventas, and Caja divergences remain | ❌ UNTESTED |
| 6 | Normative parity closure | Close the parity matrix | No Android/Windows result matrix or screenshot evidence exists | ❌ UNTESTED |
| 7 | Normative parity closure | Source conflict | Design states backend wins, but no covering behavioral test was found | ❌ UNTESTED |
| 8 | Authoritative recargo state | Authorized state change | `recargo_test.dart` provider and widget toggle | ✅ COMPLIANT |
| 9 | Authoritative recargo state | Denied or throttled change | `recargo_test.dart` covers 401, 403, and 429 while preserving prior state | ✅ COMPLIANT |
| 10 | Complete recargo configuration | Save valid configuration | Exact PUT body and configuration widget save pass | ✅ COMPLIANT |
| 11 | Complete recargo configuration | Invalid assignment | Foreign assignment is covered; missing sede and missing initial key are not | ⚠️ PARTIAL |
| 12 | Confidential sale presentation | Confirm a recargo sale | Widget and payload tests preserve total and hide recargo detail | ✅ COMPLIANT |
| 13 | Hidden-state financial invariants | Hidden state blocks a new recargo | Draft/payload invariant tests pass | ✅ COMPLIANT |
| 14 | Hidden-state financial invariants | Existing sale is annulled | No test proves backend account/cash/Kardex reversal rendering with confidentiality | ❌ UNTESTED |
| 15 | Account search and scope | Search active debtors | Exact DTO/query test passes | ✅ COMPLIANT |
| 16 | Account search and scope | Empty, loading, or denied list | Notifier/widget state and authorization tests pass | ✅ COMPLIANT |
| 17 | Account detail and history | Load detail | Detail mapping and latest-request-wins widget test pass | ✅ COMPLIANT |
| 18 | Account detail and history | Missing account | 404 clearing/partial-state test passes | ✅ COMPLIANT |
| 19 | Account creation | Create an account | No create repository method, form, or covering test exists | ❌ UNTESTED |
| 20 | Account creation | Duplicate or invalid account | No create flow or validation/conflict test exists | ❌ UNTESTED |
| 21 | Partial and full collections | Apply a collection | Partial/full widget harness and idempotent retry tests pass | ✅ COMPLIANT |
| 22 | Partial and full collections | Transfer or accounting rejection | 400/403/404/409 preservation test passes | ✅ COMPLIANT |
| 23 | Sale account selector | Select or create an account | Repository selector is tested but unused by the sale UI; account creation is absent | ❌ UNTESTED |
| 24 | Sale account selector | Empty or failed selector | No rendered selector state or retry test exists | ❌ UNTESTED |
| 25 | Exact charged-sale payload | Charge part or all to account | Value-object payload test passes, but the sale screen never supplies account fields | ⚠️ PARTIAL |
| 26 | Exact charged-sale payload | Backend rejects account charge | No draft-preservation UI/notifier test exists | ❌ UNTESTED |
| 27 | Charged-sale results | Load charged receipt | Model parsing is tested; history/detail does not render account charge distinctly | ⚠️ PARTIAL |
| 28 | Charged-sale results | Refresh fails after creation | No partial refresh test for stock/receipt/account exists | ❌ UNTESTED |
| 29 | Annulment reverses account effects | Annul charged sale | Model state preservation is tested, not refreshed account/cash/Kardex reversals | ⚠️ PARTIAL |
| 30 | Annulment reverses account effects | Annulment cannot proceed | No 403/409/422 state-preservation test for charged sales exists | ❌ UNTESTED |
| 31 | Effective permission model | Load permission exceptions | DTO/repository test passes, but no permission editor uses it | ⚠️ PARTIAL |
| 32 | Effective permission model | Loading or missing target | No editor loading/404 behavior exists | ❌ UNTESTED |
| 33 | Atomic permission replacement | Save valid exceptions | Repository harness passes; no mutation UI/provider exists | ⚠️ PARTIAL |
| 34 | Atomic permission replacement | Invalid or denied replacement | 400/403 transport tests pass without rendered prior-state behavior | ⚠️ PARTIAL |
| 35 | Superadmin PIN lifecycle | Configure PIN mode | Repository and PIN sheet implementation exist, but no widget/runtime coverage proves refreshed PIN state | ⚠️ PARTIAL |
| 36 | Superadmin PIN lifecycle | PIN management denied | No covering management denial/secret-exposure test exists | ❌ UNTESTED |
| 37 | PIN validation | Valid, invalid, or throttled PIN | Repository harness covers results/429, but no UI lockout behavior exists | ⚠️ PARTIAL |
| 38 | Sensitive stock authorization | Authorized stock transition | Repository result test passes; production stock UI never calls `adjustStock` | ⚠️ PARTIAL |
| 39 | Sensitive stock authorization | Stock authorization fails | Transport errors are tested; no production stock state remains-unchanged flow is wired | ⚠️ PARTIAL |
| 40 | Superadmin report access | Authorized or denied route | Route policy and destination tests pass | ✅ COMPLIANT |
| 41 | Exact report export | Export a report | Exact request query is tested, but runtime discards server filename/content type | ⚠️ PARTIAL |
| 42 | Exact report export | Invalid or failed export | Notifier exposes retryable 400/403 failures and no completion | ✅ COMPLIANT |
| 43 | Cash-close export | Export closed cash-session sales | Repository method exists but has no production caller/action | ❌ UNTESTED |
| 44 | Cash-close export | Missing or invalid cash session | No covering test or production action exists | ❌ UNTESTED |
| 45 | Email configuration and test delivery | Load and save settings | Provider tests pass, but unique normalization and rendered empty state are not covered | ⚠️ PARTIAL |
| 46 | Email configuration and test delivery | Test delivery fails or succeeds | Provider tests preserve recipients and cover success/failure | ✅ COMPLIANT |
| 47 | Backup authorization and scope | Authorized or denied access | Destination and 403 propagation tests pass; missing-sede behavior is not covered in UI | ⚠️ PARTIAL |
| 48 | Schedule lifecycle | Load empty/default schedule | DTO parsing passes; no widget test proves backend defaults are rendered | ⚠️ PARTIAL |
| 49 | Schedule lifecycle | Save or reject schedule | Allowed body is tested; invalid editable-draft preservation is not | ⚠️ PARTIAL |
| 50 | Execution history and transitions | Scheduled execution progresses | Run DTO parsing passes; no refresh transition behavior is tested | ⚠️ PARTIAL |
| 51 | Execution history and transitions | Empty, partial, or failed history | No covering widget test; captured errors are not rendered | ❌ UNTESTED |
| 52 | Private artifact download | Download verified artifact | SHA verification passes, but response filename/content type are discarded before saving | ⚠️ PARTIAL |
| 53 | Private artifact download | Download rejected | Hash mismatch is covered; scope, size, storage, and transport paths are not | ⚠️ PARTIAL |
| 54 | Preserve authoritative file metadata | Server names the file | File service retains supplied metadata, but report/backup callers replace server metadata | ⚠️ PARTIAL |
| 55 | Preserve authoritative file metadata | Filename is absent | No test proves endpoint fallback plus user notification | ❌ UNTESTED |
| 56 | Platform-appropriate completion | Android completion | Mock bridge only; no physical Android save/open result | ❌ UNTESTED |
| 57 | Platform-appropriate completion | Windows completion | Mock bridge only; no native Windows save/open result | ❌ UNTESTED |
| 58 | Platform-appropriate completion | User cancels | Android and Windows mock cancellation tests pass | ✅ COMPLIANT |
| 59 | Failure and retry safety | Save fails after download | No persistence-failure retry test exists | ❌ UNTESTED |
| 60 | Failure and retry safety | Open is unsupported | No unsupported-open test exists | ❌ UNTESTED |
| 61 | Navigation mirrors authorization | Existing destination matrix | Route/destination policy tests pass | ✅ COMPLIANT |
| 62 | Navigation mirrors authorization | Permissions change after refresh | Authorization refresh test passes | ✅ COMPLIANT |
| 63 | New route rules | Authorized visibility | Accounts/reports/backups access tests pass | ✅ COMPLIANT |
| 64 | New route rules | Role conflicts with permission | Accounts role-plus-permission denial test passes | ✅ COMPLIANT |
| 65 | Deep-link and loading guards | Guard state transition | Widget deep-link matrix covers unresolved, login, forced change, and authorized | ✅ COMPLIANT |
| 66 | Deep-link and loading guards | Direct unauthorized route | Widget test proves no protected content flash | ✅ COMPLIANT |
| 67 | Backend remains mutation authority | Stale client authorization | Refresh state preservation is tested, not pending-UI rollback and denial rendering | ⚠️ PARTIAL |
| 68 | Backend remains mutation authority | Authorized mutation changes state | Selected repositories use returned state, but end-to-end payload/state coverage is incomplete | ⚠️ PARTIAL |

**Compliance summary**: 22/68 scenarios compliant; 25 partial; 21 untested. Nine of 36 requirements have every scenario compliant.

### Correctness (Static Evidence)

| Capability | Status | Notes |
|---|---|---|
| Current Dashboard parity | ❌ Missing | Web SUPERADMIN uses seven financial cards (`Ventas totales`, product cost, gross/net profit, units, expenses, margin); Flutter renders legacy Caja/Productos/Compras/Asistencia/Usuarios/Notificaciones cards. |
| Current Ventas parity | ❌ Incomplete | Flutter omits the visible payment-status badge and expanded registered-by, complete payment list, pending method, receipt, cash remainder, and account charge details. |
| Current Caja parity | ❌ Incomplete | Flutter manual Entrada/Salida accepts only amount and free-text concept; web also supports label selection and required staff selection for configured labels. |
| Recargo control | ⚠️ Partial | Core confidentiality and state changes work; annulment financial reversal is not proved. |
| Accounts/collections | ⚠️ Partial | Reads and collections work; account creation is absent. |
| Account-charged sales | ❌ Missing integration | DTO and repository seams exist, but no selector/create controls or account payload wiring is used by the sale screen. |
| Permission/PIN/stock | ❌ Missing integration | Permission and stock authorization repositories exist; permission editor and stock adjustment integration are absent. |
| Reports/email | ⚠️ Partial | General exports/email exist; cash-close export is unreachable and response metadata is lost. |
| Backups/files | ❌ Incorrect | Download integrity helper exists, but metadata/length handling and recoverable UI states do not satisfy specs. |
| Navigation/access | ✅ Implemented | Central deny-by-default policy and principal deep-link rules have passing tests. |

### Coherence (Design)

| Decision | Followed? | Notes |
|---|---|---|
| Feature-first vertical slices | ⚠️ Partial | Several slices stop at DTO/repository seams without production UI integration. |
| Consume authoritative backend fields; do not infer | ❌ No | Reports/backups ignore `Content-Disposition` and `Content-Type`; backups fabricate a filename. |
| Shared operation/error model | ⚠️ Partial | Applied in some modules; Backups uses booleans/string error and never renders the captured error. |
| Central access policy | ✅ Yes | Route policy and deep-link tests pass. |
| Platform file port with length/SHA verification | ❌ No | SHA is checked for backups, but `expectedLength`/`expectedSha256` on `FileArtifact` are not validated and native platform evidence is absent. |

### TDD Compliance

| Check | Result | Details |
|---|---|---|
| TDD evidence reported | ⚠️ | Table exists, but only tasks 3.5, 3.6, 4.1, 4.2, and 4.3 have rows; tasks 4.4/4.5 were later checked without updating it. |
| All tasks have test files | ⚠️ | Files are referenced for all work units, but final device evidence was not executed and multiple tests only exercise seams. |
| RED confirmed (tests exist) | ⚠️ | 5/5 table-row test files exist; 9 task rows lack primary-artifact evidence. |
| GREEN confirmed (tests pass) | ✅ | All 237 host tests pass, including every focused file listed in the TDD table. |
| Triangulation adequate | ⚠️ | Core DTO variants are triangulated; critical UI/device scenarios remain single-layer or absent. |
| Safety net for modified files | ⚠️ | WU10 declares N/A/new while also modifying shared API/router/navigation files; the table does not account for later WU11/WU12. |

**TDD Compliance**: 1/6 checks fully passed.

### Test Layer Distribution

| Layer | Tests | Files | Tools |
|---|---:|---:|---|
| Unit/repository/model (SDD-planned files) | 103 | 10 | `flutter_test` |
| Widget/component (within those files) | 5 | 3 | `flutter_test` |
| Device integration/E2E executed | 0 | 0 | `integration_test` available but not run |
| Device integration/E2E present | 1 | 1 | Credentialed, state-changing harness |

The full host suite executed 237 tests across 25 files. Device-critical behavior remains unproved despite host mocks.

### Changed File Coverage

| Scope | Covered / Found | Line % | Rating |
|---|---:|---:|---|
| 33 changed/new `lib/**/*.dart` files | 2527 / 4832 | 52.3% | ⚠️ Low |
| New report screen | 2 / 332 | 0.6% | ⚠️ Low |
| New backup screen | 2 / 209 | 1.0% | ⚠️ Low |
| New PIN management sheet | 0 / 133 | 0.0% | ⚠️ Low |
| Ventas history screen | 116 / 227 | 51.1% | ⚠️ Low |

Twenty of 33 changed production files are below 80% line coverage. Branch coverage is unavailable in LCOV output. The configured threshold is 0%, so the command passes despite weak changed-file coverage.

### Assertion Quality

| File | Line | Assertion | Issue | Severity |
|---|---:|---|---|---|
| `test/features/parity/web_parity_test.dart` | 216-220 | Manually throws when a locally computed hash differs from literal `wrong` | Does not call the production download/integrity workflow; the test proves its own conditional | CRITICAL |
| `test/features/parity/web_parity_test.dart` | 224-233 | Loops over a hard-coded route string list and asserts each starts with `/` | No production route registry is called; this cannot prove routes are declared | CRITICAL |
| `test/features/ventas/ventas_test.dart` | 792, 849 | `tester.tap(find.text('Selecciona una billetera…'))` | Runtime emitted hit-test miss warnings; the intended widget itself was not hit | WARNING |

**Assertion quality**: 2 CRITICAL, 1 WARNING.

### Quality Metrics

**Linter/type checker**: ⚠️ `flutter analyze` exited 1 with 225 warnings/informational diagnostics. Changed paths include an unused import in `api_client.dart`, dead/unreachable code in `caja_screen.dart`, protected-state access in `cuentas_screen.dart`, an unused import in `respaldos_screen.dart`, and an unused import in `web_parity_test.dart`.  
**Compiler/build**: ✅ Windows and Android release builds succeeded.  
**APK toolchain**: ⚠️ Flutter warned that `file_picker` and `mobile_scanner` still apply the Kotlin Gradle Plugin and will require migration.

### Issues Found

**CRITICAL**

1. **SUPERADMIN Dashboard is not web-parity compliant.** Flutter renders legacy operational KPIs rather than the web's seven authoritative financial KPIs. This directly reproduces the reported field/data mismatch.
2. **Ventas and account-charged sales are incomplete.** The history card lacks the visible `Pendiente` status and complete payment/account metadata; the sale UI never uses the implemented account selector or `cuentaId`/`cuentaMonto` payload seams.
3. **Account creation is absent.** There is no `POST /cuentas` repository method or create form, so two required account scenarios cannot run.
4. **Permission exceptions and PIN-authorized stock are not integrated.** Repository tests pass, but no permission editor calls `getPermissions`/`replacePermissions`, and production UI never calls `validatePin`/`adjustStock`.
5. **Report and backup file contracts are incorrect.** `ApiClient.getBytes` discards headers; report code always uses generic fallback metadata, backup code fabricates a filename, and cash-close export has no caller.
6. **Backup failure/partial states are misleading.** `_Notifier` stores one string error, but `RespaldosScreen` never renders it; failed loads can appear as editable defaults or empty successful history.
7. **Caja manual movement parity is incomplete.** Mobile cannot choose `etiquetaId` or required `personalUsuarioId`, while the authoritative web flow supports both.
8. **Android/Windows acceptance is unproved.** No safe credentialed device workflow or screenshots were executed; mock platform bridges do not satisfy device acceptance.
9. **Closure and Strict-TDD evidence are unreliable.** `tasks.md` says 14/14 while `apply-progress.md` says 12/14; the closure test contains two production-free assertions and does not prove the declared parity matrix.

**WARNING**

- `flutter analyze` exits 1 with 225 diagnostics.
- Two Ventas widget interactions emitted hit-test warnings despite a passing suite.
- APK build reports future Kotlin plugin incompatibility for two plugins.
- Flutter and web can target the same API via compile-time/environment override, but this verification intentionally did not prove deployed credential/data equality.
- Changed/new production files have 52.3% aggregate line coverage; critical report, backup, PIN, and parity screens are weakly covered.

**SUGGESTION**

- Replace DTO-only closure tests with widget/integration tests that drive production route registries, sale account controls, permission/stock actions, response-header metadata, and native file workflows.

### Verdict

**FAIL**

Builds and all 237 host tests pass, but the implementation does not satisfy normative mobile-web parity. Multiple required production UI flows are absent or incomplete, report/backup metadata contracts are wrong, and Android/Windows acceptance evidence is missing.
