# HRFlow mobile installation and user guide

Confirm the supplied APK's build date and mode before sharing it. An earlier APK does not include later source changes automatically. See [API integration](API-INTEGRATION.md) for configuration and [client UAT](CLIENT-UAT.md) for acceptance checks.

## Before installation

The normal local output is `build/app/outputs/flutter-apk/app-release.apk` inside the mobile checkout. File size, supported devices and signing depend on the actual artifact; this guide does not certify an earlier build as the current release.

An explicit demo release uses `ALLOW_DEMO_RELEASE=true` and fictional local data. A remote build needs the configured API and the company workspace, linked account and sign-in instructions supplied by HR. A disconnected remote build never silently switches to demo.

Public account creation and email password recovery are unavailable. Contact HR for access or password assistance. Creating an employee record does not create a login account or send an invitation; linked accounts use the private operator setup workflow.

## Install by USB

1. Enable Developer options and USB debugging in the Android device settings. The exact menu varies by device.
1. Connect the phone to your Mac, unlock it and approve debugging for the computer you trust.
1. From the mobile checkout, install the supplied artifact using Flutter or ADB.

```bash
fvm flutter install \
  --use-application-binary=build/app/outputs/flutter-apk/app-release.apk
```

Alternatively, from the mobile checkout with Android SDK tools on PATH:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Open HRFlow after installation. Record installation or launch failures in the UAT checklist; a successful compile is not a device acceptance result.

## Install over local Wi-Fi

Use a trusted local network and share only the intended APK directory. From the mobile checkout:

```bash
cd build/app/outputs/flutter-apk
python3 -m http.server 8080
```

Find the Mac's network address, for example with `ipconfig getifaddr en0` when Wi-Fi uses en0. On the phone, open `http://<mac-address>:8080`, download the supplied APK and open it. If Android requests permission to install from this source, review and allow the intended source. Stop the temporary server with Control-C when finished.

For an emulator, start the intended Android emulator and drag the APK onto its window, or use ADB with the intended device selected. Verify the build's mode before using it for a demonstration or remote UAT.

## First sign-in

Open Help and getting started from sign-in for workspace and account explanations. Enter the company workspace separately from the work email. Use the credentials HR supplies; never share passwords.

In demo mode, the sign-in role cards open fictional Employee, Manager, HR and Owner workspaces. Demo workspace setup remains synthetic and sends no real invitation. Demo behavior and visible controls do not establish live server permissions.

## Your first workday

- Start on Home to clock in or out. Share location when ready; an estimate alone does not confirm attendance. If permission was denied, use the device settings to allow location for HRFlow and retry.
- Open Attendance to review recorded sessions and request a correction with a reason when needed. Missing history remains unknown.
- Open Leave to check balances and request supported full-day or half-day dates. Review the owner preview before sending for approval. Supporting leave files are disabled in this UAT slice; an evidence-required type fails closed.
- Open Requests, choose an available type and enter its relevant details. Expand Review details, save a request draft, then review and submit it from its details. The configured approval chain remains authoritative.
- Managers review their assigned decisions in Approvals. HR uses available people, schedule and leave administration destinations; private attendance CSV exports follow HR server authorization. Owners use permitted company administration and identity audit destinations.

Available navigation follows the signed-in role. This guide does not promise payroll finalization, arbitrary manual attendance changes, automatic stock deduction or broader provisional workflows.

## Recover without losing work

Review details reflects current form values without submitting. Opening or closing it should preserve title, reason, selected materials and dates. Check the highlighted field after a validation error; other values should remain.

A saved workplace request draft differs from unsaved form recovery. Follow the form's recovery message and keep it open when recovery is unavailable. For an unconfirmed command, check its record or attendance history before retrying. Retain the support reference and contact HR if the result remains unclear.

Open Help and getting started from Profile for permission, draft and command guidance. Profile's Reset demo action replaces fictional local changes; it is not a remote reset. All workflows is a developer/demo catalog, not proof that every listed flow has a provider. Use daily navigation for normal work.

Use the [client UAT checklist](CLIENT-UAT.md) to record physical-device, accessibility and representative-user results. Server setup, deployment, backup/restore and release approval remain separate operator work.
