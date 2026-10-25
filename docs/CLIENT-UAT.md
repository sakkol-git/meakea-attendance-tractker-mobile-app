# Mobile client UAT

Use this runbook for a repeatable client review before connecting a live backend. It validates native presentation and synthetic workflow logic; it does not establish server authorization, persistence, tenant isolation or production integration.

## Setup and evidence

1. Run `fvm flutter pub get` and `fvm flutter run` with the default local data source.
2. In Profile, use **Reset demo** before each role journey.
3. Test Android API 24 or newer and iOS 15 or newer. Include one low-end Android device, one current Android device and one supported iPhone before release.
4. Repeat core journeys in portrait and landscape, light and dark appearance, and 200% text scaling.
5. Record device, operating-system version, role, scenario, result and a screenshot or recording for any failure.

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
