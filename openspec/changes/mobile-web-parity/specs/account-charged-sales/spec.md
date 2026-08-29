# Account-Charged Sales Specification

## Purpose

Integrate customer-account charging into sale, receipt, reconciliation, and annulment behavior.

## Requirements

### Requirement: Sale account selector

Users with `cuentas:crear` or `ventas:crear` MAY query `GET /cuentas/selector` with only optional `search` and `sedeId`. Mobile MUST expose returned `esPersonal`, `saldo`, and `cantidadPendientes` without granting account-management access.

#### Scenario: Select or create an account
- GIVEN an authorized sale and effective sede
- WHEN the operator searches or creates a customer account
- THEN the selected backend `id` is retained for the draft

#### Scenario: Empty or failed selector
- GIVEN no matches or a request failure
- WHEN selector loading ends
- THEN mobile shows empty or retry state and does not invent an account

### Requirement: Exact charged-sale payload

A charged sale MUST use `POST /ventas` fields `cuentaId` and positive `cuentaMonto` alongside the existing `idempotencyKey`, `items`, payment, receipt, and recargo fields. `cuentaMonto` MUST have at most two decimals and MUST NOT be sent without `cuentaId`.

#### Scenario: Charge part or all to account
- GIVEN an active account and a valid sale total
- WHEN the sale is confirmed
- THEN payload contains exact `cuentaId` and `cuentaMonto`
- AND backend total-coverage and idempotency rules remain authoritative

#### Scenario: Backend rejects account charge
- GIVEN an inactive account, non-positive amount, underpayment, or mismatched idempotency payload
- WHEN submission fails
- THEN mobile shows the backend message/code and preserves the draft

### Requirement: Charged-sale results

Sale history and detail MUST parse exact response fields `cuentaId`, `cuenta`, and `cuentaMonto`; receipts and reconciliation MUST represent the backend result without recalculating account or recargo accounting.

#### Scenario: Load charged receipt
- GIVEN a sale has an account charge
- WHEN its detail loads
- THEN customer name and remaining charged amount are distinguishable from cash and transfer amounts

#### Scenario: Refresh fails after creation
- GIVEN sale creation already succeeded
- WHEN a subsequent stock, receipt, or account refresh fails
- THEN mobile reports a partial refresh failure
- AND MUST NOT resubmit the sale with a new `idempotencyKey`

### Requirement: Annulment reverses account effects

Authorized `POST /ventas/:id/anular` MUST submit only `motivo`. Mobile SHALL render the backend state transition and MUST NOT locally mutate balances before success.

#### Scenario: Annul charged sale
- GIVEN an authorized active sale in an open V2 cash session
- WHEN annulment succeeds
- THEN sale becomes `ANULADA` and refreshed account/cash/Kardex results show backend reversals

#### Scenario: Annulment cannot proceed
- GIVEN a closed cash session, V1 session, prior annulment, or insufficient authority
- WHEN annulment returns 403, 409, or 422
- THEN no local sale, stock, or account state is reversed
