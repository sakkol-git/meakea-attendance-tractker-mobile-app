# Mobile acceptance ledger

Baseline: 24 October 2026. Statuses reproduce the [enterprise UX audit](../ENTERPRISE-UX-AUDIT.md); they are **not** upgraded because a screen renders. `Red` means a permanent test asserts the required behavior and currently fails. Human evidence must name the verifier and date before a criterion can become Pass-evidenced. All 32 criteria remain open for final acceptance.

Run the focused suite with `fvm flutter test --name acceptance`. The red tests are in [enterprise_regressions_test.dart](../../test/acceptance/enterprise_regressions_test.dart). The seven unresolved scope decisions are in [scope.md](scope.md).

| ID | Criterion | Testable pass condition | Audit status | Current evidence / next gate |
| --- | --- | --- | --- | --- |
| 01 | Brand consistency | Every in-app screen uses approved brand tokens and no feature literal colors. | Pass-evidenced for in-app color tokens; native asset gate remains | [Contrast report](contrast.md), `acceptance F03` literal-color test; native brand tracked under criterion 02. |
| 02 | Native brand | Android/iOS icons, splash, app name and notification mark use the approved asset on installed devices. | Fail | Flutter iOS icon [finding F13](../ENTERPRISE-UX-AUDIT.md); asset and device gate. |
| 03 | Hierarchy and density | Each role's primary task is visible at 360×640 without scrolling. | Partial | Role goldens pending. |
| 04 | Typography | Essential status text is at least 14 logical pixels and Khmer names/numerals render without clipping. | Partial | Typography/device checks pending. |
| 05 | Light/dark color | Functional normal text reaches 4.5:1 and non-text controls 3:1 in both themes. | Pass-evidenced for semantic functional pairs; device review remains | [Contrast report](contrast.md), `acceptance F03` pair test, four dark visual goldens. |
| 06 | Responsive/large text | Every main screen and dialog works at 360 px and 200% text with keyboard visible, without overflow. | Strong foundation, bounded; Red | Existing route renders; `acceptance F07 approval dialog keeps decision action visible with keyboard`. |
| 07 | Screen readers | A person completes ten key journeys with TalkBack and VoiceOver and records spoken output. | Unverified; Human-gated | Manual script and signed runs pending. |
| 08 | Touch targets/input | Every interactive target is at least 48×48 dp and keyboard focus is visible, ordered and operable. | Partial | Target/focus audit pending. |
| 09 | Role information architecture | Employee, manager, HR and owner each reach their top task in at most two actions. | Partial | Per-role navigation study pending. |
| 10 | Search/pagination | A search or filter finds matching records on later pages without falsely displaying an empty state. | Pass-evidenced for client/demo; live API gate remains | Five `acceptance F02` tests cover later-page requests, status reset, directory search, approval search and remote query parameters. |
| 11 | Context preservation | Unsaved edits require a discard decision; permitted drafts survive the agreed interruption scenarios. | Partial; Red | `acceptance F10 dirty admin dialog asks before discard`; storage policy pending. |
| 12 | Form usability | Every form gives required/optional guidance, appropriate pickers, and an accurate review before submit. | Partial | Form-route inventory and scenarios pending. |
| 13 | Workflow correctness | Every exposed editor reloads exactly the values saved, including IDs and shift weekdays. | Partial; F01 evidenced | `acceptance F01` tests: typed employee IDs, weekend shift and downstream assignment, directory/shift-rule entry points, department/position catalogs, and unknown-field rejection. Other workflow editors remain to be accepted. |
| 14 | Leave policy | Leave forms show chargeable days, resulting balance and evidence rules; displayed amounts preserve hundredths. | Partial; F09 evidenced | Table-driven formatter, presentation lint and Home widget `acceptance F09` tests pass. Leave preview/evidence policy cases remain. |
| 15 | Overnight attendance | A 22:00–06:00 next-day correction stores both dates and shows original/proposed values to the reviewer. | Pass-evidenced for client/demo; live API gate remains | Four `acceptance F04` tests cover explicit checkout date, instant boundaries, local reload, and reviewer original/proposed dated times. |
| 16 | Approval context | A reviewer sees balance/coverage, original/proposed values or stock impact as appropriate before deciding. | Partial | Decision context tests pending. |
| 17 | Queue efficiency | Authorized queues search, filter, sort and advance to the next item without losing place. | Partial | Queue scenarios pending. |
| 18 | High-impact confirmation | Rollover, entitlement, termination and access changes show named before/after impact and an operation-specific confirmation. | Partial | Impact/receipt tests pending. |
| 19 | Material fulfillment | Full/partial issue respects available stock and remaining request quantity and displays both in history. | Strong local foundation / partial UX | Confirmation/history scenarios pending. |
| 20 | Calendar planning | A month/week view shows per-day leave coverage and an accessible person-level alternative. | Partial | Coverage test pending. |
| 21 | Reporting | Reports show period comparisons, saved segments, source drill-down and precise generated-at timestamps. | Partial | Report scenarios pending. |
| 22 | Audit explainability | Two same-day events show distinct times, actor, target, reason and before/after changes. | Partial; Red | `acceptance F08 audit rows retain time of day`; detail/filter tests pending. |
| 23 | States and recovery | Writes distinguish conflict, failure and unknown outcome, each with a usable recovery action. | Strong foundation / partial recovery | Conflict/timeout tests pending. |
| 24 | Offline trust | Every stale resource shows last update time and unavailable offline actions explain why. | Partial | Cache/offline UI tests pending. |
| 25 | Concurrency UX | A stale decision can reload, compare and resubmit with input preserved; unknown outcomes do not duplicate. | Strong transport foundation / partial UX | Competing-reviewer and lost-response tests pending. |
| 26 | Account security | The chosen identity model supports recovery, session management and its required challenge path. | Partial; Human-gated | Identity decision and live IdP checks pending. |
| 27 | Privacy/permissions | Consent precedes permission prompts, denial has recovery guidance, and logout wipes scoped sensitive data. | Partial | Device and privacy checks pending. |
| 28 | Localization/time zone | All launch languages and company-zone edge cases pass translation and boundary tests. | Limited scope; Human-gated | Language/time-zone decisions pending. |
| 29 | Performance | Cold start, frame times and memory stay within agreed budgets on the low-end reference device at target tenant size. | Partial/unverified; Human-gated | Scale/device targets and measurements pending. |
| 30 | Onboarding | An invitee accepts, completes first login and reaches the correct manager route, including expiry recovery. | Partial; Human-gated | Live invitation/backend run pending. |
| 31 | Live integration | Every candidate route passes contract tests and the core smoke suite passes against a real two-tenant gateway. | Unverified; Human-gated | Accepted OpenAPI, backend and test tenant pending. |
| 32 | Acceptance evidence | Representative users meet pre-agreed task success and error thresholds on supported devices. | Partial; Human-gated | Facilitated study and signed results pending. |

The tests in this phase deliberately fail; Phase 1 and later work should turn them green without deleting or weakening them. A targeted test only covers its stated behavior: for example, the current overnight test checks the missing UI control, while its eventual persistence and reviewer comparison tests remain required.

## P0-A verification, 24 October 2026

| Command | Observed result |
| --- | --- |
| `fvm flutter test test/*_test.dart --reporter expanded` | **72 passed**, 0 failed (the unchanged pre-acceptance suite). |
| `fvm flutter test --name acceptance --reporter expanded` | **1 passed, 9 failed as expected**; the passing test proves the local service persists overnight start/end dates. |
| `fvm flutter analyze` | **No issues found**. |
| `fvm flutter build web --release` | **Built `build/web`**; Flutter emitted its standard wasm dry-run suggestion, not a build failure. |

The full `flutter test` suite is intentionally red in Phase 0. Do not interpret this as a regression in the original 72 tests, or mark the nine criteria passed before their acceptance assertions turn green.

## P1-A verification, 24 October 2026

The Directory, People administration, Shift rules, Shift policies, Departments and Positions entry points now use the feature-owned typed editor for their record type. Employee department/position selection sends IDs; shift days send a seven-day bitmask. The local service rejects unsupported employee, shift, department and position fields, instead of acknowledging ignored input.

| Command | Observed result |
| --- | --- |
| `fvm flutter test test/acceptance/enterprise_regressions_test.dart --plain-name 'acceptance F01' --reporter expanded` | **6 passed**. |
| `fvm flutter test test/*_test.dart --reporter expanded` | **72 passed**, 0 failed. |
| `fvm flutter test --name acceptance --reporter expanded` | **7 passed, 7 expected failures** in later prompts. |
| `fvm flutter analyze` | **No issues found**. |
| `fvm flutter build web --release` | **Built `build/web`**. |

## P1-B verification, 24 October 2026

Requests, leave, directory and approvals now query the repository with debounced search before paging. Status filtering is server-side for request/leave lists; query changes create a fresh page-zero controller. The local adapter filters before pagination; the remote adapter sends optional `search`, `status` and `sort`. List empty states are withheld while further pages remain. The displayed count is the filtered total for workflow lists and the loaded count for directory.

| Command | Observed result |
| --- | --- |
| `fvm flutter test test/acceptance/enterprise_regressions_test.dart --plain-name 'acceptance F02' --reporter expanded` | **5 passed**. |
| `fvm flutter test test/*_test.dart --reporter expanded` | **72 passed**, 0 failed. |
| `fvm flutter test --name acceptance --reporter expanded` | **12 passed, 6 expected failures** in later prompts. |
| `fvm flutter analyze` | **No issues found**. |
| `fvm flutter build web --release` | **Built `build/web`**. |
