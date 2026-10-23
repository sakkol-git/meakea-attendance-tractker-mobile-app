# HRFlow mobile

## Project

Android and iOS Flutter starter for HRFlow, package hrflow_mobile. This is the generated counter scaffold; HR features and API integration are not implemented.

This directory is an independent Git repository on main. The parent HRFlow repository ignores mobile/ in the same way it ignores web/. Commit mobile changes from this directory; no remote is configured yet.

## Pinned toolchain

Flutter 3.47.7 stable with Dart 3.13.5, selected from FVM's latest stable release on 2026-10-23. The exact Flutter version is committed in .fvmrc. Keep pubspec.lock committed for repeatable application dependencies. The .fvm SDK cache/link is ignored; do not commit the SDK.

Install FVM first. From the mobile directory, restore the pinned SDK and dependencies:

```bash
fvm install
fvm flutter pub get
fvm flutter --version
```

Expect Flutter 3.47.7 and Dart 3.13.5. Use fvm flutter and fvm dart for this project; the global SDK is not changed. If a command fails, check the selected SDK with fvm list and the platform prerequisites with fvm flutter doctor -v.

## Development commands

Run from the mobile directory:

```bash
fvm flutter analyze
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter test
fvm flutter doctor -v
fvm flutter devices
fvm flutter run
```

Analysis and the starter counter widget test should pass. The final command needs an available Android device/emulator or iOS simulator/device. Android builds need the Android SDK and accepted licenses; iOS builds need Xcode and its platform tools. Device signing is not configured by this scaffold. Doctor reports machine prerequisites separately from Dart analysis/tests.

## IDE setup

Open this directory as the Flutter project. For IntelliJ or Android Studio, select .fvm/flutter_sdk as the Flutter SDK path. The Dart SDK is inside .fvm/flutter_sdk/bin/cache/dart-sdk. Reopen the project if the IDE retains a different SDK.

## Git workflow

```bash
git status
git add lib test pubspec.yaml pubspec.lock
git commit -m "Describe the mobile change"
```

Review the diff before committing. Generated builds, local IDE files, SDK caches and local secrets are ignored. Root-repository commits do not save mobile changes; this repository needs its own remote/backup before collaboration.

## Setup verification

On 2026-10-23, Flutter analysis passed with no issues, Dart formatting required no changes, and the generated counter widget test passed (one test). Flutter Doctor found two platform-tooling gaps: Android SDK was not found and Xcode was incomplete. Android/iOS builds and device execution were not run. The global FVM selection was left unchanged.
