# iCloud sync repair review — 15 October 2026

Final assessment: **PASS**, read-only source review by the independent icloud_review agent. Actual second-Mac acceptance remains pending.

The unchanged cloud head incorrectly classified ordinary saved local edits as simultaneous edits. The installed fix permits retry while still rejecting altered applied-revision content and preserving real remote/local divergence. Incomplete parent history waits before publication. Native cloud reads request missing/stale downloads and report a retry state.

Two findings were corrected before installation:

1. Pending saved mode names could disappear after a waiting/failed publication. Validated saves now persist a local pending snapshot, which survives restart; the agent retries its names and explicit empty deletions.
2. A redundant pending snapshot equal to the previous baseline could undo newer incoming mode names. Adoption now clears pending settings matching either the incoming revision or the previous baseline, while preserving genuinely different edits. Explicit conflict choices clear superseded pending settings.

Each finding was reproduced with a failing regression before correction. The final suite passed: 107 Python, 99 Swift, 80 JavaScript. The reviewer ran no builds/tests and made no edits.

Installed evidence: version 0.1.17/build 19, unchanged signing identities, all input permissions retained, helper running, no pending board edits, board revision unchanged. The real cloud head contains all three saved Mac-action bindings, is reported uploaded by iCloud, and was received by a fresh independent local client with a separate writer identity. All previous live cloud records remain byte-identical.

Limits: no actual second-Mac run, no physical evicted-file download experiment, no claim of full physical action acceptance, and no notarization. Broader pre-existing history validation and empty-name UI presentation were outside this patch. The current physical keyboard configuration and incoming board-match gate were preserved.
