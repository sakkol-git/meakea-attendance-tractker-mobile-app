# HRFlow mobile

Flutter employee and management client with a persistent local demonstration and a separately selected remote API adapter. The app replaces the generated counter scaffold. Current delivery: 24 October 2026.

## Run

The pinned SDK is Flutter 3.47.7 / Dart 3.13.5; keep `pubspec.lock` with the application.

```sh
fvm install
fvm flutter pub get
fvm flutter run
```

Local mode is the default. Choose Employee, Manager, HR, or Owner from the demo sign-in screen. All identities and data are fictional. Changes survive app restart on that device; Profile → Reset demo clears them. Mobile and web do not share demo state.

```sh
fvm flutter run --dart-define=DATA_SOURCE=remote --dart-define=API_BASE_URL=https://hr.example.com/api/v1
```

Use the same defines for release builds. Remote mode never falls back to synthetic data. A configured URL is sufficient only when the backend implements the documented adapter contract; no live HR API exists in this checkout.

## Included experiences

- Employee dashboard, clock-in/out, attendance history, inferred-record review, corrections, HR manual entries, daily calculation/finalization and reviewed geofence evidence.
- Leave reservations and balances, half-day/cross-year requests, future approved cancellation, HR ledger adjustments, carry-over previews and conflict resolution.
- General, material, remote-work, late-arrival and early-leave requests; drafts, edits, submission, cancellation, files, and review.
- Manager approval inbox, team attendance, people directory and attendance exports.
- HR/owner onboarding, invitations, lifecycle and role changes; sites, calendars, shift-policy snapshots and effective-period closure; inventory receipts and partial issues; filtered reports, export history and recovery requests.
- Profile editing, own notification preferences/devices/delivery, Firebase registration and safe record links, dark appearance, remote password change, secure session persistence and refresh rotation.
- Native device authentication for app unlock; Android/iOS permission configuration is included. This uses the operating system's device credentials/biometrics, not a custom application PIN.

Open **Profile → All workflows** to reach feature screens. All 40 business-flow entries have documented client/operations ownership in the coverage map.

English copy is implemented; the bundled Kantumruy Pro font also supports Khmer glyphs. Khmer translation is not implemented. UI follows the teal design direction in the parent `client-design/` documents and extends the unfinished mobile Figma reference.

## Architecture and integration

Read [architecture and cache policy](docs/ARCHITECTURE.md), [API adapter contract](docs/API-INTEGRATION.md), [workflow coverage](docs/WORKFLOW-COVERAGE.md), and [validation record](docs/VALIDATION.md).

**Feature-first clean architecture:** each business module owns domain, application, data and presentation folders. `app/composition.dart` injects independent feature repositories; shared infrastructure handles transport, cache and storage. Domain models and workflow policy are independent of Flutter and storage. Application providers depend on ports; data adapters implement those ports. Riverpod composes dependencies and asynchronous state, GoRouter handles guarded navigation, encrypted Hive caches remote reads, and native secure storage holds tokens and encryption keys. Generic catalog metadata and command paths remain explicit provisional extension boundaries rather than generated OpenAPI types.

## Checks

```sh
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
fvm flutter build web --release
fvm flutter doctor -v
```

The web target is a mobile-layout preview, not the Nuxt web client. Screen reference images are in `test/goldens/`. Android needs an installed SDK; iOS needs Xcode, signing and device testing. Neither platform toolchain is available on this machine, so native build/device acceptance remains open.

This directory is an independent Git repository nested under the parent HRFlow repository. Review and save mobile changes here; parent commits do not include them. No commit or deployment is performed by this delivery.
