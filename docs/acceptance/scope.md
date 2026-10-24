# Acceptance scope decisions

User decisions received 24 October 2026 are recorded below. Where the reply was not specific enough to define an acceptance target, the choice remains open. Tests may use current demo behavior but must not treat it as approved company policy.

| Decision | Options or detail required | Answer | Owner/date |
| --- | --- | --- | --- |
| Identity | Password only, password + MFA, or enterprise SSO | Password only | User, 24 Oct 2026 |
| Launch languages | English only, or English and Khmer | English only | User, 24 Oct 2026 |
| Company time zone | Fixed UTC+07, or per-company IANA zone | Fixed UTC+07 as current-client working choice; user answered “whatever” | Agent assumption, 24 Oct 2026 |
| Supported devices | Minimum Android/iOS versions and one low-end Android reference device | Android API 24 / iOS 15 confirmed; low-end reference device still unspecified | User, 24 Oct 2026; device open |
| Tenant scale | Employees and requests per month for performance budgets | Provisional 25 employees and 25 requests/month; user replied “25” without specifying which measure | Agent interpretation pending correction, 24 Oct 2026 |
| Approval policies | Delegation, escalation and bulk approval: in or explicitly out | Delegation in; escalation and bulk approval treated as out pending correction | User plus agent assumption, 24 Oct 2026 |
| Sensitive drafts | None, encrypted local, or server-side storage | Server-side | User, 24 Oct 2026 |

The overnight-correction maximum is currently 24 hours in the local service. It is a provisional named acceptance assumption, **not** a business-approved limit. Confirm or revise it with the time-zone decision before Phase 1-C is accepted.
