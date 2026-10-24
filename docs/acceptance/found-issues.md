# Additional issues found during acceptance work

- **Legacy admin-dialog controller lifecycle:** Closing an edited department dialog in the widget probe can rebuild a `TextFormField` after its `TextEditingController` was disposed. Reproduce with `fvm flutter test test/acceptance/enterprise_regressions_test.dart --plain-name 'acceptance F10 dirty admin dialog asks before discard'`. The same test also confirms the missing discard prompt. Investigate when consolidating the editors in P1-A or guarding drafts in P2-C; do not treat this as fixed by the Phase 0 test.
