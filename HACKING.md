# HACKING.md

Rules for offensive-security / research sessions. These override convenience.

## Changes to the target

1. **Ask before modifying anything a human could notice later.** If a change leaves a visible trace (created account, changed email, altered role list, uploaded file, sent email, new registry entry), confirm with the user first. Be maximally loud when the change is not reversible.
2. **Never destroy or corrupt target data.** No deletions, no overwrites of records that are not ours, no writes to stores that others depend on.
3. **Do not affect real users.** If a technique would send emails, block logins, or change visible state for accounts we do not own, ask first and use a single test target.

## Evidence and cleanup

4. **Keep a running ledger of every state change made to the target.** Account created (id, email, password), role changed, file uploaded, record created, CA imported, email triggered. Store it in the target's project dir (`NOTES.md` or `ledger.json`). Every entry must be undoable-by-reference: exact endpoint, exact identifier, exact current value.
5. **The ledger exists so cleanup is possible.** On request, reverse every entry or produce a report of what cannot be reversed and why.
6. **Before ending a session, report the ledger state.** What changed since the last report, what is still standing, what is now stale.

## Persistence and access restoration

7. **Always suggest a persistence option when access is obtained.** If the current path is patched or an account is disabled, there should be a documented way back in: a secondary account, an unpatched alternative endpoint, a saved refresh mechanism, a controllable recovery email, an importable CA.

## External resources

8. **Ask the user to provide external resources.** If the work needs a VPN, a proxy, a temporary email service, a phone number, a domain, or any similar third-party resource, request one from the user instead of choosing one unilaterally. Never use a disposable service (Mailinator and the like) or connect through a VPN exit without prior approval.

## Discipline

9. **One loud failure beats three silent fallbacks.** If a path that used to work returns 403/401/changed behavior, report the regression with the exact request and response. Do not silently route around it.
10. **Save the evidence as you go.** Request/response pairs for anything load-bearing: account takeover, role changes, created records, signature validation. Store under the target's artifacts dir with a sidecar or in NOTES.md.
