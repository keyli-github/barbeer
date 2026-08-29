# Administrative Backups Specification

## Purpose

Expose permission-gated schedules, execution history, and private artifacts.

## Requirements

### Requirement: Backup authorization and scope

Every `/backups/*` request MUST require `respaldos:gestionar`; mobile route visibility and guards MUST use that permission. Backend scope SHALL remain `global` for `SUPERADMIN` and the token's sede for other authorized users.

#### Scenario: Authorized or denied access
- GIVEN an authenticated user
- WHEN backup route or API access is evaluated
- THEN only users with `respaldos:gestionar` proceed
- AND a user without required sede receives backend 403

### Requirement: Schedule lifecycle

Mobile MUST use `GET|PUT /backups/schedule`. Updates MUST contain only `enabled`, `frequency`, and `formats`; frequency is `DAILY`, `WEEKLY`, or `MONTHLY`, and `formats` contains 1–3 unique values from `XLSX`, `JSON`, `TXT`.

#### Scenario: Load empty/default schedule
- GIVEN no persisted schedule
- WHEN retrieval succeeds
- THEN mobile renders backend defaults, `timezone`, null dates, and disabled state

#### Scenario: Save or reject schedule
- GIVEN valid or invalid schedule values
- WHEN update completes
- THEN returned `nextRunAt` and state replace local values on success
- AND validation failure preserves the editable draft

### Requirement: Execution history and transitions

Mobile MUST list `GET /backups/runs` using exact query fields `page` and `limit` and response fields `data`, `total`, `page`, `limit`, `totalPages`. It MUST represent `PENDING`, `RUNNING`, `SUCCEEDED`, and `FAILED`, including attempts, dates, `lastError`, totals, and artifacts. There is no manual-run endpoint; execution MUST NOT be invented.

#### Scenario: Scheduled execution progresses
- GIVEN an enabled schedule reaches `nextRunAt`
- WHEN history is refreshed
- THEN server transitions and artifacts are rendered without client fabrication

#### Scenario: Empty, partial, or failed history
- GIVEN no runs, a failed run, or one of the initial schedule/history requests fails
- WHEN the page settles
- THEN mobile shows empty history, run failure details, or retryable partial error respectively

### Requirement: Private artifact download

Mobile MUST request `GET /backups/runs/:runId/artifacts/:format` using a UUID and declared format. It MUST use server filename/content type and MUST NOT expose an artifact before backend scope, size, storage, and integrity checks succeed.

#### Scenario: Download verified artifact
- GIVEN a `SUCCEEDED` run exposes an artifact
- WHEN the authorized download succeeds
- THEN it is passed to platform file handling and completion is announced

#### Scenario: Download rejected
- GIVEN foreign scope, missing artifact, excessive size, integrity failure, or transport error
- WHEN download fails
- THEN no successful save is claimed and backend-safe error/retry state is shown
