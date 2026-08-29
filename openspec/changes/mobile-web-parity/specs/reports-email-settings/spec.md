# Reports and Email Settings Specification

## Purpose

Provide Superadmin report export and report-email administration.

## Requirements

### Requirement: Superadmin report access

Only role `SUPERADMIN` MAY access report UI or `/reportes/*` endpoints. Hidden navigation and route guards MUST be paired with backend authorization.

#### Scenario: Authorized or denied route
- GIVEN an authenticated user
- WHEN report navigation or a deep link is evaluated
- THEN `SUPERADMIN` may continue and every other role is denied

### Requirement: Exact report export

Mobile MUST call `GET /reportes/:tipo/exportar` where `tipo` is `ventas`, `movimientos`, or `ganancias`, using exact query fields `formato`, `fechaInicio`, `fechaFin`, and optional `sedeId`. `formato` is `xlsx`, `json`, or `txt`; dates MUST be `YYYY-MM-DD`.

#### Scenario: Export a report
- GIVEN a valid date range, optional backend venue UUID, and format
- WHEN generation succeeds
- THEN mobile uses returned content, content type, and server filename
- AND exposes generating and completion states

#### Scenario: Invalid or failed export
- GIVEN an inverted/invalid date range, invalid UUID, timeout, or server failure
- WHEN export is attempted
- THEN no completed file is claimed and a retryable error is shown

### Requirement: Cash-close export

Mobile MUST support `GET /reportes/cajas/:cajaId/ventas/exportar` with UUID `cajaId` and exact `formato` limited to `xlsx` or `json`.

#### Scenario: Export closed cash-session sales
- GIVEN a valid authorized cash session
- WHEN export succeeds
- THEN the returned private file is handed to platform file handling

#### Scenario: Missing or invalid cash session
- GIVEN invalid `cajaId`, unsupported format, or unavailable session
- WHEN backend rejects the request
- THEN mobile presents the backend error without creating a placeholder file

### Requirement: Email configuration and test delivery

Mobile MUST use `GET|PUT /reportes/email/configuration` and `POST /reportes/email/test`. Payloads MUST contain only `recipients`: 0–10 valid emails for update, or optional 1–10 valid emails for test. Responses MUST preserve `recipients`, `smtpConfigured`, `updatedAt`, `delivered`, `messageId`.

#### Scenario: Load and save settings
- GIVEN configuration is loading, empty, or populated
- WHEN valid unique normalized recipients are saved
- THEN returned configuration replaces local state and success is announced

#### Scenario: Test delivery fails or succeeds
- GIVEN SMTP and at least one effective recipient
- WHEN test delivery runs
- THEN mobile shows pending followed by delivered count or backend failure
- AND a failed test does not alter saved recipients
