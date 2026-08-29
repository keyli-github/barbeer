# Role-Aware Navigation and Access Specification

## Purpose

Align mobile navigation, deep-link guards, action visibility, and backend-authorized mutations.

## Requirements

### Requirement: Navigation mirrors effective authorization

Mobile MUST derive navigation from authenticated `rol` plus effective `permisos`. Dashboard, profile, security, and attendance scanner remain authenticated routes; other current destinations retain their exact backend permission checks. Unknown protected routes MUST default to hidden/denied.

#### Scenario: Existing destination matrix
- GIVEN any canonical role and effective permission fixture
- WHEN destinations are built
- THEN sales, cash/movements, products, categories, inventory, Kardex, purchases, labels, users, branches, roles, permissions, and audit match their declared backend permissions

#### Scenario: Permissions change after refresh
- GIVEN an individual permission is granted or revoked
- WHEN the session/effective permissions refresh
- THEN navigation and action visibility update without retaining stale access

### Requirement: New route rules

Accounts list/detail MUST require role `SUPERADMIN` or `ADMIN` plus `cuentas:leer`; reports MUST require `SUPERADMIN`; backups MUST require `respaldos:gestionar`. The sale account selector MAY appear with `cuentas:crear` or `ventas:crear`. Recargo controls MUST follow returned `puedeConfigurar` and `puedeCambiar`.

#### Scenario: Authorized visibility
- GIVEN the exact role and permissions for a new capability
- WHEN navigation and contextual actions render
- THEN only its authorized route/action is visible

#### Scenario: Role conflicts with permission
- GIVEN a user has `cuentas:leer` but is not `SUPERADMIN` or `ADMIN`
- WHEN accounts navigation or deep link is evaluated
- THEN access is denied despite the permission string

### Requirement: Deep-link and loading guards

Mobile MUST defer protected-route decisions while authentication/effective permissions load, redirect unauthenticated users to login, enforce forced password change, and route authenticated denials to a non-sensitive unauthorized state.

#### Scenario: Guard state transition
- GIVEN app bootstrap is unresolved, expired, forced-change, or authorized
- WHEN a protected deep link opens
- THEN mobile respectively waits, requests login, requires password change, or enters the route

#### Scenario: Direct unauthorized route
- GIVEN an authenticated user lacks access
- WHEN the route is entered directly
- THEN no protected content/request is shown before denial

### Requirement: Backend remains mutation authority

Hidden buttons and route guards MUST NOT be treated as security. Every read and mutation SHALL be sent only when UI authorization allows it, and mobile MUST still handle backend 401/403/404 scope-safe responses without optimistic success.

#### Scenario: Stale client authorization
- GIVEN mobile shows an action from stale permissions
- WHEN backend returns 403
- THEN mobile reverts pending UI state, shows denial, and refreshes authorization

#### Scenario: Authorized mutation changes state
- GIVEN UI and backend both authorize an operation
- WHEN backend succeeds
- THEN only the returned state becomes authoritative
- AND role/permission metadata is never added to the domain payload
