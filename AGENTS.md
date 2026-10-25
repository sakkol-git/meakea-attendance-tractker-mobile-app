# HRFlow mobile instructions

Read the parent `AGENTS.md` when this repository is checked out inside HRFlow. For standalone checkout, begin with this repository's architecture and integration guides in `docs/`.

- Inspect source and Git status; this client has an independent Git history.
- Treat `contracts/openapi.json` and its fixtures as generated copies from the backend repository's `contracts/` directory. Do not hand-edit a bundle to hide drift.
- `contracts/bundle.json` identifies the source content digest. Coordinate contract changes in all three repositories and run the parent's `scripts/contracts.py check` with all checkouts present.
- The shared leave contract is provisional. Other routes and DTOs remain client expectations until backed by an accepted server contract and real integration tests.
- Assess the other client, server, contracts, schema/events and deployment for behavior changes. Explain why a boundary needs no edit.
- Preserve opaque ETags and command keys, fail remote requests honestly, and keep tenant/resource authorization on the server.
- Run the repository CI commands before claiming completion. Record tests and limitations; update current integration docs alongside behavior.
- Do not modify unrelated working changes, commit, push or deploy unless requested.

## Business-first engineering rules

- Business requirements and agreed acceptance criteria are the primary success measure. Trace behavior to an owning requirement; do not invent HR policy, endpoints, fields or supported infrastructure. Record unknowns and confirm blocking business ambiguity before dependent work.
- Apply SOLID to responsibilities and dependency boundaries: one reason to change, extension at proven variation points, substitutable implementations, small consumer-focused interfaces, and business logic independent of transport/storage details. Do not create abstractions solely to satisfy an acronym.
- Organize by feature and responsibility. Keep domain rules separate from UI, HTTP and persistence; wire dependencies in a composition root. Follow existing accepted architecture and repository conventions; avoid new frameworks or layers without a concrete need.
- Keep files, components and directories cohesive and beginner-friendly. Use plain domain names, explicit types, small focused functions and shallow navigation. Prefer existing patterns and brief comments explaining why. Aim for about 250 lines per handwritten source file; review files over 300 lines for unrelated responsibilities. Extract meaningful modules, never arbitrary fragments. Generated artifacts and justified cohesive exceptions must be identified.
- Avoid monster components, catch-all utilities, giant services and mixed business/transport/UI logic. A small feature may stay simple; not every operation needs an interface, factory, repository or use-case class.
- Choose the simplest approach that meets correctness, security, maintainability and operating constraints. State material tradeoffs in adoption, delivery time, recurring cost and maintenance; do not add speculative extensibility or paid services without a justified requirement.
- Use BDD-style Given/When/Then acceptance examples for workflows and ambiguous business behavior; use TDD red-green-refactor for meaningful business logic, regression fixes and contracts. Confirm a test fails for the expected reason, implement the smallest correct change, then refactor. Use proportional verification for documentation, formatting and mechanical changes; do not create tests that merely mirror code.
- Ground factual claims in inspected files, accepted decisions, official primary documentation or executed commands. Separate observation, proposal, assumption and unknown. Do not claim zero hallucinations, complete context, passing checks or production readiness without evidence; disclose uncertainty and verification limits.
- Use narrow searches and bounded source excerpts. Prefer available HRFlow MCP tools for repeated context/read/search/check work; use existing CLI checks when the tools are unavailable. Reuse evidence only while its source revision, working changes and inputs remain valid; never sacrifice required verification to save tokens.

## Compact test evidence

- When HRFlow MCP tools are available, use `run_tests` for a relevant suite/file, then `get_test_result` for structured counts and failures. Request `get_test_details` only for a selected stack or log excerpt. Use `cancel_test_run` for work that should stop.
- Do not infer success from a console tail, reuse stale reports or treat partial/zero-test runs as acceptance. Grouped messages identify repeated evidence, not a proven root cause. Run the broader verifier when required; narrow unit runs omit builds, lint and other scopes.
