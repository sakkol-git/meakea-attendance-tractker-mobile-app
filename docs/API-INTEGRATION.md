# Mobile API adapter contract

24 October 2026. This is the contract consumed by the current mobile adapter. It is a handover specification, not the canonical server OpenAPI and not proof of compatibility with the historical reference examples. Publish/accept the backend schema, then update the owning `lib/features/<feature>/data/` repository, routes and mappers where fields or routes differ. Do not change screen code to accommodate transport DTOs.

## Select remote mode

```sh
fvm flutter run --dart-define=DATA_SOURCE=remote --dart-define=API_BASE_URL=https://hr.example.com/api/v1
```

The absolute base must end in `/api/v1`; a deployment prefix and optional trailing slash are supported. HTTPS is required except loopback HTTP for development. Credentials, fragments and queries in the base are rejected. Build-time defines are public configuration and require a rebuild to change.

All paths below are relative to that base. JSON success bodies use `application/json`; failures use a JSON problem object such as:

```json
{"code":"LEAVE_OVERLAP","detail":"The requested period overlaps existing leave.","traceId":"server-trace-id"}
```

Bearer JWT is attached per API request. POST uses `Idempotency-Key` UUID v4, except `/auth/login` and `/auth/refresh`. Replays must return the original outcome for the same principal/key/payload; a changed payload must fail. Versioned commands carry exact quoted `If-Match`. Detail ETags can be opaque; the client preserves them. Rows used without a separate detail read must include `etag` or use the documented quoted integer `version` convention. Never serve a different validator while accepting synthesized version tags.

Responses may be 200/201/202 with JSON or 204 without a body. HTTP redirects are rejected. The API timeout is 15 seconds; signed file transfers have 60-second timeouts. A timeout does not establish whether a command committed. There is no blanket automatic retry; only one replay after successful token rotation.

401 requests sign-in after refresh failure; 403 denies access; 409 is a state/business conflict; 412 requires refresh and human review; 428 means a missing concurrency/idempotency precondition; 422 exposes validation failures. Error detail is rendered as plain text. Do not include secrets in it.

## Common response shapes

Collections must return `{ "items": [...], "total": 123 }`, with non-negative integer total. Requests include zero-based `page` and `size`. Workflow pages use size 25; supporting collections use 100. The server must honor stable ordering and pagination. Incomplete/empty pages before total are errors. Catalog fetches stop at 10,000 records with an explicit error.

Searchable workflow lists (`/requests/me`, `/leave/requests/me` and the three `/pending` approval queues) now send optional `search`, `status` and `sort` query parameters. People directory and feature administration lists send `search` with `page` and `size`. The backend must apply search/filter/sort **before** pagination and return the filtered `total`; changing a query resets the client to page zero. `status=CLOSED` is a grouped filter for `REJECTED`, `CANCELLED`, `FULFILLED` and `CLOSED` records. `sort=oldest` or `newest` orders by `createdAt` with a stable ID tie-breaker. Empty results must mean the complete filtered set is empty, not merely that the current page lacked matches. These semantics need an accepted OpenAPI definition and live acceptance before remote rollout.

IDs are opaque nonempty strings that must fit the current safe path alphabet (lowercase ASCII letters, digits, hyphens). Timestamp values are parseable ISO-8601 strings; UTC `Z` is recommended. Date-only fields use `YYYY-MM-DD`. Versions are integers; amounts are finite JSON numbers, not numeric strings.

Profile:

```json
{"employeeId":"employee-a","tenantId":"tenant-a","roles":["EMPLOYEE"],"name":"Sok Dara","email":"dara@example.test","department":"Product","position":"Designer","organization":"Example Co","phone":"+855..."}
```

Supported effective roles, in priority order: OWNER, HR_ADMIN, MANAGER, EMPLOYEE. Optional display fields have safe defaults; tenant and employee identity and roles are required. Production authorization must evaluate actual relationships and approval membership, not just these coarse UI roles.

Work session:

```json
{"id":"session-a","employeeId":"employee-a","checkInAt":"2026-10-23T01:30:00Z","checkOutAt":null,"source":"TAP","confirmStatus":"NONE","version":1,"etag":"\"1\""}
```

`clockIn`/`clockOut` are accepted legacy aliases. Sources include TAP, INFERRED and MANUAL; inferred review uses `confirmStatus:PENDING`, then CONFIRMED/REJECTED. `/attendance/today` returns `{ "workDate":"2026-10-23", "sessions":[], "shift":{"name":"Standard workday"} }`.

Workflow record:

```json
{"id":"request-a","employeeId":"employee-a","employeeName":"Sok Dara","title":"External monitor","reason":"Design work","status":"DRAFT","version":1,"type":"MATERIAL","decisions":[],"attachments":[]}
```

Leave also returns leaveTypeId, startDate, endDate, halfDay and numeric days. Corrections return workDate, newCheckIn and newCheckOut. Decision entries use actor, action, note and at. Attachments use id, name and numeric size. Material approval can return `status:PENDING, approvalStage:HR`; otherwise a decided record must reflect the actual next status. The backend owns its chain resolution, not the client.

Leave balance:

```json
{"leaveTypeId":"annual","name":"Annual leave","entitled":18,"used":2,"pending":1,"available":15}
```

Inbox item: id, title, optional body, boolean read, optional recordId and kind (`leave`, `request`, `correction`). Notification preferences use boolean attendance, announcements and approvals fields. The current UI keeps approvals enabled.

## Authentication and account

| Method/path | Request | Response |
| --- | --- | --- |
| POST `/auth/login` | tenantSlug, email, password | accessToken, refreshToken |
| POST `/auth/refresh` | refreshToken | rotated accessToken and refreshToken |
| GET `/auth/me` | — | Profile above; always uncached |
| POST `/auth/logout` | refreshToken | 204; revoke the server token family |
| POST `/auth/change-password` | currentPassword, newPassword | 204 or JSON success |
| PATCH `/profile` | name, phone | Updated profile |

The adapter uses a refresh-token JSON body and native secure storage. If the accepted server instead uses HttpOnly cookies, PKCE, MFA, account recovery challenges or different tenant resolution, implement that protocol at this boundary. The current recovery link displays an HR-contact instruction; it does not falsely simulate account recovery.

## Feature routes and wire behavior

The machine-readable [candidate endpoint inventory](validation/feature-endpoints.json) lists every feature-owned case route and its method/version precondition. The source of truth for actual calls is `lib/features/<feature>/data/` and shared workflow adapters. These routes are implementation requirements proposed to the server team, **not accepted server endpoints**. The backend in this checkout does not implement them.

Attendance uses GET `/attendance/today`, `/attendance/me`, `/attendance/team`, POST `/attendance/check-in` and `/attendance/check-out`, and versioned POST `/attendance/sessions/{id}/confirm` or `/reject`. Check-in sends deviceId, UTC occurredAt and `source:TAP`; checkout also sends sessionId. Corrections use `/attendance/corrections`, `/pending`, `/{id}` and `/{id}/approve` or `/reject`. The review/daily-status/evidence/manual-entry additions are in the endpoint inventory. Foreground evidence sends a historical-style batch to `/attendance/evidence`; the server must validate consent, site, device and replay. The phone does not run attendance inference. The local demo uses a fixed UTC+07 company calendar; generalized tenant timezone rules require acceptance.

Leave uses GET `/leave/balances/me`, `/leave/types`, and paginated own/pending requests; POST `/leave/requests` and versioned `/{id}/approve`, `/reject`, `/cancel`. Request bodies include leaveTypeId, startDate, endDate, halfDay (`NONE`, `AM`, `PM`) and reason. The local implementation additionally demonstrates exact hundredth reservations, future approved cancellation, HR ledger adjustment, year-end preview/apply and independent conflict review. Their candidate paths and version requirements are in the inventory. The server must own transactionality, balance authority, calendar cutoffs and compensation.

General/material/time requests use POST `/requests`, PATCH `/requests/{id}`, GET own/pending/detail and versioned `/{id}/submit`, `/approve`, `/reject`, `/cancel`, `/fulfill`. Draft updates include type-specific items, quantity, dates and times; explicit null or empty list clears values from a previous category. The local demo snapshots reviewer chains and allows partial stock-aware material issue. Server chain membership, stock reservation and ledger changes must be enforced atomically. Candidate admin routes for request types, chains, stock receipt and comments are in the inventory.

Employee directory and shift support use paginated GET `/employees`, `/departments`, `/positions`, `/shifts`, `/holidays`, `/materials`, `/audit-logs`; HR catalog creation/update uses POST/PATCH with If-Match on updates. Effective-dated assignments use GET/POST `/employees/{id}/shifts`; POST sends shiftId, validFrom and nullable validTo. The GET history route is a **provisional extension**. Assignment close, company, site, employee lifecycle, roles and invitations are listed in the inventory. A server must enforce tenant/relationship access and overlapping effective dates.

Inbox uses GET `/notifications`, POST `/notifications/{id}/read` or `/notifications/read-all` and GET/PUT `/notifications/preferences`; device registration/removal and delivery status use candidate routes in the inventory. `/reports/dashboard` is a count projection. Report feature routes provide period-filtered attendance/late/leave/request views, job history and owner rebuild request. Scoring, training, outbox relay, retries and scheduling belong to protected backend services; the mobile owner view can only display sanitized readiness and request permitted operations.

## Private files and exports

The app supports leave and request attachments. POST `/{kind}/{id}/attachments/presign` sends fileName, contentType, size and SHA-256; response must contain attachmentId, HTTPS uploadUrl and optional requiredHeaders. The app PUTs bytes to storage with those headers, without the API bearer, and POSTs `/{kind}/{id}/attachments/{attachmentId}/complete`. GET `/{kind}/{id}/attachments/{attachmentId}/download` returns HTTPS downloadUrl for an explicit user download/share action. Here `{kind}` means `leave/requests` or `requests`. Picker accepts PDF/PNG/JPG/JPEG and rejects files over 10 MiB. Backend must check owner access, content/checksum, malware, ticket expiry and incomplete-upload cleanup. Signed URLs and attachments bypass the read cache.

POST `/reports/exports` sends report and CSV format, returns an id and job status. GET `/reports/exports` is history; GET `/reports/exports/{id}` supplies status and on COMPLETED an HTTPS downloadUrl and optional safe filename. Foreground polling checks up to ten times at two-second intervals; pending jobs remain in history for later download. Backend must scope every job to its requester and tenant. Timed-out creation has unknown outcome and must reconcile by its retained command key.

## Live acceptance boundary

The client can be switched to remote mode with a base URL, but that only works if the gateway implements the exact consumed paths, DTOs, auth, pagination, ETag/idempotency and authorization semantics. URL entry alone cannot integrate an arbitrary backend. The current repository has neither a runnable HR API nor an accepted OpenAPI. Reconcile the inventory and these examples against the actual gateway contract and change feature data adapters where needed; then run employee, manager, HR and owner journeys against separate tenants.

Accept refresh rotation/revocation, relationship authorization, stale ETags, duplicate commands, timeout-after-commit reconciliation, balance and stock authority, paging, private files, notifications and failed exports. Build signed Android/iOS apps and exercise native permissions, keychain/keystore, biometrics and sharing on devices. Confirm company timezone, policy, privacy/legal content and accessibility. Controlled local and HTTP fixture tests do not establish these server or device properties.

## Firebase, location and native setup

Dependencies are pinned in `pubspec.lock`: geolocator 14.1.2, firebase_core 5.1.0 and firebase_messaging 17.0.1. Android minimum is API 24 and iOS deployment target is 15. Foreground location descriptions/permissions and Android notification permission are present. Background location is not requested.

Configure the real project using FlutterFire for the actual bundle/application IDs, then supply native Firebase configuration. Enable the Xcode Push Notifications capability with the correct signed `aps-environment` entitlement, upload APNs credentials in Firebase and configure Android's Google Services integration. Do not commit service-account keys or release signing passwords. UIScene's notification-center delegate setup is present in AppDelegate; iOS remote-notification background mode is declared. Actual signed native builds are still required.

The Firebase Messaging 17 SDK's `onRegistered` value is a Firebase installation direct-send target. The registration adapter sends it in the provisional `token` field; reconcile that field/name and delivery API with your backend provider schema, rather than assuming a legacy FCM token contract. No target is printed in UI or logs. Registration/rotation is bound to the current account; the server must revoke device associations on logout, termination and token invalidation, prevent cross-account target leakage, and enforce preferences. Notification payloads may contain only authorized kind/recordId references; the client validates the path and the server must authorize the detail read.

Official setup references: [Firebase Flutter messaging](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [Messaging plugin / UIScene](https://pub.dev/packages/firebase_messaging), [geolocator permissions](https://pub.dev/packages/geolocator). Web preview supports the inbox and demo adapter; remote browser push registration is intentionally unsupported.
Attendance correction details must return `previousSessions` (the server-recorded sessions captured when the correction is submitted), alongside `workDate`, `newCheckIn`, and `newCheckOut`. The client presents these as original versus proposed dated times. Corrections use UTC instants; the launch company zone is Asia/Phnom_Penh (UTC+07). The client accepts a positive duration up to 24 hours and rejects future proposed instants; the gateway must enforce the same rules and return its own authoritative original snapshot.

High-impact previews are authoritative and version-bound. `POST /leave/admin/year-end/preview` returns `previewId`, `summary`, `affectedEmployees`, `totalCarried`, `totalForfeited`, and `rows[]` with `employeeId`, `employeeName`, `leaveTypeId`, `leaveTypeName`, `currentBalance`, `carriedOver`, `forfeited`, and `newBalance` (all day quantities at hundredth precision). Commit must reject a changed preview basis. `POST /employees/{id}/impact` with `If-Match` returns `employeeName`, `currentRole`, optional `newRole`, `accessEnds`, `pendingRequests`, `assignedMaterials`, `openApprovals`, and `summary`; the review screen shows these before a role change or termination. Destructive actions require an audit reason, including `DELETE /notifications/devices/{id}`.

Audit reads use paged `GET /audit-logs` with `page`, `size`, `actor`, `action`, `target`, `from`, and `to` filters. Filtering happens before paging; results are newest first with stable, distinct timestamps. Each row supplies `id`, `at` (ISO instant), `actor`, `action`, `entityId`, optional `reason`, and optional `changes` mapping field names to `{before, after}`. The client displays exact company-local time with `UTC+07`, without inferring a timestamp from arbitrary string content. Sensitive secrets must never appear in `changes`.
