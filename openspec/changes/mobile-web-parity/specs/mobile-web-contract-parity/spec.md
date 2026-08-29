# Mobile-Web Contract Parity Specification

## Purpose

Define normative closure of mobile parity against backend contracts and web product behavior.

## Requirements

### Requirement: Exact API contracts

Mobile MUST use backend endpoint, HTTP method, path, query, body, and response field names exactly. It MUST NOT send mobile-only aliases or undeclared fields; collection contracts MUST retain backend names such as `pagina`, `limite`, `codigoSede`, and `costoUnit`.

#### Scenario: Exact request and response mapping
- GIVEN an audited endpoint and valid backend fixture
- WHEN mobile sends and parses the operation
- THEN every transported name and value matches the backend contract
- AND no alias or undeclared payload field is present

#### Scenario: Backend rejects an invalid contract
- GIVEN a request containing an unknown field or invalid value
- WHEN backend validation returns an error
- THEN mobile shows the normalized `message` without retrying as success
- AND preserves `statusCode`, `path`, and any declared error `code`

### Requirement: Deterministic async states

Every audited screen MUST expose distinguishable loading, content, empty, recoverable error, and partial-result states where its endpoint can produce them.

#### Scenario: Empty and retry states
- GIVEN a valid authorized request
- WHEN it returns no records or fails
- THEN mobile shows an empty state or actionable error respectively
- AND retry does not duplicate a prior mutation

#### Scenario: Partial dashboard response
- GIVEN dashboard data with explicit module errors
- WHEN successful modules render
- THEN mobile retains each failed module error
- AND MUST NOT represent the aggregate as fully successful

### Requirement: Current-module parity remains normative

The parity matrix MUST include authentication/profile/sessions/security, branding, dashboard, users, roles/permissions, branches/audit, products/categories, inventory/Kardex, purchases/providers, attendance/shifts/QR, sales/receipts, cash/movements, and labels. Existing exact behaviors including nested permission IDs, civil audit dates, password policy, `codigoSede`, Kardex types, and scoped utility fields MUST remain covered.

#### Scenario: Existing module regression
- GIVEN a currently audited module
- WHEN its parity suite runs after a new capability is added
- THEN its contract, authorization, loading, empty, and error assertions still pass

### Requirement: Normative parity closure

A domain SHALL be marked complete only when its matrix records backend contract evidence, web behavior evidence, mobile behavior, role/permission coverage, Android and Windows result, and no unexplained divergence.

#### Scenario: Close the parity matrix
- GIVEN all declared capabilities and current modules
- WHEN evidence is reviewed
- THEN 100% have passing normative rows or an explicit blocker
- AND visual layout differences alone are not divergences

#### Scenario: Source conflict
- GIVEN backend authorization conflicts with web presentation
- WHEN expected behavior is resolved
- THEN backend contract and authorization win
- AND mobile does not require a backend or web behavior change
