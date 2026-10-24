# HRFlow mobile enterprise UX and workflow evaluation

Date: 24 October 2026. Scope: Flutter mobile client, its mobile-layout preview, local workflows and remote-adapter boundaries. The separate Nuxt application is not evaluated as a completed product.

## Verdict

**Functional demonstration with a coherent light-theme foundation; not ready for an enterprise operational pilot without corrective work.** The existing 40-flow map establishes traceability and entry points, not complete end-to-end acceptance. In particular, BF-032–039 mostly represent backend/operator responsibilities exposed through a readiness view. They are not eight complete mobile workflows.

The earlier handover's broad demo-readiness claim needs qualification: this audit reproduced silent HR edit failures and a search dead end, and measured insufficient dark-theme contrast. A presenter can demonstrate selected journeys, but should not promise that every exposed route works correctly merely because the screen renders.

There is no single universal “enterprise UI standard.” This review uses published accessibility guidance, usability heuristics, HRFlow's own design rules, and explicit operational criteria for HR software. It is an expert/code review with controlled probes, not an accessibility certification, security certification, or user study. SSO, delegation, translation and similar requirements depend on the organization's scope; they are identified as absent capabilities rather than universal compliance violations.

## Evidence and method

- Read `business-flow.md`, the design/typography/component documents, mobile coverage/architecture/integration documents, and feature UI/state/data implementations.
- Visually inspected four current light-mode golden screenshots: Home, Leave, Request detail and Approvals; inspected the year-end review screenshot and the shipped iOS application icon.
- Rendered a new dark-mode Leave screenshot using production composition and measured actual theme color pairs. [Dark-mode evidence](screenshots/audit-dark-leave.png).
- Ran four targeted diagnostic probes: legacy HR edits, multi-page request search, dark contrast, and an approval dialog at 200% text with a simulated keyboard. [Output](validation/enterprise-audit-probes.txt), [diagnostic source snapshot](validation/enterprise-audit-probe.dart.txt). These probes observe defects; their “passed” result is not acceptance of those defects. The temporary test file was removed from the ordinary suite.
- Reviewed the preceding 72-test passing record and release web-build result. Did not rerun that unchanged baseline. The source suite includes useful domain/session/cache tests and rendering checks, but rendering every panel is not equivalent to completing every action.
- No native device, live API, actual push delivery, screen-reader, large-production-dataset performance, or representative-user study was performed. No application source was changed during this evaluation.

References: [Nielsen's usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) inform discoverability, feedback, consistency, prevention and recovery. [WCAG 2.2](https://www.w3.org/TR/WCAG22/) is used as an accessibility benchmark for the preview and relevant interaction principles; native acceptance also needs platform testing. [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) uses 4.5:1 for normal text and 3:1 for large text. [Android accessibility guidance](https://developer.android.com/guide/topics/ui/accessibility/apps) recommends at least 48×48 dp touch targets and suitable text contrast. These references do not certify this implementation.

## Enterprise criteria matrix

**Strong foundation** means useful implementation evidence, not production certification. **Partial** means material work remains. **Fail** means a specific inspected or reproduced problem. **Unverified** means the required evidence is absent. Findings below give exact locations and acceptance conditions.

| # | Criterion | Assessment | Evidence and remaining work |
| --- | --- | --- | --- |
| 01 | Brand consistency inside the app | Strong foundation | Teal palette, bundled Kantumruy Pro, consistent cards/icons/navigation; light screens are visually coherent. |
| 02 | Native brand completion | Fail | Shipped iOS app icon is still the Flutter logo. Native launch/store identity needs a branded pass. |
| 03 | Visual hierarchy and information density | Partial | Main clock action is clear; large greeting/hero and card padding consume scarce mobile space. Detail actions sit below discussion/files/history. |
| 04 | Typography and readable labels | Partial | Good hierarchy and wrapping foundation; statuses are 13 units versus the local design document's minimum 14 for essential status. Some metadata is 12. Validate real Khmer names and numerals on devices. |
| 05 | Light/dark semantic color system | Fail | Hard-coded muted/status/error colors are reused on dark surfaces. See measured contrast in F03. |
| 06 | Responsive layout and enlarged text | Strong foundation, bounded | Existing 360 px/200% render checks; targeted approval-dialog/keyboard probe reported no layout exception. This is not proof of all focus/scroll/keyboard states. |
| 07 | Screen readers, focus and announcements | Unverified | Material controls/tooltips provide a baseline; no TalkBack/VoiceOver task-completion evidence or systematic semantic/announcement audit. |
| 08 | Touch targets and alternative input | Partial | Shared buttons specify 48–52 unit minima. Custom interactive cards, every icon, focus order and external-keyboard behavior need measured acceptance. |
| 09 | Role-specific information architecture | Partial | Employee bottom navigation is understandable. HR/owner work is buried in Profile → All workflows, a long unsearchable list; duplicate editors create inconsistent behavior. |
| 10 | Findability, search and pagination | Fail | Request/leave searches filter only loaded records; an empty result hides loading the next page (F02). |
| 11 | Returning to work and preserving context | Partial | Router guards/back navigation exist. Generic admin dialogs discard unsaved input on Go back; durable form recovery and return-after-expiry are incomplete. |
| 12 | Form usability and input guidance | Partial | Labels, validation, date pickers, weekday chips and review steps exist. Required/optional indicators are inconsistent; generic time fields require typed HH:mm; large lookups are dropdowns. |
| 13 | Workflow correctness across all entry points | Fail | Legacy employee and shift editors can report successful changes that were ignored (F01). The newer route alone does not establish the older route's correctness. |
| 14 | Leave planning and policy transparency | Partial | Balances and local accounting exist, but form lacks a chargeable-days/balance-after preview and advance evidence requirements; balance display loses hundredth precision. |
| 15 | Attendance exceptions and overnight work | Fail for overnight correction | Shifts permit overnight work, while the employee correction form cannot express next-day checkout (F04). Ordinary tap/inferred/correction paths have tests. |
| 16 | Approval decision context | Partial | Actor, status, reason, files and next reviewer can be shown. Missing balance impact/team overlap/original-versus-proposed correction comparison and full stage progress at the decision point. |
| 17 | Approval queue efficiency | Partial | Paginated authorized queue exists; lacks search, request-type/age filters, useful prioritization, age/SLA indicators and next-item processing. Delegation/escalation are absent policy-dependent capabilities. |
| 18 | High-impact administrative confirmation | Partial | ETags, reasons and review exist. Rollover shows only aggregate totals; termination/access changes use generic Confirm without operation-specific impact explanations (F05). |
| 19 | Material fulfillment | Strong local foundation / partial UX | Reviewer snapshots, stock-aware partial issue and history exist. Issuing should retain request/material identity, stock and remaining quantities together in the confirmation. No device/API acceptance. |
| 20 | Calendar and workforce planning | Partial | “Team leave calendar” is a card list with dates, not an overlap/coverage planning view. A list is acceptable for lookup, insufficient evidence for team capacity planning. |
| 21 | Reporting and comparisons | Partial | Period filters, report projections and exports exist. No saved segments, comparison summaries or source-record drill-down; update timestamps lose time-of-day. |
| 22 | Audit explainability | Partial | Events/decisions are visible, but Audit activity displays action, actor and date only; no field diff, exact time, target detail or useful investigation filters (F08). |
| 23 | Loading, empty, success and error states | Strong foundation / partial recovery | Labeled progress, retry, empty-state actions and status text exist. Generic errors/cloud-off icon and success messages lack operation-specific detail; uncertainty/conflicts need guided recovery. |
| 24 | Offline/stale-data trust | Partial | Bounded account-scoped read cache and visible stale warning exist; offline writes are deliberately unsupported. No visible per-resource last-sync timestamp or consistent command availability guidance. |
| 25 | Duplicate actions and concurrency UX | Strong transport foundation / partial UX | Retained keys, ETags, coalesced refresh and stale-version invalidation are tested. A stale decision dialog retains the old record and asks the user to refresh without an in-dialog refresh/review route. |
| 26 | Account security UX and recovery | Partial | Password visibility/autofill, session guards, logout and native-lock adapter exist. Recovery is a static HR instruction; no actionable tenant support, SSO/MFA journey or session-management UI. Decide the required enterprise identity model. |
| 27 | Privacy, permissions and sensitive files | Partial | Foreground location explains capture/review, private-file adapters avoid sending API bearer to storage, exports require explicit sharing. Actual company privacy/help links, native permission recovery and device evidence remain open. |
| 28 | Localization and timezone behavior | Limited scope | English only; Khmer font support is not translation. Fixed UTC+07 is explicit. Wider markets, IANA zones, localized copy/date/number behavior and travel scenarios are not accepted. |
| 29 | Enterprise-scale performance | Partial/unverified | Cache bounds/TTL/request coalescing and paginated cases help. Directory/catalogs load large collections; dropdowns can contain thousands; row rendering is largely eager Column construction. No measured startup/frame/network budget. |
| 30 | Onboarding and administrator continuity | Partial | Setup, people creation, invitations and role changes have local paths. No completed real invitation acceptance/recovery journey or absence/delegation operating model is demonstrated. |
| 31 | Live integration and operational truth | Unverified | 66 candidate case routes and remote adapter are documented; no accepted live HR API. Backend jobs are correctly identified as backend duties, but status views are not completed worker workflows. |
| 32 | Acceptance evidence and usability outcomes | Partial | Good automated foundations; no representative employee/manager/HR study, task-success measurements, real-device coverage or production tenant acceptance. A 40-row map is not a completion metric. |

## Prioritized findings

P1 = correct before an enterprise pilot that exposes the affected workflow. P2 = material usability/governance gap to resolve before broad rollout. P3 = polish. These are audit priorities, not a claim of an exploitable security vulnerability.

### F01 — P1: HR editors can claim success without applying changes

**Reproduced against the local service using the exact legacy form payload shape.** Directory → Edit employee submits `department` and `position`; the newer update handler applies `departmentId` and `positionId`. The request succeeds but both displayed values stay unchanged. Shift rules submits text `days`; the handler derives days from `workingDays`, so entering “Sat, Sun” saved “Mon, Tue, Wed, Thu, Fri.”

Evidence: `lib/features/identity/presentation/people_pages.dart:248` and `:347`; `lib/features/identity/data/case_local.dart:263` and `:74`; diagnostic output. This breaks user trust and can affect scheduling. Route both entry points through the same typed feature editor. Acceptance: edit through every visible entry point, reload, verify exact persisted values and downstream assignments.

### F02 — P1: Search falsely suggests an existing request is absent

**Reproduced with 26 records.** The first 25 records load; the matching “Special laptop” is on page two. Searching displays “Nothing here yet”; there is no Load more button although the controller reports more data. Status filtering has the same structural problem when the loaded page has no matches.

Evidence: `lib/features/workflows/presentation/workflow_pages.dart:211`, `:223`, `:243`; `lib/features/workflows/application/providers.dart:28`. Apply filters/search on the server before pagination, with query-bound provider state and truthful result counts. Acceptance: find later-page records and statuses without manually clearing the search or loading all prior pages.

### F03 — P1: Dark appearance fails normal-text contrast expectations

**Measured and visually confirmed.** Dark surface is `#0E1513`; dark card is `#1B211F`. Muted text is 2.99:1 on the surface and 2.64:1 on cards. Approved-status text is approximately 2.08:1 on its composited pill; error text is 2.26:1 on a card. These are below the 4.5:1 normal-text benchmark. The selected bottom-navigation icon is also visually very faint and needs non-text contrast measurement.

Evidence: `lib/core/theme.dart:3`, `:109`; `lib/core/widgets.dart:44`, `:217`; [rendered screenshot](screenshots/audit-dark-leave.png). Introduce semantic foreground/background pairs per theme, including status, errors, disabled controls and selected navigation. Acceptance: measure every functional pair, then check screens with actual text sizes and assistive tools. Existing dark-mode “no exception” tests do not test readability.

### F04 — P1 for overnight staff: Employee correction cannot represent next-day checkout

**Confirmed from the UI submission path.** The correction form rejects an end clock time earlier than or equal to the start time, and serializes both against the same date. A valid 22:00–06:00 overnight shift cannot be corrected. The shift implementation explicitly supports overnight shifts.

Evidence: `lib/features/workflows/presentation/form_page.dart:494`, `:501`; `lib/features/identity/data/case_local.dart:72`. Add explicit start/end date-time inputs or an unambiguous next-day control, with company timezone and original-record comparison. Acceptance: same-day, overnight, >24-hour rejection, midnight and timezone-boundary scenarios match agreed rules.

### F05 — P2: High-impact review lacks the information needed to judge consequences

Rollover's local preview returns only previewId and an aggregate summary. The UI cannot inspect employee/type allocations, forfeitures or before/after balances. Adjustments do not show resulting balances. Termination/access edits use the same generic confirmation as ordinary changes. `CaseAction.destructive` is declared/set but unused by the renderer.

Evidence: `lib/features/leave/data/case_local.dart:295`; `lib/features/leave/presentation/case_pages.dart:23`; `lib/shared/presentation/case_page.dart:62`, `:494`; `lib/features/identity/presentation/case_pages.dart:146`. Add operation-specific preview details, affected counts, named consequences, and explicit final action labels. Step-up authentication or independent approval should follow the organization's chosen policy, not be assumed universally required.

### F06 — P2: Workflow navigation favors feature inventory over daily responsibilities

Profile → All workflows is a long feature list. Managers/HR still begin with the employee home and five employee-oriented tabs. Related work is split across Directory/People administration and Shift rules/Shift policies. The overlap is already causing F01.

Evidence: `lib/app/feature_panels.dart:38`; `lib/features/identity/presentation/profile_page.dart`; light Home golden. Provide role-relevant work queues, consistent people/policy entry points, searchable task navigation and direct related-record links. Keep the employee clock task prominent while giving managers approvals and HR exceptions a clear home. Validate findability with real role representatives.

### F07 — P2: Reviewers work through a sparse queue and long detail page

Approval cards show employee/type/date/status but not submission age, urgency, policy exception or decision impact. Queue has no search/sort/category filters. Actions are below attachments/activity, so long histories push them far down. The confirmation contains generic text and a note rather than a compact named request summary.

Evidence: `lib/features/workflows/presentation/workflow_pages.dart:263`, `:613`, `:651`, `:700`. Add queue triage and a safe persistent action area, show relevant balance/team/original-record context, and offer next-request navigation. Bulk approval should be introduced only for safe homogeneous cases; it is not automatically a requirement.

### F08 — P2: Audit and report chronology loses important detail

`businessValue` formats all ISO-looking timestamps as dates. Audit activity also formats time away and shows only action/actor/date; request timelines/comments do the same. Two same-day decisions cannot be distinguished by time, and report “Updated” is not precise enough to judge freshness.

Evidence: `lib/shared/presentation/case_page.dart:274`; `lib/features/identity/presentation/audit_page.dart:32`; `lib/features/workflows/presentation/workflow_pages.dart:444`, `:628`. Separate date, timestamp and duration formatters. Show company timezone, precise timestamp, subject, actor, reason and relevant before/after details with authorized drill-down. This concerns audit usability; it does not establish server audit immutability.

### F09 — P2: Leave balances are displayed at lower precision than accounting

Local accounting supports hundredths, but Home and Leave use at most one decimal for available days. For example, 2.25 is displayed as 2.3. This does not alter the ledger, but the employee sees a different entitlement than the authoritative value.

Evidence: `lib/features/workflows/presentation/workflow_pages.dart:159`; `lib/features/dashboard/presentation/home_page.dart:267`. Use a consistent unit/precision policy, retaining up to two meaningful decimals; include the applicable balance period. Acceptance: 0, 0.01, 0.25, 0.5, 1.05 and negative/error cases are shown truthfully.

### F10 — P2: Form safety and policy guidance are inconsistent

The main request form has a discard guard, but generic admin dialogs allow Go back to close meaningful edits without a dirty-state check. They have no durable recovery on process death/session expiry. Leave form does not preview chargeable days or final balance; half-day choices are shown before checking the selected policy. Required leave evidence is enforced at approval, while the employee form does not flag that policy requirement in advance.

Evidence: `lib/shared/presentation/case_page.dart:494`, `:551`; `lib/features/workflows/presentation/form_page.dart:370`, `:447`; `lib/features/workflows/data/local_handler.dart:211`. Add consistent discard/recovery behavior, policy-aware controls and a review of actual impact. Preserve drafts only through an approved storage policy for sensitive HR data.

### F11 — P2: Conflict and uncertain-outcome recovery is too manual

The client correctly carries ETags and stable keys, but stale decision dialogs retain the old record. The user receives “refresh before making a decision” without a direct refresh-and-compare flow inside the dialog. Non-clock form keys are not a durable command history after navigation/process loss. Cached-data warning has no per-resource timestamp.

Evidence: `lib/app/runtime.dart:8`; `lib/features/workflows/presentation/workflow_pages.dart:700`, `:791`; `lib/shared/presentation/case_page.dart:310`, `:484`; `lib/core/widgets.dart:33`. Provide distinct conflict, network-failure and unknown-outcome states, with record reconciliation and preserved input. Acceptance must cover timeout after server commit and another reviewer acting first.

### F12 — P2: Scale, planning and support capabilities remain limited

Directory/catalog reads can load up to 10,000 records; dropdown lookup loads up to 10,000 choices, and collections largely build eager widget Columns. Reports and team calendar are generic card lists. There are no measured mobile performance budgets, actionable support contacts, or completed enterprise sign-in recovery. English-only/UTC+07 scope must be accepted explicitly by the buyer.

Evidence: `lib/app/cases.dart:74`; `lib/core/data/resource_repository.dart:23`; `lib/features/identity/presentation/people_pages.dart:60`; `lib/features/identity/presentation/auth_page.dart:213`; `lib/app.dart:258`. Add server-driven people search/paged selectors and lazy lists, appropriate planning views, contextual support, and the selected identity/localization scope. Measure against representative tenant size on supported devices.

### F13 — P2 before client-branded installation: Native branding is unfinished

The iOS 1024px application icon is the Flutter logo, despite the coherent HRFlow in-app palette. Evidence: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`. Replace platform/store icon sets and verify launch screen, app name, notification identity and installation experience on both platforms. The audit did not validate native launch behavior.

## What is worth keeping

The light visual foundation is calm and consistent. Clocking has a clear primary action; status is expressed with words, not just color. Shared controls have useful sizing defaults. Main forms include validation and request draft handling. Role gates, exact command receipts, version checks, approval separation, partial stock issues, correction evidence retention and local accounting are substantive foundations. Cache/session tests address important races. These should be retained while fixing inconsistent entry points and improving task-specific presentation.

The code and documentation also correctly distinguish foreground evidence from confirmed attendance, local demonstration from remote mode, and backend jobs from mobile execution. Preserve those distinctions in demonstrations and sales claims.

## Remediation and acceptance order

1. **Correctness and readability first:** F01–F04 and F09. Require persisted-value checks for every editor entry point, complete-result search/filter checks, semantic contrast tests, and a successful overnight correction journey.
2. **Decision safety and continuity:** F05, F08, F10 and F11. Require itemized rollover previews, before/after changes, exact timestamps, preserved form state, and guided conflict/unknown-outcome reconciliation.
3. **Role productivity and product finish:** F06, F07, F12 and F13. Simplify navigation, improve queues/selectors, finish branding and set an explicit supported organization/locale/device scope.
4. **Acceptance with users and infrastructure:** observe employees, managers and HR staff completing representative ordinary and exception tasks without coaching. Record completion, wrong decisions, recovery success, time and assistance needed. Agree targets before testing. Run TalkBack/VoiceOver, keyboard/large-text/contrast checks, representative-data performance measurements, signed native flows and cross-tenant live API acceptance.

Suggested operational acceptance journeys: create/edit through both people routes; find a request on a later page; create policy-dependent leave with evidence; approve/reject with conflict recovery; correct an overnight shift; adjust a fractional balance; inspect/apply a carry-over preview; partially fulfill material quantities; investigate two same-day audit events; recover from permission denial, session expiry and a committed command whose response was lost.

Until those checks pass, label the deliverable **“mobile workflow demonstration with remote adapter under integration”**, and use a controlled demo script that discloses remaining gaps. The gateway URL alone cannot prove enterprise readiness or complete workflow correctness.
