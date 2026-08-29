# Customer Accounts and Collections Specification

## Purpose

Provide backend-scoped customer accounts, debt history, creation, and collections.

## Requirements

### Requirement: Account search and scope

Authorized mobile users MUST use `GET /cuentas` with only `search` and `sedeId`. List access requires `cuentas:leer` and role `SUPERADMIN` or `ADMIN`; `SUPERADMIN` MUST select `sedeId`, while other users MUST remain in their token sede.

#### Scenario: Search active debtors
- GIVEN an authorized user and effective sede
- WHEN a name or document `search` completes
- THEN results expose exact fields `id`, `nombre`, `documento`, `telefono`, `saldo`, `activo`, `cantidadPendientes`, `createdAt`, and `updatedAt`

#### Scenario: Empty, loading, or denied list
- GIVEN the account route is opened
- WHEN data is loading, empty, or backend returns 403
- THEN each state is distinct and no stale foreign-sede result is shown

### Requirement: Account detail and history

Mobile MUST use `GET /cuentas/:id` with `sedeId` and render `movimientos` plus `pendientes`, including exact sale/item fields. Recargo detail in pending sales MUST obey recargo confidentiality.

#### Scenario: Load detail
- GIVEN an existing scoped account
- WHEN detail succeeds
- THEN balance, movements, and up to the returned pending sales render
- AND a newer selection cannot be overwritten by an older response

#### Scenario: Missing account
- GIVEN an unknown account UUID
- WHEN detail returns 404 `La cuenta no existe`
- THEN mobile clears the unavailable detail and presents the error

### Requirement: Account creation

Users with `cuentas:crear` MUST create through `POST /cuentas` using only `nombre`, optional `documento`, and optional `telefono`; limits are 100, 20, and 20 characters respectively.

#### Scenario: Create an account
- GIVEN valid customer values
- WHEN creation succeeds
- THEN the returned account becomes selectable without fabricated fields

#### Scenario: Duplicate or invalid account
- GIVEN a duplicate name, blank `nombre`, or over-limit field
- WHEN submitted
- THEN backend validation/conflict is shown and the form remains editable

### Requirement: Partial and full collections

Users with `cuentas:editar` and role `SUPERADMIN` or `ADMIN` MUST call `POST /cuentas/:id/pagos` using only `monto`, `medioPago`, `idempotencyKey`, optional `comprobanteAnalisisId`, and optional `sedeId`.

#### Scenario: Apply a collection
- GIVEN the current user owns an open V2 cash session
- WHEN a valid partial or full payment succeeds
- THEN returned balance/history replace local values
- AND the same `idempotencyKey` is reused after uncertain delivery

#### Scenario: Transfer or accounting rejection
- GIVEN transfer evidence is absent/invalid, payment exceeds sede balance, or cash ownership fails
- WHEN payment is submitted
- THEN the exact 400, 403, 404, or 409 error is shown
- AND no optimistic balance is committed
