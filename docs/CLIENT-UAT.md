# Mobile client UAT

Use this runbook for a repeatable client review before connecting a live backend. It validates native presentation and synthetic workflow logic; it does not establish server authorization, persistence, tenant isolation or production integration.

## Setup and evidence

- Given remote mode without an account, open workspace setup and getting-started help. Expect HR-provided workspace/account instructions, no public account-creation command and clear password-assistance guidance. Demo setup must remain explicitly labelled.
- From sign-in and Profile, open Help and getting started. Follow the first-workday navigation and location-permission recovery explanations without developer terminology.
- Given a request with entered title, reason, materials or dates, expand Review details, edit a field and verify the summary updates while other values remain. Saving a request is still a draft; submission happens from its details.
- Given a chosen start date, open the end-date picker. Earlier end dates must be unavailable. Restored values outside the picker window must not crash or change merely because the picker was opened. Cancel and confirm entered values remain.

1. Run `fvm flutter pub get` and `fvm flutter run` with the default local data source.
1. In Profile, use **Reset demo** before each role journey.
1. Test Android API 24 or newer and iOS 15 or newer. Include one low-end Android device, one current Android device and one supported iPhone before release.
1. Repeat core journeys in portrait and landscape, light and dark appearance, and 200% text scaling.
1. Record device, operating-system version, role, scenario, result and a screenshot or recording for any failure.

## Role journeys

| Role | Scenario | Expected result |
| --- | --- | --- |
| Employee | Sign in, clock in, view history, clock out | Current attendance and history update once; repeated commands do not create duplicates |
| Employee | Create a half-day leave request with evidence, save a draft, leave the screen, restore, edit and submit it | Draft content survives navigation; required fields and evidence are enforced; status and wording match web |
| Employee | Create a general or material request, attach a supported file, submit and cancel an eligible request | Status, quantities and available actions remain consistent across list and detail screens |
| Manager | Filter the approval inbox, inspect policy and age context, approve one item and reject another with a reason | Results load incrementally; decisions require current data and show clear success or conflict recovery |
| Manager | Create and cancel a delegation, then review team coverage | Self-delegation and overlapping dates are refused; coverage details remain usable without relying on color |
| HR | Create and edit an employee, assign a shift, add an overnight attendance correction and adjust leave balance | Typed catalog values persist; dates, reasons and resulting values are visible |
| HR | Approve and partially fulfill a material request | Requested, issued, remaining and stock values reconcile after each action |
| HR | Start an attendance report export, wait for completion, then save or share it | Queued, running, completed and failed states are understandable; native file action appears only when ready |
| Owner | Review organization settings, audit activity and role-restricted workflows | Owner-only navigation is visible and employee-only or operator-only actions remain guarded |

## State, accessibility and device pass

The subsequent usability polish adds these acceptance examples:

- Given a scrolled request form with invalid fields, when Save request draft is pressed, then the first invalid field is revealed, a nearby error is announced and all entered values remain. Repeat with the keyboard open and 200% text.
- Given a search with no matching requests, when Clear filters is pressed, then the search text and status clear and the unfiltered records return. A pending search timer must not restore the old query.
- Given reduced-motion settings, when a read is loading, then its text remains understandable without an animated spinner. Failed reads must announce a recovery action rather than an empty count.
- Given a slow leave preview, when Send for approval is pressed, then the action shows Saving and prevents repeated submission or edits until the check completes. A failed preview must restore the action and retain the reason and selected dates.
- Given Unread only with no matching notifications, when Show all updates is pressed, then the full inbox returns. Legacy updates explain that no linked record is available. Saved-data notices retain the update time and show task names rather than technical routes.
- On web, return from request details and confirm search/status/page preferences survive. Switch accounts or demo roles and confirm those preferences clear.
- On web, select correction date/time values in the displayed company zone, including overnight work. Confirm original sessions, missing-history feedback and the submitted result; users must not need to type a UTC offset.
- On web, choose Dark, reload, then choose Use device setting and change the operating-system appearance. Explicit Light/Dark choices override device changes. Repeat form, menu, table and error-state review in each appearance.
- Observe at least one employee, manager and HR reviewer completing clock-in, leave, request, correction and approval tasks without coaching. Record completion, hesitation, mistakes and recovery; treat these as observations, not an automatic usability score.

The 29 October UI pass adds the following checks to the existing device review:

- Open Tasks as each role. Daily HR actions should be easy to find, and service-readiness processes should not appear in the task list. Open a leave/request/correction detail and confirm its parent destination remains selected.
- Use a small phone with enlarged text and the keyboard open. Scroll the request fields and confirm Save request draft or Send for approval remains reachable without dismissing the keyboard. Submit invalid input and confirm the entered values survive.
- Simulate an approval read failure on the home screen. The role work card must explain unavailable counts rather than claiming there are no approvals. Verify team/people/audit shortcuts only appear for the intended role.
- Review a record without decision context. Missing team absences, balances and completed approval stages must stay unknown. Compare the same record and terminology on web.
- Generate consecutive success messages. The latest result should replace the previous snackbar instead of leaving a queue of stale confirmations.

The corresponding web review covers 320px attendance cards, complete date/time/state visibility, compact summary, readable date filters, explicit Share location permission recovery, and a footer that does not present optional live-notification connectivity as workspace health. Khmer language support is a separate pending phase and is not part of this English-screen acceptance claim.

- Confirm every visited screen has a useful loading state, empty message, recoverable error and success feedback.
- Disable connectivity before a write. The client must explain that the action was not confirmed and must not invent success.
- Exercise a stale-version conflict. Preserve entered text, explain the conflict and offer a safe refresh or retry path.
- With TalkBack and VoiceOver, confirm meaningful names, reading order, state announcements and no unlabeled controls.
- With the largest supported text size, confirm primary actions remain reachable above the keyboard and content does not clip.
- Confirm touch targets are at least 44 logical pixels, focus is visible with a hardware keyboard and status meaning does not rely on color.
- Verify denied location, camera, files and notification permissions produce an explanation and recovery path.
- Lock and reopen the device, then sign out. Confirm protected content is not exposed in the app switcher and the previous account cannot reappear.

## Completion record

Mark a scenario **automated** only when a named test covers it, **manual device** after it passes on hardware, or **blocked** when it needs a real API, production identity or representative user. Emulator and widget checks do not replace the device pass.
