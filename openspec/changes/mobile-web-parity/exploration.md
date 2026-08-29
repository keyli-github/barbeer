# Exploration: Mobile-Web Functional Parity

## Exploration: mobile-web-parity

### Current State
The comparison used fixed repository baselines: mobile `a0563791f7303ea6470a383dbb0fdb3d084ed1e0`, web `7188fa0fd06bdf5bcd93f425ec07a80a2014d8cf`, and backend `077d9cb77948af863f8749174f923301709ec5ce`. Backend authorization and DTO behavior are authoritative; the web application is the product and interaction reference.

The committed Flutter application already follows a feature-first architecture with Riverpod, `go_router`, and Dio. It covers authentication, profile/security, remote branding, dashboard, users, roles, permissions, branches, audit, products, categories, inventory, Kardex, purchases/providers, attendance/turnos/QR, sales, cash register, movements, and labels. Existing parity tests protect selected contract details such as `codigoSede`, nested role permissions, audit dates, password rules, and Kardex semantics.

The mobile worktree contains 22 modified tracked files and the untracked `responsive_helper.dart` (1,860 additions and 2,806 deletions). These changes primarily redesign responsive presentation and do not add routes or API constants for the missing domains. The only confirmed configuration behavior change is that `ApiConstants.baseUrl` now defaults to production in non-product builds. The matrix therefore treats worktree UI changes separately from committed capability coverage.

| Domain/capability | Backend and web reference | Mobile `HEAD` | Dirty worktree effect | Classification |
|---|---|---|---|---|
| Authentication, profile, sessions, security | Login, refresh, forced password change, profile, session revocation | Present | Login/password screens redesigned | aligned |
| Branding | Public branding plus Superadmin logo/cover mutation | Present and reachable from Profile for Superadmin | Profile layout adjusted | aligned |
| Dashboard | Aggregated operational summaries with explicit module failures | Present; contract-focused tests exist | Major responsive rewrite | partial |
| Users | CRUD, reset password, individual permission exceptions, Superadmin PIN management/validation | CRUD and reset only; no user-permission or PIN endpoints/constants | No capability added | partial |
| Roles and permission catalog | Role permission assignment and grouped permission catalog | Present | Permissions screen styling only | aligned |
| Branches and audit | Branch CRUD and filtered audit history | Present | Responsive presentation changes | aligned |
| Products and stock authorization | Product CRUD, images, availability, stock actions; exceptional stock reductions require Superadmin PIN | Product/catalog flows exist; no PIN field or authorization flow found | Product screen presentation changed | partial |
| Categories and labels | CRUD/state management and sale usage | Present | Category screen styling only | aligned |
| Inventory and Kardex | Configuration, adjustments, summaries, stock movement history | Present | Responsive presentation changes | aligned, except PIN-assisted stock adjustment |
| Purchases and providers | Provider CRUD, purchase lifecycle, detail and summaries | Present | Responsive presentation changes | aligned |
| Attendance and shifts | Employee QR marking plus privileged management | Present | Responsive presentation changes | aligned |
| Sales and receipts | Idempotent sale creation, receipt analysis, reconciliation, annulment, account charging, recargo accounting | Core sale/receipt flows exist; account charging is absent | Sales screens redesigned, but missing capabilities remain | partial |
| Recargo visibility/control | Authenticated hidden-state endpoint, Superadmin configuration, controlled toggle; web hides normal recargo details while retaining totals and payload fields | No control endpoints/store; committed and dirty UIs expose amount, reason, and subtotal | No parity fix | divergent |
| Cash register and movements | Open/pre-close/close, reconciliation, history, operational movement views | Present | Responsive presentation changes | aligned |
| Customer accounts/collections | List/search, selector, detail/history, creation, partial/full payment; sales can charge accounts | No feature, route, navigation entry, API constant, model, or sale payload fields | No capability added | missing |
| Reports and email settings | Superadmin exports plus report-email configuration and test delivery | No feature, route, navigation entry, or API constants | No capability added | missing |
| Administrative backups | Permission-gated schedule, run history, and private artifact downloads | No feature, route, navigation entry, or API constants | No capability added | missing |
| Runtime API selection | Build-time `API_BASE_URL`, local development fallback, production endpoint | Committed build distinguishes debug/local and product/production | Dirty default always targets production | divergent (dirty only) |

Key contract mismatches are structural rather than cosmetic:

- Mobile sale payloads contain recargo fields but omit `cuentaId`/account amount fields required for web-equivalent account charging.
- Mobile exposes recargo amount, reason, and subtotal in normal sale views, while the web deliberately suppresses those details and preserves only the total and submission fields.
- Mobile has no clients for `/recargo-control/*`, `/cuentas/*`, `/reportes/*`, or `/backups/*`.
- Mobile user administration does not call `/usuarios/:id/permisos`, `/usuarios/superadmin-pins`, `/usuarios/:id/superadmin-pin`, or `/usuarios/validate-pin`.
- Backend pagination and DTO validation remain authoritative: new clients must use backend names such as `pagina`, `limite`, `codigoSede`, and `costoUnit`, and must not send undeclared fields.

### Affected Areas
- `lib/core/constants/api_constants.dart` — needs missing domain endpoints, but its protected dirty base-URL change must be resolved independently.
- `lib/core/routes/route_paths.dart` — lacks accounts, reports, and backups routes.
- `lib/core/routes/app_router.dart` — requires guarded route registrations for missing modules.
- `lib/core/navigation/app_destinations.dart` — requires backend-aligned permission visibility for new destinations.
- `lib/features/ventas/` — needs account charging and web-equivalent recargo visibility/control without breaking idempotency or totals.
- `lib/features/usuarios/presentation/screens/usuarios_screen.dart` — lacks individual permission and Superadmin PIN workflows.
- `lib/features/productos/` and `lib/features/inventario/` — need backend-authorized PIN-assisted stock behavior where applicable.
- `lib/features/cuentas/` — new bounded feature for account list, detail, creation, payments, and sale selector integration.
- `lib/features/reportes/` — new Superadmin export/email-settings feature with platform-aware file handling.
- `lib/features/respaldos/` — new permission-gated schedule/history/download feature mapped to backend `/backups`.
- `test/features/parity/web_parity_test.dart` — should expand from selected contract checks to missing-domain and visibility invariants.
- `integration_test/acceptance_test.dart` — should cover role-visible navigation and critical vertical workflows when credentials/devices are available.

### Approaches
1. **Vertical capability slices** — implement one backend-authorized user journey at a time, keeping its model/repository tests, route, UI, and permission behavior together.
   - Pros: Produces reviewable value, isolates regressions, respects the 400-line budget, and avoids broad conflicts with the protected responsive work.
   - Cons: Shared navigation and API constants evolve incrementally; full parity arrives over several slices.
   - Effort: High overall, Medium per slice

2. **Horizontal foundation first** — add all missing endpoints, models, repositories, routes, and navigation before building screens.
   - Pros: Establishes a complete client contract layer early and can reveal backend mapping errors quickly.
   - Cons: Creates a large invisible change, leaves dead routes/data code temporarily, and is likely to exceed the review budget before any workflow is usable.
   - Effort: High

3. **Single parity rewrite** — reconcile all screens and domains in one coordinated implementation.
   - Pros: One release boundary and one final parity audit.
   - Cons: Unreviewable scope, high regression risk, severe collision risk with 4,666 lines of existing mobile worktree churn, and poor rollback isolation.
   - Effort: Very High

### Recommendation
Use vertical capability slices and first freeze behavioral invariants with tests. The first corrective slice should align recargo visibility without changing stored totals or payload fields. Then introduce accounts because it is both a missing module and a dependency of complete sales parity: (1) account models/repository tests, (2) list/detail route and permission navigation, (3) create/payment actions, and (4) sale selector/payload integration. Follow with user permission/PIN workflows, then reports and backups as separate download-oriented slices.

Keep every slice near or below 400 changed lines and do not mix responsive redesign reconciliation with new domain behavior. Treat the current dirty screens as protected input: rebase or merge capability work only after the owner decides whether those UI changes become the new visual baseline. Suggested review units are recargo invariants, accounts data layer, accounts read UI, accounts mutations, sales-account integration, user permissions, PIN authorization, reports export, report email settings, backup schedule/history, and backup download.

### Risks
- Existing uncommitted mobile changes overlap many target screens; direct implementation now could overwrite or entangle user-authored work.
- Recargo data is financially significant even when hidden; a visual parity change must preserve totals, idempotency, cash movements, and submission fields.
- Account payments affect sales, cash movements, receipts, reconciliation, and annulment, so incomplete client support can create inconsistent operator workflows.
- Reports and backups require Android/Windows file-save and download behavior that is not proven by current tests.
- Route visibility is only UX; every mutation must continue relying on backend role/permission enforcement and normalized API errors.
- Integration coverage requires devices and credentials that are not available in the detected local test capability report.
- The dirty production-default API URL can make development tests target shared infrastructure unless explicitly overridden.

### Ready for Proposal
Yes. The proposal should define parity as a sequence of contract-backed vertical capabilities, preserve the protected mobile worktree, establish web-equivalent recargo confidentiality as the first behavior correction, and plan accounts, advanced user administration, reports, and backups as independent reviewable changes or chained slices.
