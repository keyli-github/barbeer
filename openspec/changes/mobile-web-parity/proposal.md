# Proposal: Complete Mobile-Web Functional Parity

## Intent

Deliver Android/Windows parity for backend-authorized data, rules, actions, roles, and permissions through device-appropriate Flutter UI. Backend contracts and authorization govern; web informs interaction.

## Scope

### In Scope
- Preserve the 22-file responsive redesign; avoid broad redesign or reformatting.
- Deliver reviewable mobile slices with contract, route, UI/action, and verification evidence.
- Prioritize recargo, accounts/sales, permissions/PIN, reports, then backups.

### Out of Scope
- Any edit, test, commit, push, deployment, or contract correction in `C:\Users\key\backend_bar`, frontend/web, or the deployed server—even when a limitation blocks parity.
- Inferring omitted fields or recalculating historical totals; record the parity limitation and render only authoritative returned values.
- Desktop-layout replication on mobile.
- Removing, replacing, or silently reconciling protected local redesign work.

## Capabilities

### New Capabilities
- `mobile-web-contract-parity`: Exact fields, errors, loading/empty states, actions, and results across every audited current and new domain.
- `recargo-confidentiality-control`: Hidden state, Superadmin controls, confidential display, and preserved totals/payloads.
- `customer-accounts-collections`: Search, detail/history, creation, and partial/full collections.
- `account-charged-sales`: Account selection/charging, receipts, reconciliation, and annulment.
- `individual-permissions-pin-authorization`: User exceptions, Superadmin PIN lifecycle/validation, and sensitive stock authorization.
- `reports-email-settings`: Superadmin exports, email configuration, and test delivery.
- `administrative-backups`: Permission-gated schedules, history, execution, and private downloads.
- `android-windows-file-handling`: Platform-correct export/backup saving and opening.
- `role-aware-navigation-access`: Exact route visibility, guards, roles, permissions, and authorized mutations.

### Modified Capabilities
None; `openspec/specs/` has no existing specifications.

## Approach

Consume the current backend contract as-is. Test invariants first; implement mobile-only slices at protected seams. Never mix responsive redesign with capability work.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `lib/core/{constants,routes,navigation}/` | Modified | Endpoints, guarded routes, destinations |
| `lib/features/{ventas,usuarios,productos,inventario}/` | Modified | Parity integrations |
| `lib/features/{cuentas,reportes,respaldos}/` | New | Missing vertical modules |
| `test/features/parity/`, `integration_test/` | Modified | Contract and workflow evidence |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Dirty-work collision | High | Isolate seams; never reset/format unrelated files |
| Financial/authorization regression | High | Contract tests; backend remains authority |
| Platform downloads fail | Medium | Verify on Android and Windows |

## Rollback Plan

Revert slices independently, removing only their route/navigation exposure. No data migration or protected redesign rollback.

## Dependencies

- Read-only current backend contracts, test roles, Android/Windows devices, protected baseline, and verification API URL.

## Success Criteria

- [ ] 100% of audited domains satisfy the parity matrix with no unexplained divergence.
- [ ] Each capability has contract and permission tests, including error/loading/empty states.
- [ ] Critical workflows pass on Android and Windows.
- [ ] No protected work is lost; slices meet the review budget or use approved chaining.
