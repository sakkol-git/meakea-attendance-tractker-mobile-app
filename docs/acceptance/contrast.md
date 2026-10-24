# Semantic color contrast, 24 October 2026

The `acceptance F03` test calculates WCAG contrast from `SemanticColors` for both themes. Text pairs require at least 4.5:1; control indicators require at least 3:1. Status remains a word plus color. These are representative minimum functional pairs; the test enumerates every semantic role pairing used by shared status and navigation controls.

| Pair | Light | Dark | Minimum |
| --- | ---: | ---: | ---: |
| Primary on surface | 13.82 | 17.23 | 4.5 |
| Primary on card | 14.85 | 15.23 | 4.5 |
| Muted on surface | 5.77 | 10.89 | 4.5 |
| Muted on card | 6.20 | 9.63 | 4.5 |
| Error on card | 7.25 | 9.63 | 4.5 |
| Success on pill | 6.61 | 8.89 | 4.5 |
| Error on pill | 6.24 | 8.24 | 4.5 |
| Warning on pill | 5.91 | 8.57 | 4.5 |
| Info on pill | 6.25 | 8.31 | 4.5 |
| Selected navigation on indicator | 6.59 | 8.89 | 3.0 |
| Focus on card | 7.42 | 10.99 | 3.0 |
| Divider on card | 3.92 | 5.95 | 3.0 |
| Hero text on hero | 7.42 | 7.42 | 4.5 |
| Hero muted on hero | 5.91 | 5.91 | 4.5 |
| Hero indicator on hero | 5.24 | 5.24 | 3.0 |

Dark visual references are `test/goldens/dark-home.png`, `dark-leave.png`, `dark-request.png`, and `dark-approvals.png`. The feature tree and shared widgets use semantic theme roles; an acceptance source test rejects literal ARGB colors outside `core/theme.dart`.
