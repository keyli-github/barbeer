# Android and Windows File Handling Specification

## Purpose

Define user-verifiable handling of report and backup downloads on both target platforms.

## Requirements

### Requirement: Preserve authoritative file metadata

Downloaded reports and backups MUST retain server-provided filename, bytes, and content type. A documented endpoint-specific fallback filename MAY be used only when `Content-Disposition` omits a filename; mobile MUST NOT change file format or content.

#### Scenario: Server names the file
- GIVEN a successful response with filename and content type
- WHEN Android or Windows handles the download
- THEN the saved/opened artifact retains both values and exact bytes

#### Scenario: Filename is absent
- GIVEN valid content without a server filename
- WHEN the file workflow starts
- THEN the declared report/backup fallback is used
- AND the user is informed of the resulting name

### Requirement: Platform-appropriate completion

On Android and Windows, mobile SHALL provide a platform-appropriate user-confirmed save destination or accessible saved result and SHOULD offer opening the completed file when the platform supports its type. It MUST NOT claim success before durable handoff completes.

#### Scenario: Android completion
- GIVEN an Android user accepts the file workflow
- WHEN saving completes
- THEN mobile identifies the saved result and offers a supported next action

#### Scenario: Windows completion
- GIVEN a Windows user confirms a valid destination
- WHEN saving completes
- THEN mobile identifies the final path/result and may open the file

#### Scenario: User cancels
- GIVEN a save/open choice is presented
- WHEN the user cancels
- THEN mobile returns to the source screen without error or success claim

### Requirement: Failure and retry safety

Mobile MUST distinguish generation/download failure, permission or destination denial, insufficient space, write failure, and unsupported open action where the platform reports them. Retrying a save MUST NOT repeat the originating financial or administrative mutation.

#### Scenario: Save fails after download
- GIVEN valid bytes were downloaded but persistence fails
- WHEN the platform reports failure
- THEN mobile retains a retry path where safe and reports no saved file

#### Scenario: Open is unsupported
- GIVEN a file was saved successfully but cannot be opened
- WHEN open is requested
- THEN mobile preserves the saved-file success and reports only the open failure
