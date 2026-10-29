# Mobile API adapter contract

## Focused forms and first use — 29 October 2026

Request details, material selection and workflow date/time fields have separate presentation components. The parent retains controllers, draft restoration, command identity and submission rules. The expandable Review details summary follows edits; end-date selection starts at the chosen start date and safely opens for recovered dates without changing them until a selection is made.

Public Help and getting started is reachable from sign-in and Profile. It explains HR-provided workspace/account access, first workday navigation, location permissions, drafts and unconfirmed actions. Remote setup shows HR assistance instead of invoking the pending tenant-creation route. Local demo setup remains available and is labelled as demo behavior. No adapter, server policy, contract, storage or event changed. Private linked-account provisioning remains an operator task; public account creation and email password recovery are not claimed.

## Usability polish checkpoint — 29 October 2026

Request forms reveal the first invalid field and keep announced, scrollable error feedback beside the keyboard-safe action. Existing calendar-year leave policy is explained before submission. While submission awaits the owner leave preview, the busy state prevents repeated taps and edits; a failed preview preserves entries. The draft-edit page now has a separate cohesive file without increasing structure limits. Empty filtered lists offer Clear filters, including cancelling any pending search timer. Notifications add unread-filter recovery, text read state and an explanation for unsupported destinations. Role count grammar and attendance-read failure wording are corrected. Saved-data notices use task labels and retain their timestamps without exposing technical paths. Shared loading states respect reduced motion, and recoverable read failures expose a live error region. No adapter, schema or business policy changed. Root Week 08 evidence records macOS/Linux checks; physical-device, assistive-technology and Khmer acceptance remain outstanding.

## Client UX follow-up — 29 October 2026

Primary navigation now uses Attendance and Tasks, and record detail routes select the corresponding parent destination. The Tasks hub omits service-readiness and report-recovery entries. Role work cards keep approval-read failures visible and provide direct team, people and owner audit links. Leave and attendance-correction labels are aligned with web. Missing decision context is displayed as unavailable rather than a count of zero.

Request forms now compose a dedicated FormActions bar outside the scrolling fields. Its keyboard inset keeps Save request draft/Send for approval visible on a 320px phone with enlarged text and an open keyboard. Existing validation, uncertain command identity, form-draft support and unsaved-change guards remain in the owner form. Repeated snackbars replace the previous notification. Intentional visual changes require reviewed light/dark golden updates on each supported test platform.

The shared component matrix is maintained in `web/docs/MOBILE-ALIGNMENT.md` in the coordinated checkout. The existing private file, request, leave, notification and attendance adapters were not changed. Earlier provider/APK evidence remains dated; this pass adds UI checks and does not establish device, gateway, Khmer localization or deployment acceptance. The root Week 08 evidence records the current UX checks and remaining limits.

24 October 2026. This is the contract consumed by the current mobile adapter. It is a handover specification, not the canonical server OpenAPI and not proof of compatibility with the historical reference examples. Publish/accept the backend schema, then update the owning `lib/features/<feature>/data/` repository, routes and mappers where fields or routes differ. Do not change screen code to accommodate transport DTOs.

## Select remote mode

```bash
fvm flutter run \
  --dart-define=DATA_SOURCE=remote \
  --dart-define=API_BASE_URL=https://hr.example.com/api/v1 \
  --dart-define=FILE_ORIGINS=https://files.example.com
```

The absolute base must end in `/api/v1`; a deployment prefix and optional trailing slash are supported. HTTPS is required except loopback HTTP for development. Credentials, fragments and queries in the base are rejected. Build-time defines are public configuration and require a rebuild to change.

`FILE_ORIGINS` is a comma-separated list of trusted HTTPS origins for signed attachment and export transfers. The API origin is trusted automatically. A signed URL outside that set fails closed.

All paths below are relative to that base. JSON success bodies use `application/json`; failures use a JSON problem object such as:

```json
{
  "code": "LEAVE_OVERLAP",
  "detail": "The requested period overlaps existing leave.",
  "traceId": "server-trace-id"
}
```

Bearer JWT is attached per API request. POST uses `Idempotency-Key` UUID v4, except `/auth/login` and `/auth/refresh`. Replays must return the original outcome for the same principal/key/payload; a changed payload must fail. Versioned commands carry exact quoted `If-Match`. Detail ETags can be opaque; the client preserves them. Rows used without a separate detail read must include `etag` or use the documented quoted integer `version` convention. Never serve a different validator while accepting synthesized version tags.

Responses may be 200/201/202 with JSON or 204 without a body. HTTP redirects are rejected. The API timeout is 15 seconds; signed file transfers have 60-second timeouts. A timeout does not establish whether a command committed. There is no blanket automatic retry; only one replay after successful token rotation.

401 requests sign-in after refresh failure; 403 denies access; 409 is a state/business conflict; 412 requires refresh and human review; 428 means a missing concurrency/idempotency precondition; 422 exposes validation failures. Error detail is rendered as plain text. Do not include secrets in it.

## Common response shapes

Collections must return `{ "items": [...], "page": 0, "size": 25, "total": 123 }`, with non-negative integer total. Requests include zero-based `page` and `size` between 1 and 100. Workflow pages use size 25; supporting collections use 100. The server must honor stable ordering and pagination. Incomplete/empty pages before total are errors. General collection fetches stop at 10,000 records; selectors stop at 1,000 choices and should use server search for larger catalogs.

Searchable workflow lists (`/requests/me`, `/leave/requests/me` and the three `/pending` approval queues) now send optional `search`, `status` and `sort` query parameters. People directory and feature administration lists send `search` with `page` and `size`. The backend must apply search/filter/sort **before** pagination and return the filtered `total`; changing a query resets the client to page zero. `status=CLOSED` is a grouped filter for `REJECTED`, `CANCELLED`, `FULFILLED` and `CLOSED` records. `sort=oldest` or `newest` orders by `createdAt` with a stable ID tie-breaker. Empty results must mean the complete filtered set is empty, not merely that the current page lacked matches. These semantics need an accepted OpenAPI definition and live acceptance before remote rollout.

IDs are opaque nonempty strings that must fit the current safe path alphabet (lowercase ASCII letters, digits, hyphens). Timestamp values are parseable ISO-8601 strings; UTC `Z` is recommended. Date-only fields use `YYYY-MM-DD`. Versions are integers; amounts are finite JSON numbers, not numeric strings.

Profile:

```json
{
  "employeeId": "employee-a",
  "tenantId": "tenant-a",
  "roles": [
    "EMPLOYEE"
  ],
  "name": "Sok Dara",
  "email": "dara@example.test",
  "department": "Product",
  "position": "Designer",
  "organization": "Example Co",
  "phone": "+855...",
  "timeZone": "Asia/Phnom_Penh"
}
```

Supported display roles, in priority order: OWNER, HR_ADMIN, MANAGER, EMPLOYEE. The profile retains all explicit grants for request review/fulfillment; selecting the highest display role does not discard a separately granted HR_ADMIN role. Optional display fields have safe defaults; tenant and employee identity and roles are required. Production authorization must evaluate actual relationships and approval membership, not just these coarse UI roles.

Work session:

```json
{
  "id": "session-a",
  "employeeId": "employee-a",
  "checkInAt": "2026-10-23T01:30:00Z",
  "checkOutAt": null,
  "source": "TAP",
  "confirmStatus": "NONE",
  "version": 1,
  "etag": "\"1\""
}
```

`clockIn`/`clockOut` are accepted legacy aliases. Sources include TAP, INFERRED and MANUAL; inferred review uses `confirmStatus:PENDING`, then CONFIRMED/REJECTED. `/attendance/today` returns `{ "workDate":"2026-10-23", "sessions":[], "shift":{"name":"Standard workday"} }`.

Workflow record:

```json
{
  "id": "request-a",
  "employeeId": "employee-a",
  "employeeName": "Sok Dara",
  "title": "External monitor",
  "reason": "Design work",
  "status": "DRAFT",
  "version": 1,
  "type": "MATERIAL",
  "decisions": [],
  "attachments": []
}
```

Leave also returns leaveTypeId, startDate, endDate, portion and numeric days. The shared portion values are `FULL_DAY`, `MORNING` and `AFTERNOON`. Corrections return workDate, newCheckIn and newCheckOut. Decision entries use actor, action, note and at. Attachments use id, name and numeric size. Material approval can return `status:PENDING, approvalStage:HR`; otherwise a decided record must reflect the actual next status. The backend owns its chain resolution, not the client.

Leave balance:

```json
{
  "leaveTypeId": "annual",
  "name": "Annual leave",
  "entitled": 18,
  "used": 2,
  "pending": 1,
  "available": 15
}
```

Inbox item: id, title, optional body, boolean read, optional recordId and kind (`leave`, `request`, `correction`). Remote notification preferences use boolean email, inApp and reminders fields plus a version; GET supplies the reviewed ETag for PUT. The local demo retains attendance, announcements and approvals categories, with approvals enabled.

## Authentication and account

| Method/path | Request | Response |
| --- | --- | --- |
| POST `/auth/login` | tenant, email, password | accessToken and refreshToken for native clients; web uses its secure refresh cookie |
| POST `/auth/refresh` | refreshToken | rotated accessToken and refreshToken |
| GET `/auth/me` | — | Profile above; always uncached |
| POST `/auth/logout` | refreshToken | 204; revoke the server token family |
| POST `/auth/change-password` | currentPassword, newPassword | 204 or JSON success |
| PATCH `/auth/profile` | name, timeZone | Updated profile |

The adapter uses a refresh-token JSON body and native secure storage. If the accepted server instead uses HttpOnly cookies, PKCE, MFA, account recovery challenges or different tenant resolution, implement that protocol at this boundary. The current recovery link displays an HR-contact instruction; it does not falsely simulate account recovery.

## Feature routes and wire behavior

The machine-readable candidate endpoint inventory `validation/feature-endpoints.json` lists every feature-owned case route and its method/version precondition. The source of truth for actual calls is `lib/features/<feature>/data/` and shared workflow adapters. These routes are implementation requirements proposed to the server team, **not accepted server endpoints**. Some owner controllers now exist; the integration checklist below distinguishes them from unimplemented extensions.

Attendance uses GET `/attendance/today`, `/attendance/me`, `/attendance/team`, POST `/attendance/check-in` and `/attendance/check-out`, and versioned POST `/attendance/sessions/{id}/confirm` or `/reject`. Check-in sends deviceId, UTC occurredAt and `source:TAP`; checkout also sends sessionId. Remote correction review uses GET `/attendance/corrections?status=PENDING`, then `/{id}` and `/{id}/approve` or `/reject`. The local demo retains `/attendance/corrections/pending`. The review/daily-status/evidence/manual-entry additions are in the endpoint inventory. Foreground evidence sends a historical-style batch to `/attendance/evidence`; the server must validate consent, site, device and replay. The phone does not run attendance inference. The local demo uses a fixed UTC+07 company calendar; generalized tenant timezone rules require acceptance.

Leave uses GET `/leave/balances/me`, `/leave/types`, and paginated own/pending requests; POST `/leave/requests` and versioned `/{id}/approve`, `/reject`, `/cancel`. Remote request bodies include the catalog `code` in `type`, startDate, endDate, portion (`FULL_DAY`, `MORNING`, `AFTERNOON`) and reason. The local implementation additionally demonstrates exact hundredth reservations, future approved cancellation, HR ledger adjustment, year-end preview/apply and independent conflict review. Their candidate paths and version requirements are in the inventory. The server must own transactionality, balance authority, calendar cutoffs and compensation.

General/material/time requests use POST `/requests`, PATCH `/requests/{id}`, GET `/requests/me`, GET `/requests/inbox` for reviewer queues, detail and versioned `/{id}/submit`, `/approve`, `/reject`, `/cancel`, `/fulfill`. The local demo retains `/requests/pending`. Draft updates include type-specific items, quantity, dates and times; explicit null or empty list clears values from a previous category. The local demo snapshots reviewer chains and allows partial stock-aware material issue. Server chain membership, stock reservation and ledger changes must be enforced atomically. Candidate admin routes for request types, chains, stock receipt and comments are in the inventory.

Employee directory and shift support use paginated GET `/employees`, `/departments`, `/positions`, `/shifts`, `/holidays`, `/materials`, `/audit-logs`; HR catalog creation/update uses POST/PATCH with If-Match on updates. The remote employee master, work-site, shift, holiday and assignment adapters send those exact paths to additive `/api/v2` contracts while the base remains `/api/v1`; local demo paths and other employee actions retain their existing paths. Employee writes use `employeeNo`, `departmentId` and `positionId`; site writes use `radiusM` and timezone, shift writes use site ID, matching timezone, same-day local times, working-day mask and grace, and holiday writes include kind. Effective-dated assignments use GET/POST `/employees/{id}/shifts`; POST sends shiftId, validFrom and nullable validTo. Assignment close and list are versioned, while company, employee lifecycle, roles and invitations retain their provisional inventory routes. A server must enforce tenant/relationship access and overlapping effective dates.

Inbox uses GET `/notifications`, POST `/notifications/{id}/read` or `/notifications/read-all` and GET/PUT `/notifications/preferences`; device registration/removal and delivery status use candidate routes in the inventory. `/reports/dashboard` is a count projection. Report feature routes provide period-filtered attendance/late/leave/request views, job history and owner rebuild request. Scoring, training, outbox relay, retries and scheduling belong to protected backend services; the mobile owner view can only display sanitized readiness and request permitted operations.

## Private files and exports

Request attachments use POST `/requests/{id}/attachments/presign` with fileName, contentType, size and sha256. The current provider returns an exact relative `/api/v1/requests/{id}/attachments/{attachmentId}/upload` URL. The app verifies the owner/attachment path, then sends binary PUT through its authenticated API transport. Completion uses POST `/{attachmentId}/complete`; reservation and completion retain account-scoped command identities until success so an uncertain outcome retries the same operation. GET `/{attachmentId}/download` returns the exact relative private `/file` URL; binary GET remains authenticated, refuses redirects and bypasses cache. Persisted fileName/fileSize metadata maps to the file's actual display name/size.

PDF/PNG/JPEG files must be nonempty and at most 10 MiB. The provider verifies participant/tenant access, reservation metadata, content signature, checksum, declared length and filename, and returns no-store/nosniff private downloads. The retained legacy signed-HTTPS adapter sends no API bearer, follows no redirects and accepts only configured trusted origins. Required leave evidence remains a provider capability gap; the client does not substitute a request upload or simulate successful leave evidence.

POST `/reports/exports` sends report and CSV format, returns an id and job status. GET `/reports/exports` is history; GET `/reports/exports/{id}` supplies status and on COMPLETED an exact relative private downloadUrl and optional safe filename. The app verifies `/api/v1/reports/exports/{id}/download` and fetches authenticated CSV bytes without redirects or caching. Foreground polling checks up to ten times at two-second intervals; pending jobs remain in history for later download. Backend must scope every job to its requester and tenant. Timed-out creation has unknown outcome and must reconcile by its retained command key.

## Live acceptance boundary

The client can be switched to remote mode with a base URL, but that only works if the gateway implements the exact consumed paths, DTOs, auth, pagination, ETag/idempotency and authorization semantics. URL entry alone cannot integrate an arbitrary backend. The checkout now contains owner business controllers and a provisional canonical OpenAPI; neither is sufficient evidence of complete consumer/provider compatibility. Reconcile the inventory and these examples against the actual gateway contract and change feature data adapters where needed; then run employee, manager, HR and owner journeys against separate tenants.

Accept refresh rotation/revocation, relationship authorization, stale ETags, duplicate commands, timeout-after-commit reconciliation, balance and stock authority, paging, private files, notifications and failed exports. Build signed Android/iOS apps and exercise native permissions, keychain/keystore, biometrics and sharing on devices. Confirm company timezone, policy, privacy/legal content and accessibility. Controlled local and HTTP fixture tests do not establish these server or device properties.

## Firebase, location and native setup

Dependencies are pinned in `pubspec.lock`: geolocator 14.1.2, firebase_core 5.1.0 and firebase_messaging 17.0.1. Android minimum is API 24 and iOS deployment target is 15. Foreground location descriptions/permissions and Android notification permission are present. Background location is not requested.

Configure the real project using FlutterFire for the actual bundle/application IDs, then supply native Firebase configuration. Enable the Xcode Push Notifications capability with the correct signed `aps-environment` entitlement, upload APNs credentials in Firebase and configure Android's Google Services integration. Do not commit service-account keys or release signing passwords. UIScene's notification-center delegate setup is present in AppDelegate; iOS remote-notification background mode is declared. Actual signed native builds are still required.

The Firebase Messaging 17 SDK's `onRegistered` value is a Firebase installation direct-send target. The registration adapter sends it in the provisional `token` field; reconcile that field/name and delivery API with your backend provider schema, rather than assuming a legacy FCM token contract. No target is printed in UI or logs. Registration/rotation is bound to the current account; the server must revoke device associations on logout, termination and token invalidation, prevent cross-account target leakage, and enforce preferences. Notification payloads may contain only authorized kind/recordId references; the client validates the path and the server must authorize the detail read.

Official setup references: [Firebase Flutter messaging](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [Messaging plugin / UIScene](https://pub.dev/packages/firebase_messaging), [geolocator permissions](https://pub.dev/packages/geolocator). Web preview supports the inbox and demo adapter; remote browser push registration is intentionally unsupported.

Attendance correction details must return `previousSessions` (the server-recorded sessions captured when the correction is submitted), alongside `workDate`, `newCheckIn`, and `newCheckOut`. The client presents these as original versus proposed dated times. Corrections use UTC instants; the launch company zone is Asia/Phnom_Penh (UTC+07). The client accepts a positive duration up to 24 hours and rejects future proposed instants; the gateway must enforce the same rules and return its own authoritative original snapshot.

High-impact previews are authoritative and version-bound. `POST /leave/admin/year-end/preview` returns `previewId`, `summary`, `affectedEmployees`, `totalCarried`, `totalForfeited`, and `rows[]` with `employeeId`, `employeeName`, `leaveTypeId`, `leaveTypeName`, `currentBalance`, `carriedOver`, `forfeited`, and `newBalance` (all day quantities at hundredth precision). Commit must reject a changed preview basis. `POST /employees/{id}/impact` with `If-Match` returns `employeeName`, `currentRole`, optional `newRole`, `accessEnds`, `pendingRequests`, `assignedMaterials`, `openApprovals`, and `summary`; the review screen shows these before a role change or termination. Destructive actions require an audit reason, including `DELETE /notifications/devices/{id}`.

Audit reads use paged `GET /audit-logs` with `page`, `size`, `actor`, `action`, `target`, `from`, and `to` filters. Filtering happens before paging; results are newest first with ID breaking equal-timestamp ties. Each row supplies `id`, `at` (ISO instant), `actor`, `action`, `entityId`, optional `reason`, and optional `changes` mapping field names to `{before, after}`. The client displays exact company-local time with `UTC+07`, without inferring a timestamp from arbitrary string content. Sensitive secrets must never appear in `changes`.

The current identity audit UAT slice is tenant `OWNER` only. Remote `actor` is the account UUID; actor names are not joined. It covers identity-owned organization master changes atomically: catalog create, employee create/update, work-site create/update/delete, shift create/update, assignment create/close, and holiday create/update/delete. Auth/profile coverage and historical backfill remain pending. Date filters select whole UTC days. Other services' audits are outside this endpoint. Mobile navigation, route guards and the explicit local demo enforce the owner-only rule.

Leave forms select a catalog ID; the remote adapter resolves it through the current paged `/leave/types` response and calls `POST /leave/requests/preview` with its `code` in `type`, `startDate`, `endDate`, and `portion`. Submission uses the same conversion. Unknown selections fail before a command; the demo retains its separate `leaveTypeId` input. The response supplies `chargeableDays`, `balanceBefore`, `balanceAfter`, `allowHalfDay`, `evidenceRequired`, `minimumNoticeDays`, and `warnings[]`. The leave owner calculates scheduled workdays, holidays, accounting-year balances, overlap, evidence and notice policy and must revalidate at submission; the local adapter is a demonstration policy. Required evidence is selected before submission and attached through the existing attachment contract after request creation, before the client announces success.

Sensitive in-progress form drafts use authenticated, tenant- and employee-scoped `GET`, `PUT`, and `DELETE /form-drafts/{leave|correction|request}`. `GET` returns `{payload, updatedAt}` (null payload when absent), `PUT` accepts `{payload:{schema:1,...}}`, and `DELETE /form-drafts` clears all of the account's drafts on explicit logout. The client debounces writes, restores on form re-entry, never places these reads in its client cache, and excludes attachment bytes. The gateway must persist drafts server-side, authorize every request, prevent cross-tenant access, return `Cache-Control: no-store`, and erase on logout. In local demo mode the synthetic service is saved with other fictional demo data on the device; this is not the remote sensitive-draft storage contract.

## Shared contract checks

The parent HRFlow repository owns `contracts/openapi.json`. Its current working copy is a broad provisional consumer inventory whose operations are marked pending; only the leave detail/approval fixture currently has cross-client adapter evidence. This repository contains generated copies, shared synthetic fixtures and a bundle receipt under `contracts/`. Run `python3 contracts/check-bundle.py` for local integrity; run the parent `scripts/contracts.py check` with both client checkouts for source freshness. Inventory does not establish provider implementation, business acceptance or live security acceptance.

## Private report CSV transport (2026-10-28)

The additive `GET /reports/exports/{id}/download` endpoint requires the original requester authenticated as HR_ADMIN in the same tenant. Completed jobs return the relative `/api/v1/reports/exports/{id}/download` link. Fetch that path through the current authenticated API transport with CSV response mode; do not navigate to it or send an anonymous storage request. Verify the link matches the selected job, reject redirects and non-CSV responses, and preserve UTF-8. Mobile checks the workspace generation before returning data and never caches export responses. Foreign jobs return 404, unfinished jobs 409, unavailable files 503 and removed HR_ADMIN token authority 403. The live worker supports effective attendance sessions and verified leave requests; REQUESTS additionally requires completed typed request replay and a known original creation timestamp.

Remote reporting now reads `/reports/attendance/summary` and displays the actual effective session records and nullable duration. It does not decode that response as the illustrative local dashboard, fill absent fields with synthetic zeros, or derive absence/leave percentages. Web exports ATTENDANCE from this view; the local demo retains its illustrative leave dashboard. Manager scope is still unavailable on the reporting provider and fails explicitly.


UAT preview accounting update (2026-10-28): the owner returns `balanceTracked=false` with explicit null `balanceBefore`/`balanceAfter` for unpaid leave. The mobile preview shows “Not tracked”; it does not create a zero entitlement. Paid previews require finite numeric amounts. Older paid-only providers may omit the additive flag only with valid numeric balances. This decoder change does not establish a live client/provider journey; the catalog/type-code boundary is being aligned separately.

The mobile catalog and balance readers request explicit pages. The leave owner supports scoped, bounded catalog pagination while preserving its historical array when no page is requested. Remote balances use the owner’s `type` code; the demo’s `leaveTypeId` remains supported by its own fixture. These mappings have consumer tests and separate real owner HTTP evidence; a deployed mobile-to-gateway journey is still a separate acceptance check.

REQUESTS CSV uses the original owner createdAt, with UTC calendar date bounds and the exact timestamp in each row. An uninitialized/replaying request source or an unknown legacy creation basis returns 503 without a job. All sources retain the same tenant/original-requester/current-HR_ADMIN private download checks; no anonymous URL is supported. Local provider/broker evidence is recorded separately from mock consumer tests.


## Current client integration checklist — 29 October 2026

The shared working checklist is maintained in the sibling web integration guide under “Client integration checklist — 29 October 2026”. This mobile summary is usable without that sibling checkout. The backend/UAT chat owns provider repairs, canonical contracts/fixtures and final release evidence; client tests establish consumer behavior only.

| Workflow | Inspected provider / mobile status | Remaining evidence or blocker |
| --- | --- | --- |
| Identity | Browser/native protocols and explicit linked-account setup now exist; native session adapter retains one exact-request refresh replay | No reusable two-tenant employee/manager/HR/owner runtime has been started here; live native session test remains opt-in |
| Organization | Existing v2 employee/site/shift/holiday/assignment adapters match inspected owner route families | Lifecycle/invitations/admin extensions and relationship journeys remain separate acceptance gaps |
| Attendance | Tap/history DTO aliases and zero-version records supported; persistent tap/key retains unknown outcomes | Correction detail/ETag and scoped paging now exist; expanded actual-client review checks passed. Team/inference/manual/evidence extensions require separate provider acceptance |
| Leave | Owner catalog/preview/balances and paginated records already integrated at consumer boundary | Required evidence, ledger/rollover/conflict APIs and live role/tenant journeys remain gaps |
| Requests | Explicit own/inbox pages; non-material quantity normalized to the canonical positive default 1 | Explicit paged provider envelopes now exist and actual GENERAL create/submit/replay/pages pass; canonical material selections and paired date/time fields now pass provider tests and expanded actual client/provider verification |
| Notifications | Remote settings read actual email/inApp/reminders and exact GET ETag; save rejects missing ETag, preserves stale 412 and serializes switches | Demo attendance/announcement/approval categories retained; push/devices/delivery endpoints remain extensions |
| Reports/CSV | Existing authenticated private CSV path and summary adapter | Live export authorization, real device sharing and native acceptance remain required |
| Request attachments | Canonical private request transfer now uses exact request/attachment URLs, authenticated bytes, no redirects/cache and retained reservation/completion keys | Actual private PDF upload/download passes against packaged provider; leave evidence remains unsupported |
| Unsaved form recovery | Explicitly unavailable in remote mode; visible on-screen notice; no recovery/autosave/cleanup call to missing endpoints | Demo form persistence remains. Server draft persistence remains an open requirement, not a successful remote capability |
| Extended workflow panels | Feature routes remain provisional where controllers are absent | Generic workflow/action APIs are not substituted with demo state |

Given a successful create, unsupported draft cleanup is skipped so the result is not mislabeled as failed. Given stale settings, the exact reviewed opaque ETag is sent and 412 is surfaced without refetch-and-replay. Missing remote settings fields fail visibly. The application does not fabricate HR policy, resource versions, tenant access or unavailable provider responses.

Boundary assessment: mobile UI/application/data adapter changes only; no HR policy, server authorization, database, events or deployment topology changes. Canonical changes and compatibility/sync stay with the backend owner. All original unrelated dirty changes are preserved. The existing large request form remains cohesive form orchestration in this slice; notification settings rendering was extracted to its own small panel.

Initial baseline: 171 tests passed, one opt-in live-auth test skipped. The HRFlow MCP mobile runner returned an unstructured tool error, so direct pinned Flutter commands are used and their exact results will be recorded at the final checkpoint. New settings, draft-capability and request-payload tests were observed failing before implementation, then passed in focused runs. Live API/device/UAT acceptance is not established by these fixtures.


Request review presentation now retains all explicit profile role grants: OWNER alone does not imply MANAGER or HR_ADMIN; a separately granted HR_ADMIN role enables HR request actions. Demo persona behavior remains explicit. Provider fileName/fileSize metadata is mapped to presentation name/size without fabricating filenames or file records. Legacy signed-file transfers never carry API credentials, follow redirects or accept an unconfigured storage origin.

The Android toolchain is installed and licensed. The remote-mode release APK compiled with the reserved example.invalid API URL; this is compilation evidence only. This checkout's pre-existing signing configuration falls back to the debug key when no release keystore is supplied. Native device, production signing, Firebase, complete Xcode/iOS and gateway/login UAT remain separate requirements. The Flutter build emits a firebase_core Kotlin Gradle migration warning; no dependency upgrade is included in this client-contract slice.


Correction review distinguishes a null/missing submission-time `previousSessions` snapshot (unavailable evidence) from an authoritative empty array (no captured sessions). Legacy rows must remain unknown rather than be reconstructed from mutable current sessions. The mobile panel renders both states explicitly.

Current source provenance is recorded in `docs/validation/client-integration-source.json` with individual content hashes and an aggregate source identity. Tested base revisions: root `2ad32602d686c8134492aa4d40146562c52a879e`, web `d1db592ae67c472c06b9fe7298c6773ad3bf3f22`, mobile `6066d91d711d7652f49d08edc1acf6ea0c60ae7a`, all with uncommitted changes. SHAs alone cannot reproduce this candidate. No commit, push or deploy has been performed.


## Verification scope and handoff

Pinned Flutter analysis passes without issues. The final structured mobile run reports 187 passed, zero failed, three explicit opt-in live skips (`c2892e4210dd4fbf`). The mobile scoped verifier passed analysis, tests, bundle integrity and whitespace with baseline compatibility; later focused regression and structured test results above identify the final source changes. Initial MCP requests used invalid repository-prefixed test paths and returned tool errors; corrected repository-relative paths work and structured counts are used. No zero-test or skipped run is treated as live acceptance.

The remote-mode Android release APK built successfully at `build/app/outputs/flutter-apk/app-release.apk` (about 65.1 MB), with a reserved example.invalid base URL solely for compilation. APK signature verification passed. Existing local signing material was neither read nor changed; do not infer organizational distribution approval from a valid signature. Android tooling/licenses are present; Xcode is incomplete and no Android/iOS device was connected. Firebase/Kotlin migration and SDK-tooling warnings remain documented build limitations.

The real-provider fixture initially passed two web and two native cases without skips for requests, private files, notification settings and access failures. The expanded native harness initially had a duplicate variable; it was corrected, separated from the web correction work date and compiled. The final expanded run passed two web and two native cases with no skips (`/tmp/hrflow-uat-expanded-client-provider-final.log`). It covers material selections and edits, remote/late/early date/time round-trip, correction detail/ETag/scoped pages/manager approval/stale writes, private files, command replay and denials against actual packaged request, notification and attendance services. Attendance schedule references are explicit fixture data, not attendance organization replay evidence. Direct-provider tests explicitly map the API prefix to owner controller roots and do not prove gateway/login/cookies or native permissions. Final UAT owns the remaining integrated identity/organization/leave/report journeys, full-project checks and deployment/device release gates. No production-readiness claim is made.


Both clients preserve the original remote draft category because the current update API has no category-change field. The edit form disables that selection and explains that a new draft is required for a different category. Local demo editing remains unchanged. The separate native correction review panel treats absent originals as unknown and captured empty snapshots as no original session; the provider now captures new submission-time snapshots immutably, with legacy rows remaining null.

The explicit demo web build also passed (`fvm flutter build web --release --dart-define=ALLOW_DEMO_RELEASE=true`). This is a Flutter layout preview and does not establish Nuxt or native-device acceptance.

The last repeated browser run had a blank-page login timeout during concurrent local checks. A build-output race is suspected but not established. That run remains failed evidence; browser verification is being rerun with build output held stable. No check or timeout was weakened to turn it green.

Final stable-output browser rerun passed all 15 cases with zero failures or skips (structured run `dc7dc91815d54952`). Final web checks passed 126 unit cases; mobile structured run passed 187 cases with three explicit opt-in live skips. The separate expanded actual-provider fixture passed two web and two native cases with no skips. Android remote APK and explicit Flutter demo web compilation passed; no native-device or gateway acceptance is inferred. Final source and verification metadata are stored in the adjacent JSON provenance receipt.


## Notification routing follow-up — 29 October 2026

The notification owner is adding private domain facts with `kind` and `recordId`. Web links request/leave records to their detail routes, corrections to the attendance correction view and attendance sessions to attendance. Native inbox and push share a safe route helper: request/leave/correction detail and attendance activity. IDs must match the existing safe path alphabet; unknown/missing legacy targets remain readable with no invented deep link. Empty/null legacy web `to` is accepted. New domain facts never treat the recipient account UUID as a navigation path.

Both preference screens explain that required approval updates remain in the inbox when optional updates are disabled. This clarifies the approved server policy; the client does not implement delivery, force a local notice or promote email/push/SSE into Must scope. Updated route tests were first observed failing before implementation, then passed. The native full run passed 188 cases with three opt-in live skips; the web check passed 128 unit cases. The earlier APK and real-provider evidence precede this routing/presentation follow-up; notification delivery and final combined acceptance remain server/UAT-owned.
