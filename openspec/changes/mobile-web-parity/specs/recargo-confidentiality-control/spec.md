# Recargo Confidentiality Control Specification

## Purpose

Protect recargo detail without changing valid sale totals, payloads, or accounting.

## Requirements

### Requirement: Authoritative recargo state

Authenticated clients MUST read `GET /recargo-control/estado` fields `oculto`, `configurado`, `puedeConfigurar`, and `puedeCambiar`. Only `SUPERADMIN` MAY read or update `/recargo-control/configuracion`; only `SUPERADMIN` or the assigned active user for the user's `sedeId` MAY call `POST /recargo-control/cambiar`.

#### Scenario: Authorized state change
- GIVEN `puedeCambiar` is true and `clave` is valid
- WHEN `{clave, oculto}` is submitted
- THEN mobile applies the returned `oculto` state everywhere

#### Scenario: Denied or throttled change
- GIVEN an unassigned user, wrong `clave`, or too many attempts
- WHEN the state change is submitted
- THEN mobile presents the backend 403, 401, or 429 error
- AND the prior state remains active

### Requirement: Complete configuration

Configuration MUST submit only optional `clave` and `responsables[{sedeId, usuarioId}]`; `clave` MUST contain 6–64 characters, and every active sede MUST have exactly one active user from that sede.

#### Scenario: Save valid configuration
- GIVEN a `SUPERADMIN` supplies all active-sede assignments
- WHEN configuration succeeds
- THEN the returned sedes and `responsableId` values replace local state

#### Scenario: Invalid assignment
- GIVEN a missing sede, foreign-sede user, or missing initial `clave`
- WHEN save is attempted
- THEN validation is shown and no success state is emitted

### Requirement: Confidential sale presentation

When a valid sale contains `recargoMonto` and `recargoMotivo`, normal sale confirmation and review MUST show the final payable total while hiding the standalone recargo amount, reason, and subtotal breakdown. An authorized edit control MAY reveal the details transiently; confirmation MUST retain the exact fields and values.

#### Scenario: Confirm a recargo sale
- GIVEN items total 10 and an allowed recargo of 5
- WHEN the operator confirms the sale
- THEN the normal view shows total 15 without recargo detail
- AND payload still contains `recargoMonto: 5` and `recargoMotivo`

### Requirement: Hidden-state financial invariants

While `oculto` is true, mobile MUST NOT offer or submit a new positive `recargoMonto`. Existing persisted recargos MUST retain sale totals, idempotency identity, cash movements, reconciliation, account balances, receipts, and annulment reversals; hiding MUST NOT delete or recalculate financial data.

#### Scenario: Hidden state blocks a new recargo
- GIVEN `oculto` becomes true during a draft
- WHEN the draft is reviewed or submitted
- THEN recargo editing and new recargo fields are unavailable
- AND backend rejection is surfaced if a stale client submits them

#### Scenario: Existing sale is annulled
- GIVEN a stored sale has recargo accounting
- WHEN an authorized annulment succeeds
- THEN backend reversal results are rendered
- AND confidential recargo detail remains hidden
