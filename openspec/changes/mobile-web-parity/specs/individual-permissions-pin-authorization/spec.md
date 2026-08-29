# Individual Permissions and PIN Authorization Specification

## Purpose

Support per-user permission exceptions and backend-authorized sensitive stock actions.

## Requirements

### Requirement: Effective permission model

Users with `usuarios:leer` MUST load `GET /usuarios/:id/permisos` and distinguish `permisosPorRol`, `permisosAdicionales`, `permisosRevocados`, and `permisosEfectivos` fields `porRol`, `adicional`, `revocado`, and `activo`.

#### Scenario: Load permission exceptions
- GIVEN an authorized user target
- WHEN permissions load
- THEN inherited, granted, revoked, and effective states remain distinguishable

#### Scenario: Loading or missing target
- GIVEN permission data is pending or target returns 404
- WHEN the editor opens
- THEN mutation controls remain unavailable and the error is recoverable

### Requirement: Atomic permission replacement

Only backend-authorized `SUPERADMIN` users MAY mutate individual exceptions. Mobile SHOULD use `PUT /usuarios/:id/permisos` with exact arrays `permisoIds` and `permisoIdsRevocados`; neither array MAY contain duplicates or the same ID in both.

#### Scenario: Save valid exceptions
- GIVEN catalog IDs separate additions from inherited revocations
- WHEN replacement succeeds
- THEN the returned effective model replaces local state atomically

#### Scenario: Invalid or denied replacement
- GIVEN an unknown ID, revocation of a non-inherited permission, or non-Superadmin actor
- WHEN submitted
- THEN backend 400/403 is shown and prior effective state remains

### Requirement: Superadmin PIN lifecycle

PIN management MUST use exact fields `superadminPin` and `pinAutoGenerate`. Manual PINs MUST be exactly four digits; only `SUPERADMIN` MAY manage or view permitted PIN state, and hashed manual PINs MUST NOT be exposed.

#### Scenario: Configure PIN mode
- GIVEN a `SUPERADMIN` selects manual or automatic mode
- WHEN `PATCH /usuarios/:id/superadmin-pin` succeeds
- THEN mobile refreshes `tienePin`, `currentPin`, and `pinAutoGenerate`

#### Scenario: PIN management denied
- GIVEN a non-Superadmin or invalid PIN format
- WHEN management is attempted
- THEN mobile shows backend 403 or validation and exposes no PIN secret

### Requirement: PIN validation

Authenticated PIN checks MUST call `POST /usuarios/validate-pin` with only `pin`. Mobile MUST treat only `success: true` as authorization and MUST preserve backend attempt throttling.

#### Scenario: Valid, invalid, or throttled PIN
- GIVEN a four-digit PIN is entered
- WHEN backend returns success, false, or 429
- THEN mobile respectively continues, denies, or locks retry until instructed
- AND never logs or persists the PIN

### Requirement: Sensitive stock authorization

`POST /productos/:id/stock` MUST send only `sedeId`, `tipo`, `cantidad`, `referencia`, and `superadminPin` as applicable. Non-Superadmins MUST provide a four-digit `superadminPin` and nonblank `referencia`; `tipo` is `ENTRADA` or `SALIDA` and `cantidad` MUST be positive.

#### Scenario: Authorized stock transition
- GIVEN valid PIN, reference, product, sede, and nonnegative resulting stock
- WHEN adjustment succeeds
- THEN returned `productoId`, `sedeId`, `stock`, `tipo`, and `cantidad` replace local stock

#### Scenario: Stock authorization fails
- GIVEN missing/wrong PIN, missing reference, or negative resulting stock
- WHEN backend rejects the request
- THEN stock remains unchanged and the exact error is shown
