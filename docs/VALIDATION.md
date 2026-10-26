# Mobile validation record

25 October 2026. Flutter 3.47.7 / Dart 3.13.5 on macOS arm64. Commands use the repository-pinned FVM SDK.

| Check | Result | Evidence or limit |
| --- | --- | --- |
| Dart formatting | PASS | [Format output](validation/dart-format.txt) |
| Flutter analyzer | PASS | [Analyzer output](validation/flutter-analyze.txt) |
| Automated suite | PASS, 148 tests; 1 live-gateway test skipped because credentials were not supplied | Current `fvm flutter test`; [earlier captured output](validation/flutter-test.txt) |
| Release web preview | PASS | [Build output](validation/flutter-build-web.txt) |
| Shared demo seed | PASS | Root `python3 scripts/sync-client-demo-data.py --check` |
| Diff whitespace | PASS | `git diff --check` in mobile |
| Android build and device | NOT RUN | Android SDK is not installed on this machine |
| iOS build and device | NOT RUN | Full Xcode platforms and production signing are unavailable |
| Live HR API | NOT RUN | No runnable business API or accepted contract is supplied |

[Flutter doctor](validation/flutter-doctor.txt) records the platform gaps. The web build is a mobile-layout demonstration, not a native or Nuxt acceptance build. The [candidate endpoint inventory](validation/feature-endpoints.json) has 71 case routes and is checked against feature code; [workflow routes](validation/workflow-routes.json) map all 40 source business flows to a client view or explicit backend/operator ownership.

Visual references have separate macOS and Linux images because their host renderers produce different pixels with the same bundled fonts. `test/visual_test.dart` selects the host reference. The manual `Generate Linux visual references` workflow creates a downloadable artifact for review; it never commits approved images automatically. Normal CI compares against committed Linux images.

The 26 October 2026 Linux reference run [40349098723](https://github.com/sakkol-git/meakea-attendance-tractker-mobile-app/actions/runs/40349098723) passed on the pinned Flutter SDK and produced 14 PNGs at 402 × 874. Its downloaded images were compared with the macOS references; the home view was visually inspected and showed the same layout and content. The artifact images are committed under `test/goldens/linux/`. Local macOS visual tests pass against the original references; the next Linux CI run must verify the committed Linux set.

Automated checks cover the local employee, manager, HR and owner journeys; every feature panel/editor at 360 px and 200% text; main HR workflows at 800 × 1280 and 150% text; visual reference screens; role and ownership guards; shift snapshots and interval overlap; clock records, grace boundary, corrections and daily finalization; exact leave reservations, future cancellation, adjustments, year-end and conflicts; request reviewer snapshots, partial material issue and stock ledger; own notifications; report/export behavior; local receipt replay and persistence. Release-configuration checks refuse an implicit local-data release, reject unsafe remote API URLs and retain explicit demo and safe remote builds. The architecture suite prevents new oversized source files and growth of reviewed exceptions. Remote fixtures exercise bearer refresh rotation, support-reference formatting, old-account race protection, DTO/paging/ETag parsing, cache encryption/bounds/TTL/stale fallback, 412 cache invalidation and session changes during asynchronous native-data reads. These controlled tests do not prove the missing backend's authorization, distributed transaction behavior, push delivery or native plugin behavior.

The rebuilt preview was also opened in a clean browser tab: HR sign-in, All workflows, year-end carry-over preview/review and cancellation returned to the underlying list. [Year-end review screenshot](screenshots/year-end-review.png). Earlier manual browser evidence includes the employee sign-in, clock-in/out, persisted demo draft/submission and HR dated-shift journey from the preceding checkpoint: [dashboard](screenshots/home.png), [submitted request](screenshots/request-submitted.png), [shift assignment](screenshots/shift-assignment.png). The current release preview is available locally at `http://127.0.0.1:8766/` when its server is running. Fictional demo data can be reset under Profile.

Before a production release, accept the gateway contract and execute cross-tenant employee/manager/HR/owner API journeys, duplicate and timeout-after-commit commands, authorization changes, private file checks and notification delivery. Build signed Android and iOS packages, then test secure storage, device authentication, foreground location, permissions, file picking/sharing, accessibility and company privacy/legal policy on real devices. Changing only the gateway URL cannot satisfy those missing server and native release gates.
