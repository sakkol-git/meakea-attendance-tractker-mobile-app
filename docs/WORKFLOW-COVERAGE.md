# Mobile workflow coverage

24 October 2026. This maps all 40 entries in the parent `business-flow.md` to the mobile client. Screens, adapters and fictional demo behavior exist for the client-owned tasks below. This is **not** a production backend acceptance claim. Operational tasks remain in the secured backend/ML environment; the owner sees an explicit readiness view rather than simulated worker execution.

Open **Profile → All workflows** for feature screens. Home, Activity, Requests, Leave, Approvals, Directory, Schedule, Settings and Security remain available in their normal navigation.

| Flow | Client entry | Scope and behavior |
| --- | --- | --- |
| BF-001 Login | `/login` | employee: Remote login and explicit demo personas |
| BF-002 Refresh token rotation | `/security` | employee: Automatic coalesced refresh and guarded replay |
| BF-003 Company setup | `/setup` | employee: Authorized setup form; real provisioning requires accepted service |
| BF-004 Employee and organization onboarding | `/features/identity.people` | hr: People, invitations, lifecycle, roles and organization catalogs |
| BF-005 Shift definition and assignment | `/features/identity.shifts` | hr: Shift policies, assignment snapshots, period closure and history |
| BF-006 Company holidays | `/manage/holidays` | hr: Create and edit holiday calendar |
| BF-007 Clock in | `/home` | employee: Clock command and one-open-session guard |
| BF-008 Clock out | `/home` | employee: Versioned clock-out and retry reconciliation |
| BF-009 Evidence submission | `/evidence/capture` | employee: Opt-in foreground observation and processing history |
| BF-010 Inference orchestration | `/features/attendance.evidence` | employee: Client displays processing outcomes; server owns orchestration |
| BF-011 Inferred attendance review | `/activity` | employee: Confirm or reject inferred sessions |
| BF-012 Correction and manual entry | `/new/correction` | employee: Correction submission and decision; HR manual-entry screen |
| BF-013 Daily-status finalization | `/features/attendance.review` | hr: Provisional days, review guards and revision-aware finalization |
| BF-014 Leave submission and reservation | `/new/leave` | employee: Workday and exact-unit annual reservations |
| BF-015 Leave approval | `/approvals` | manager: Independent versioned approval |
| BF-016 Leave rejection | `/approvals` | manager: Reasoned rejection and release |
| BF-017 Leave cancellation | `/leave` | employee: Own pending or whole future approved leave cancellation |
| BF-018 Leave balance and adjustments | `/features/leave.balances` | hr: Independent HR ledger adjustments and balance revisions |
| BF-019 Year-end carry-over | `/features/leave.rollovers` | hr: Explicit cap, preview, stale-preview rejection and replay-safe apply |
| BF-020 Leave conflict review | `/features/leave.conflicts` | hr: Independent keep or cancel with compensation and evidence retention |
| BF-021 Create and edit requests | `/new/request` | employee: Category, material, quantity, date and time drafts |
| BF-022 Submit and resolve review chain | `/requests` | employee: Submission snapshots configured review chain |
| BF-023 Approve request step | `/approvals` | manager: Assigned reviewer then optional HR step |
| BF-024 Reject or cancel request | `/requests` | employee: Owner cancellation and independent reasoned rejection |
| BF-025 Material fulfillment | `/features/requests.fulfillment` | hr: Partial stock-aware issue with history |
| BF-026 Private attachments | `/requests` | employee: Request and leave file picker, private download and share |
| BF-027 Notification delivery | `/features/notifications.devices` | employee: Device registration, rotation and delivery view; provider setup required |
| BF-028 Inbox and preferences | `/notifications` | employee: Reads, record links and own notification preferences |
| BF-029 Reports and projections | `/features/reporting.attendance` | manager: Period-filtered reports; projections are server-owned |
| BF-030 Report export | `/features/reporting.exports` | manager: Job history, status, scoped CSV download and share |
| BF-031 Projection recovery | `/features/reporting.rebuilds` | owner: Authorized reasoned rebuild request and job history |
| BF-032 Standalone scoring | `/features/operations.readiness` | owner: Readiness only; scoring runs in protected service |
| BF-033 Model inspection | `/features/operations.readiness` | owner: Readiness only; protected service metadata required |
| BF-034 Model training | `/features/operations.readiness` | owner: Operator-owned offline workflow, mobile status boundary |
| BF-035 Owner event relay | `/features/operations.readiness` | owner: Backend-owned publication, mobile status boundary |
| BF-036 Consumer retry and dead letter | `/features/operations.readiness` | owner: Backend-owned recovery, mobile status boundary |
| BF-037 Shift cutoff scheduler | `/features/operations.readiness` | owner: Backend scheduling; manual HR daily review available |
| BF-038 Reference bootstrap | `/features/operations.readiness` | owner: Backend bootstrap; fictional fixture initialization in demo |
| BF-039 Technical readiness and API documentation | `/features/operations.readiness` | owner: Sanitized status contract, no direct infrastructure access |
| BF-040 Logout and token revocation | `/profile` | employee: Local credential removal and server revocation request |

## Demonstration policies

- Fixed company calendar: Asia/Phnom_Penh (UTC+07), English UI, assignment-specific workdays or Monday–Friday fallback. Overnight shifts end on the following day. No DST or general IANA-timezone support is claimed.
- Approved leave cancellation is for an entirely future request. Started leave requires independent conflict review; the cancel decision compensates the whole request. The source documents leave overlap policy unresolved; this explicit demo choice requires company approval before live use.
- Leave uses integer hundredths, full/half-day portions, pending reservations per year, explicit HR adjustments and carry-over caps. Year-end preview blocks pending cross-year requests and refuses a changed balance basis or a repeated closing-year application.
- Manual/correction entries retain superseded original records. Daily calculations choose manual evidence before taps before non-rejected inference; holidays/day-off/leave calendar labels are separate from retained work minutes. Unresolved conflicts, open sessions and pending inference block finalization. New source evidence invalidates an earlier finalization revision.
- Request submission snapshots the configured first reviewer and optional HR step. Material issues validate approved remaining quantities and current stock. Demo starter material stock is ten items each; receipt and issue history remain separate.
- Invitations and setup do not send real email in demo. Location capture uses fictional coordinates in demo. Notifications are in-app demo records; no push or Kafka delivery is fabricated. Report recovery refreshes local source-derived data only.

## Integration acceptance still required

The parent repository has no accepted business OpenAPI or implemented Java HR controllers. Every feature keeps its candidate paths in `lib/features/<feature>/data/case_routes.dart`; these extensions must be reconciled with actual gateway contracts. Native SDKs, permissions, secure storage, Firebase/APNs, signing, actual file storage and accessibility need device acceptance. Changing a URL alone cannot make an incompatible server work.

Machine-readable route coverage: `docs/validation/workflow-routes.json`. Tests compare its 40 IDs with the parent source and exercise all role-gated feature pages through the production composition.
