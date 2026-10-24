# Mobile architecture and cache policy

Implementation record: 24 October 2026. This document describes the current client, not verified server behavior.

## Feature modules

The client uses **feature-first modules, each with its own clean architecture**. There is no shipped all-feature repository or top-level domain/application/data monolith.

```text
lib/features/<feature>/
  domain/          immutable models, capabilities and repository ports
  application/     Riverpod state, query lifecycles and use cases
  data/            repository implementations, DTO mappers, route tables,
                   platform adapters and feature-owned local handlers
  presentation/    screens, editors and feature view definitions
```

Business modules are identity, attendance, leave, requests, notifications, reporting and operations. Attachments, workflow coordination, settings and dashboard are smaller supporting modules. Feature domains never import Flutter, persistence or concrete data adapters. Application/presentation depend on ports; the architecture suite inspects actual feature files and fails on empty/missing layers.

`lib/app/composition.dart` wires separate feature repositories to the selected `ApiClient`. `lib/app/cases.dart` coordinates paginated administrative views through the owning feature port; `lib/app/catalogs.dart` routes reference lookups to that feature. `lib/app.dart` owns navigation and role gates. The `HrRepository`/`WorkspaceRepository` compatibility fixture exists only under `test/support/`.

Shared infrastructure is limited to transport protocol, secure storage, encrypted cache, mechanical HTTP helpers, theme/widgets and common workflow/view metadata. Each feature owns its route table and DTO mapping. `shared/domain/models.dart` and `core/data/mappers.dart` retain test compatibility exports, not a central production repository.

`core/demo/local_service.dart` is a transactional synthetic service kernel. Its Dart part files live in the owning feature's `data/local_handler.dart` / `case_local.dart`. The kernel supplies fictional fixtures, tables, serialization, snapshot rollback and command receipts; feature handlers supply business behavior. A single snapshot emulates cross-feature persistence for demonstration, not a cross-service production transaction.

Core entities are typed. Flexible case/catalog metadata remains an explicit boundary until the accepted backend schema exists; feature data adapters convert it into immutable `CaseRecord` values. There is no claim that provisional hand-written metadata is generated OpenAPI or fully typed business DTOs.

## Session and authorization

- Tokens are stored together in one native secure-storage value per API origin/path namespace. Access tokens are read from memory per request. No tokens enter demo snapshots or preferences.
- An authenticated profile must contain tenant ID, employee ID and supported roles before cache identity is bound. Scope includes API namespace, tenant, employee and effective role.
- Simultaneous 401s share one refresh operation. A request is replayed once with its original command object and idempotency key. Credential and workspace generation guards prevent old-account requests and refresh replays from publishing results or running under a newly signed-in principal. Serialized credential operations prevent a late refresh or sign-out from overwriting newer credentials. Application operation guards also prevent late restoration, login, sign-out and profile edits from replacing a newer session.
- Failed refresh/replayed 401 erases the local session and returns the app to sign-in. Network failures do not silently revoke a valid session.
- GoRouter gates authenticated, management and HR routes. Workflow policy hides ineligible actions. The server must independently enforce tenant ownership, reporting relationships, approval-chain membership and privileges.
- Native device authentication locks a restored session when enabled and after more than 30 seconds in the background. It supplements account authentication. Browser preview does not enable the native lock setting.

## Remote read cache

The cache stores successful authenticated GET responses only. No queued mutations, optimistic approvals, or automatic offline writes are implemented.

| Resource | Maximum freshness |
| --- | --- |
| Leave balances | 15 seconds |
| Attendance, pending approval queues, notifications | 30 seconds |
| Employees, departments, positions, shifts, holidays, materials, leave types | 5 minutes |
| Other cacheable reads | 1 minute |
| Auth, attachments, export jobs/downloads, audit | Never cached |

Server `Cache-Control: no-store`/`no-cache` and `Vary: *` disable caching; server `max-age` can shorten the client TTL. Cache keys include path and canonical query parameters. Identical simultaneous reads share a request, and callers receive cloned response objects.

Encrypted Hive stores at most 128 entries / 4 MiB of serialized responses, with a 256 KiB entry limit and LRU eviction. Its generated encryption key lives in secure storage. If secure storage or encrypted disk cache is unavailable, only memory caching is used. Storage failure cannot turn a successful server mutation into a reported mutation failure. Malformed cache records are discarded.

Expired responses are revalidated. Only network/timeout errors may return a response at most 24 hours old, marked stale with a visible notice. A 401, 403, malformed DTO, validation conflict or business failure cannot trigger stale fallback. Cache hits are performance hints, never authorization or balance authority.

Successful commands invalidate related resource families: leave also invalidates attendance, reports and notifications; attendance invalidates leave/conflicts, reports and notifications; shift edits invalidate assignment snapshots and attendance; requests invalidate reports/notifications/materials. Invalidation epochs prevent old in-flight reads from publishing after a mutation, identity change or explicit refresh. Sign-out clears the active cache. Pull-to-refresh clears cache before reloading active data.

Workflow lists fetch 25 records at a time and offer Load more. Approval pages combine three independently paginated resource queues. Supporting catalogs/history fetch pages of 100, explicitly rejecting incomplete responses or more than 10,000 rows rather than silently truncating. Server-side search and virtualized enterprise-size directories are a future scale boundary; the current UI is intended for bounded mobile datasets.

## Commands and demo durability

POST commands carry UUID v4 keys. Forms and review actions retain keys for an unchanged retry payload; versioned decisions use the detail ETag without stripping quotes. Clock retries retain the exact original body/timestamp in secure storage until acknowledged. This is not a background command queue or a guarantee of recovery after every app termination; uncertain outcomes must be reconciled with server state.

The local simulator serializes commands, keeps successful POST receipts, and rolls back a mutation if snapshot persistence fails. Its synthetic snapshot includes request history, files, notifications and audit. It uses preferences because it contains fictional demo data, not production employee data. Demo identities are distinct principals, but demo role checks are not evidence of production security.

Feature demonstration rules and all 40 workflow mappings are recorded in [workflow coverage](WORKFLOW-COVERAGE.md). Leave uses integer hundredths and dated portions, ledger adjustments, cross-year reservations, explicit rollover previews and conflict review. Requests snapshot review chains and issue material quantities against stock. Manual entries and corrections retain superseded source records; daily finalization binds to a fingerprint of its source evidence, calendar and pinned shift policy. New evidence makes a finalized result provisional again.

Shift assignment intervals include both endpoints, reject overlap and preserve the policy snapshot selected at assignment. Editing a policy changes later assignments; closing a current period cannot rewrite past days. In a production system these invariants, actor scope and source snapshots must be implemented atomically on the server.

## Platform and operational limits

Native keychain/keystore, biometric lifecycle, file picker and sharing need real Android/iOS validation. The company timezone in the demo and current date/time form adapter is UTC+07 (Phnom Penh); multi-timezone tenants need an accepted timezone contract and adapter change before release. Device backup is disabled on Android; iOS keychain entitlement and Face ID usage text are configured but not signed/device-tested.

No analytics payloads or personal-data logging are added. Production monitoring, crash reporting, release signing, threat review, Firebase/APNs provider configuration, legal/privacy content, store distribution and accessibility acceptance must be configured for the actual organization. Automated layout checks do not replace assistive-technology testing on devices.

## Device integrations

Location capture is foreground and opt-in. The user chooses an available work site and arrival/departure, captures one sample, reviews it and submits only a boundary event supported by the sample's accuracy. The adapter uses the documented EvidenceBatch shape with a stable event ID, occurrence time and device installation ID. A signed-in server must verify consent, device trust and geofence semantics; client coordinates are untrusted. No Wi-Fi/BLE flags or ML score are fabricated. The demo retains receipt metadata but drops the event's raw sample coordinates.

Firebase Messaging 17 registration uses `register()` / `onRegistered` (installation direct-send targets), with account-bound registration and rotation listeners. Only supported record kinds and safe IDs can become notification links. Inbox data stays available when push is unconfigured. Native Firebase configuration, Apple Push capability/entitlement, APNs keys, Android provider setup and actual message/device acceptance remain required. See [API integration](API-INTEGRATION.md).
