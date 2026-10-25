# Mobile client quality gates

These gates protect client behavior without claiming backend or physical-device acceptance.

## Automated on every change

- Dart formatting, analyzer, architecture, workflow, adaptive-layout and golden tests.
- Refusal of implicit local data in a release and validation of the remote `/api/v1` URL.
- Compilation of a remote-mode release APK and an explicitly marked demo web preview in CI.
- A 300-line cohesion threshold for new Dart files. Existing reviewed files are capped at their current size and must shrink when their responsibility is touched.

## Reviewed large-file exceptions

The current exceptions are listed beside their limits in `test/architecture_test.dart`. The synthetic service kernel and feature-local handlers contain the local demonstration state machine. Large presentation files compose established workflows. They are technical debt, not a pattern for new features. Split them by feature state, form section or reusable presentation responsibility during related changes, then lower or remove the matching limit.

Shared case metadata and the paged lookup were already extracted from `case_page.dart`. Further arbitrary slicing would make state flow harder to follow, so the editor and request form should be decomposed alongside their next behavior change with focused widget tests.

## Manual before release

Run [client UAT](CLIENT-UAT.md) on the supported Android and iOS versions, including a low-end Android device. Verify TalkBack, VoiceOver, largest text, landscape, keyboard-open layouts, secure storage, device authentication, permission denial, file sharing and app-switcher privacy. Profile startup, frame rendering, memory and cache size on hardware. Signed builds and representative-user evidence remain external gates.
