# KLAWOS Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task after explicit coding authorization. Steps use checkbox (`- [ ]`) syntax for tracking. Delegation/execution method is not selected; do not launch subagents, create a repository, or execute this plan during the current planning-only request.

**Document revision:** 1.3 — implementation in progress; approved commissioning and gaming-output preservation.

**Goal:** Build the separate KLAWOS 3D configurator with full device-supported Vial features and automatic Codex/Claude Work actions, packaged for both Macs.

**Architecture:** A Cocoa/WKWebView host loads bundled UI assets and talks to a native current-user agent over XPC. The agent owns device input, app context, actions and serialized HID operations; a bundled Python worker adapts Vial's protocol/model logic over correlated pipes. Hardware configuration, Mac action profiles and presentation metadata remain distinct and are reconciled by verified Apply operations.

**Tech Stack:** macOS 14+, Swift/Cocoa, WebKit, IOKit, XPC, bundled Python 3.12, Vial GUI tag `v0.7.5`, vendored Three.js `0.180.0`, plain JavaScript/CSS, Blender for development assets only.

**Spec:** [SPEC.md](SPEC.md), specification version 1.3 dated 14 October 2026. Read it completely before starting. This plan is complete for review; all implementation-step checkboxes are intentionally unchecked. Test snippets are future test contracts in this document, not implemented tests.

## Global Constraints

- Do not start coding yet. Completing or approving these documents does not itself authorize implementation.
- Project home is `/Users/philip.scholl/_WORK/KLAWOS`. Private-repository creation belongs to the later implementation phase.
- Separate app; preserve the existing Micro Studio, FreeMicro installation, live Micro config, and dirty source tree.
- Work actions automatically follow Codex, Claude, or the Default Work context.
- Wheel press retains Work → Dota → Wardogs → Work. Work rotation retains scroll up/down.
- App delivery targets both Macs. Windows app development is outside this scope; ordinary keyboard-resident mappings remain portable according to their target OS and keyboard layout.
- Technology baseline: macOS 14 or later; Swift/Cocoa, WebKit, IOKit and XPC; bundled Python 3.12 runtime; adapted Vial GUI source tag `v0.7.5`; locally vendored Three.js `0.180.0`; plain JavaScript/CSS.
- Initial product version `0.1.0`; specification/project format has independent version 1.
- Store app data under `~/Library/Application Support/KLAWOS Studio/`, with owner-only permissions for project/action data.
- Draft autosave is atomic and debounced by 300 ms; Apply flushes it first.
- Retain the last 20 pre-write project backups per device definition; never delete a backup referenced by an unresolved recovery record.
- A `.vil` backup alone is incomplete for this app's lighting features.
- Vial writes settings sequentially. A multi-setting save cannot be represented as an atomic device transaction.
- Closing the editor leaves the helper active; gameplay bindings and the hardware wheel cycle must work when it is stopped.
- Never disable Gatekeeper, MDM, or Input Monitoring to make a test pass.
- No changes to protected Claude/Codex configuration or the MainBrain architecture are part of this project.

## Review Focus

The following conditions need explicit tests beyond ordinary happy-path feature coverage:

1. The 64-bit definition UID loses precision in JavaScript, or two matching pads appear: preserve the UID string and require selection of one actual device. Owners: tasks 1, 2 and 10.
2. Another editor changes macro memory or a cable disappears after some writes: retain unrelated values, journal partial state, and recover without blindly replaying. Owners: tasks 4 and 5.
3. Focus changes during a held key, or synthesized output re-enters the helper: keep the press/release context paired and do not fire twice. Owners: tasks 3 and 6.
4. The helper stops, permission is revoked, or the app is upgraded: release held state, keep gaming inputs usable, and show the actual runtime generation/availability. Owners: tasks 6 and 12.
5. Imported macros/metadata are malformed, contain unknown future fields, or carry executable/machine-specific content: preserve safe unknown data, reject unsafe writes before device access, and execute nothing on import. Owners: tasks 1, 4 and 11.

## Future file map

No files below are created by this planning request. Paths are relative to the KLAWOS project root unless explicitly described as external read-only references.

| Paths | Responsibility |
|---|---|
| `VERSION`, `README.md`, `.gitignore`, `THIRD-PARTY.md`, `build/manifest.json` | Version, operator instructions, exclusions and pinned provenance. |
| `native/Package.swift`, `native/Sources/KlawosContracts/Contracts.swift` | Two native executables and their shared typed request/state contracts. |
| `native/Sources/KlawosAgent/{AgentMain,HIDTransport,InputRouter,TriggerAllocator,ContextRouter,ActionExecutor,ActionCatalog,WorkerConnection,ProjectStore,ApplyCoordinator,AgentService,Diagnostics}.swift` | Native agent, one file per named responsibility. |
| `native/Sources/KlawosAgent/{MacroRecorder,ImportExport}.swift` | Explicit foreground macro recording and native file-format/file-dialog handoff. |
| `native/Sources/KlawosStudio/{AppDelegate,WebBridge,AgentClient,PermissionGuide}.swift` | Native editor window, allowed UI bridge, XPC client and recovery guidance. |
| `native/Tests/KlawosTests/*.swift` | Transport-independent native unit/integration contracts. |
| `service/klawos_device/{worker,model,keycodes,macros,features,lighting,diff,validation}.py` | Headless adaptation of Vial protocol and model; modules grouped by responsibility. |
| `service/klawos_device/project_format.py` | Portable project and Vial-compatible import/export serialization. |
| `service/upstream/vial-0.7.5/` | Only the reused upstream files and license notices; provenance identifies changes. |
| `service/data/qmk_settings.json`, `service/tests/test_*.py` | Pinned upstream settings schema and fixture-only backend tests. |
| `ui/{index.html,styles.css,app.js,bridge.js,board-viewer.js,key-editor.js,advanced-editor.js,recovery-view.js}` | Bundled editor shell, viewer, drafts, supported-feature tools and recovery flow. |
| `ui/vendor/three/`, `ui/models/{klawos.glb,control-map.json,poster.png}` | Offline runtime assets and stable input/model mapping. |
| `art/board/{reference,klawos.blend,build_board.py,asset-review.md}` | Supplied screenshot/model, editable reconstruction and measurements/estimates. |
| `tests/fixtures/{baseline.vil,capabilities.json,lighting.json,project.klawos,malformed/}` | Sanitized deliberate fixtures; never the live Micro configuration or transcript. |
| `tests/ui/{editor,advanced,recovery,accessibility}.test.mjs`, `tests/integration/*.md` | Pure UI contracts and recorded physical/native acceptance procedures. |
| `scripts/{check,build-app,package-release,verify-package}.sh` | Future documented build/check entrypoints; no installer or build script is written now. |
| `packaging/{Info.plist,AgentInfo.plist,com.pippo.klawos.agent.plist}` | Stable product/agent identity and current-user macOS service registration. |
| `docs/{CAPABILITIES,ACCEPTANCE,RELEASE,REVIEW}.md` | Measured feature matrix, both-Mac evidence, release/rollback and final review. |

Do not create a general plugin framework, cloud API, app updater service, project database, or cross-device live sync. The device protocol, helper and editor are tightly related milestones of this product; each task below has an independently reviewable result. No task assumes another subsystem is already proven merely because its mock tests pass.

## Contract index

Shared contracts are defined in task 1. Later tasks must use these names without redefining parallel types.

- `DeviceIdentity.uid` is a decimal String. `DeviceDescriptor.pathToken` is an opaque selected-device token.
- `Snapshot`, `Draft`, `Capabilities`, `LightingState`, `HelperConfiguration`, `ChangePlan`, `ApplyResult`, `ContextSnapshot`, `InputSample`, `PressToken`, `ActionDescriptor`, `ActionResult`, `AgentRequest`, `AgentResponse` are Codable/native JSON equivalents, using the fields in SPEC §6–8.
- `AgentRequest` includes `requestID`, operation, selected-device generation and optional draft revision. `AgentResponse` echoes them; errors carry stable codes and plain-English recovery text.
- `WorkerMessage` contains `requestID`, `operationID`, kind (`command`, `exchange`, `exchangeResult`, `result`, `error`) and validated payload. One logical device operation runs at a time.
- `InputSample` is transient source identity, key/usage sequence, phase and synthetic flag; it is never diagnostic/log content.
- `HelperConfiguration` has a generation UUID, trigger-map revision, and per-input Default/Codex/Claude bindings. `PressToken` freezes context and action for paired release.

Additional shared names defined in task 1, before consumer tasks:

| Type | Exact role/shape |
|---|---|
| `JSONValue`, `FieldEdit`, `FieldPath` | Lossless JSON value; `{path: String, value: JSONValue}`; canonical path into hardware, lighting, metadata or profiles. |
| `InputID`, `FeatureID` | String input ID (`key:r:c`, `encoder:0:ccw/cw`); fixed supported-feature enum from SPEC §4. |
| `DeviceOperation`, `BackupRef` | `{operationID, fieldPaths, expectedOld, desiredNew, regionID}`; `{backupID, projectID, deviceIdentity, revision}`. |
| `MergeResult`, `ValidatedProject` | `{snapshot, conflicts: [FieldPath]}`; validated format-1 project plus preserved extension fields. |
| `RecoveryJournal`, `RecoveryChoice` | Operation progress, pre-write backup, staged helper generation and observed values; choice enum keepCurrent/completeIntended/restoreChangedRegions. |
| `TriggerPlan`, `RoutedInput`, `StopReason` | `{allocations, fieldEdits, sourceRevision}`; passThrough/helperPress/helperRelease/ignoredSynthetic; stop/disconnect/permissionRevoked/generationChanged/crashRecovery. |
| `ContextBindings`, `ResolvedBinding` | Default plus exact bundle-ID overrides for one input; `{profileID, inherited, action}` with explicit None. |
| `Availability`, `RecordingStatus` | ready/unavailable/unknown with reason; recording session ID, active flag, permission state and event count. |
| `FeatureModel`, `FeatureEdit`, `MacroEvent` | Feature ID/capability/schema/current entries; entry/field/value edit; text/tap/down/up/delay event with validated parameters. |
| `WorkerOperation`, `WorkerResult` | Fixed operation enum and validated payload; one typed snapshot/capabilities/validation/change-plan/verification result. |
| `AppMetadata`, `PortableProfiles`, `ImportPreview` | Layer/input labels/icons/display layout; portable action IDs/context bindings; validated proposed project, missing local bindings and change summary. |
| `DiagnosticState`, `BridgeMessage`, `BridgeResponse` | Redaction-allowlisted metadata only; allowlisted operation/correlation/generation/revision/payload; correlated response/error. |

Use one Codable schema with Python/JS equivalents; do not add separate subtly different UID, snapshot or action representations. Swift types with fixed enum cases may encode case names; JSON uses the stated field names.

---

### Task 1: Baseline, contracts and reproducible development setup

**Files:** Create the version/provenance files, `native/Package.swift`, `Contracts.swift`, `native/Tests/KlawosTests/ContractsTests.swift`, `service/klawos_device/model.py`, `service/tests/test_model.py`, and sanitized fixture files listed above. Modify only the project's README to distinguish operator and developer paths.

**Interfaces:** Produce all Contract-index types and `parse_snapshot(document: bytes) -> Snapshot`, `canonical_revision(snapshot: Snapshot) -> str`. Parse UID losslessly; provide `validate_message(payload: bytes) -> WorkerMessage` with a 4 MiB limit. Later native/Python/JS code shares the JSON schema.

- [ ] Write failing contract tests for six-layer fixture retention, exact UID, explicit None versus inherited overrides, unknown numeric keys/fields, 4 MiB size/32-level nesting limits, duplicate JSON keys, and missing/expired revision rejection. Confirm unchanged-value reads have identical revisions despite different capture timestamps. Test example: `assert parse_snapshot(fixture).identity.uid == "6994672159869375106"`.
- [ ] Run `python3.12 -m unittest discover -s service/tests -p test_model.py -v` and `swift test --package-path native --filter ContractsTests`; confirm each new requirement fails for its missing behavior, not an unrelated dependency error.
- [ ] Implement the contracts and canonical representation. Preserve original imported unknown fields alongside the editable typed view. Include native/JS UID-string tests.
- [ ] Resolve exact tested Python 3.12 distribution/build and any necessary pure parser dependency; record source URL, revision, license and SHA256. Use a development interpreter to run tests, but require the final package to bundle its runtime. Do not install the upstream Qt application dependencies.
- [ ] Re-run the focused tests; verify no test reads `~/.freemicro`, real user macros, or live device data. Inspect the reference Micro tree read-only and record hashes of copied UI components before adapting copies.
- [ ] Commit only the contract/setup deliverable once later implementation is authorized. Do not commit raw handover/config backup directories; `.gitignore` excludes them, screenshots pending review, runtime logs and signing secrets. Repository creation/push remains task 13.

**Exit:** Shared schemas, fixtures and provenance exist, with passing fixture tests. No hardware writes.

### Task 2: Headless Vial adaptation and read-only device gate G1

**Files:** Create `HIDTransport.swift`, `WorkerConnection.swift`, `service/klawos_device/{worker,keycodes,macros,features,lighting}.py`, the reused upstream subset and schema, `HIDTransportTests.swift`, `test_protocol.py`, `test_keycodes.py`, `docs/CAPABILITIES.md`.

**Interfaces:** Produce `HIDTransport.exchange(_ request: Data, device: DeviceDescriptor, timeoutMS: Int) throws -> Data`; transport reports are exactly 32 bytes at the Vial boundary. Produce Python `read_snapshot(exchange, descriptor) -> Snapshot`, `read_capabilities(exchange, identity) -> Capabilities`, `decode_keycode(value: int, protocol: int) -> str`, `encode_keycode(value: str, protocol: int) -> int`; `WorkerConnection.perform(_ operation: WorkerOperation) async throws -> WorkerResult` correlates all nested exchanges. Unknown keycodes remain lossless numeric values.

- [ ] Write protocol transcript tests for discovery/UID, definition decoding, six layers/encoder, protocol 5 keycodes, dynamic capacities, 21 settings, macro capacity/extended events, readable lighting, short reports, wrong reply generation, timeout and ambiguous identity. Include two same-VID/PID pads requiring explicit selection.
- [ ] Run `python3.12 -m unittest discover -s service/tests -p 'test_*code*.py' -v`, `python3.12 -m unittest discover -s service/tests -p test_protocol.py -v`, and `swift test --package-path native --filter HIDTransportTests`; observe relevant failures.
- [ ] Adapt pinned upstream models and packet operations, replacing Qt translation/unlock/settings dependencies with explicit non-UI interfaces. Use a restricted supported keycode parser; no Python `eval` on imported expressions. Strip UI imports without weakening upstream conversion/error checks. Implement native generic report transport and worker correlation/deadlines.
- [ ] Re-run tests and compare representative protocol behavior against the pinned upstream tests/transcripts. Verify the worker imports no PyQt and the protocol model does not access the live Micro file.
- [ ] With Pippo present and coding phase authorized, close Vial for exclusive read access; read the real KLAWOS only. Compare a fresh official Vial export with the adapter's `.vil` by decoded fields; capture lighting/capabilities separately. No reset, unlock, key change or firmware operation at this step.
- [ ] Record G1 evidence, device identity/path selection, capacities, absent-feature reasons and readable lighting fields in `docs/CAPABILITIES.md`. If G1 fails, stop dependent device tasks and report the actual failure. Commit the adapter only after review.

**Exit:** Proven read-only device connection; G1 result explicit. A fixture pass alone is insufficient.

### Task 3: Globally reserved helper-input gate G2 and trigger allocation

**Files:** Create `InputRouter.swift`, `TriggerAllocator.swift`, `InputRouterTests.swift`, `TriggerAllocatorTests.swift`, `tests/integration/helper-input.md`.

**Interfaces:** Consume Snapshot/Capabilities from task 2. Produce `TriggerAllocator.allocate(snapshot: Snapshot, helperInputs: [InputID]) throws -> TriggerPlan`; candidates are F13–F24, then modifier-qualified F13–F24, with collision scan across every emission source. Produce `InputRouter.route(_ sample: InputSample, configuration: HelperConfiguration) -> RoutedInput`, and `releaseAll(reason: StopReason)`. `RoutedInput` is pass-through, helper-press/release or ignored-synthetic; the active reservation and verified device generation are mandatory; physical keyboard identity is not available from this event stream.

- [ ] Write failing tests for same reserved chord from another keyboard invoking the same action and unrelated chords passing through, synthetic output being ignored, one action per physical press, hold/release pairing, candidates colliding with gaming/macro/combo/tap-dance/override output, and a changed device generation invalidating outstanding inputs. Assert ordered allocation F13–F24, Shift+F13–F24, then Control+Shift+F13–F24 and balanced modifier handling without swallowing modifiers needed by unrelated input. Test modifier-only presses and mixed ordinary typing explicitly; disable modifier-qualified candidates unless this physical gate passes.
- [ ] Run `swift test --package-path native --filter InputRouterTests` and `--filter TriggerAllocatorTests`; observe failures before implementation.
- [ ] Implement a bounded native input-capture/consumption proof using supported macOS event APIs and the approved global reservations. No layer polling. Do not choose a whole-keyboard seizure path that silently converts gaming into synthetic input. Reserved-chord consumption and synthetic-event exclusion are evidence gates, not assumed API capabilities.
- [ ] Re-run fixture tests. Arrange a temporary, backed-up Work-only spare-key mapping for one helper trigger; keep wheel/layer/gaming settings byte-equivalent. Identify the physical control with Pippo first, save a pre-test export, and restore/read back its original mapping after the proof.
- [ ] Perform G2 physical tests: identical sequence from ordinary keyboard, KLAWOS trigger, rapid repeat, modifiers held, focus change, synthetic output, helper stop/crash/restart, unplug/replug and gaming-layer inputs. Record counts/outcomes, not raw reports or typed text. Require zero duplicates/leaked helper triggers while running and unchanged unrelated ordinary/gaming behavior. The reserved chord from another keyboard must invoke the same action. Confirm that stop/disconnect removes all reservations and that per-Mac shortcut conflicts are surfaced.
- [ ] If reliable global reserved-chord consumption cannot be proven, stop helper integration and revise this design with Pippo; do not spend UI work pretending the runtime requirement is solved. Commit the verified bounded input path and trigger allocator after review.

**Exit:** G2 passes on the Workbook, with a repeatable procedure for the personal Mac. Only allocated chords are consumed globally; no whole-keyboard seizure or firmware modification.

### Task 4: Draft storage, revisions, portable project model and backups

**Files:** Create `ProjectStore.swift`, `service/klawos_device/{validation,diff}.py`, `ProjectStoreTests.swift`, `test_validation.py`, `test_diff.py`, and malformed fixtures.

**Interfaces:** Produce `ProjectStore.load(projectID: UUID) throws -> Draft`, `patch(projectID: UUID, revision: String, edits: [FieldEdit]) throws -> Draft`, `flush(projectID: UUID) throws`, `backup(snapshot: Snapshot, recoveryID: UUID?) throws -> BackupRef`. Python produces `validate_project(document: bytes, capabilities: Capabilities) -> ValidatedProject`, `merge_snapshot(base: Snapshot, actual: Snapshot, desired: Snapshot) -> MergeResult` and `plan_changes(actual: Snapshot, desired: Snapshot) -> ChangePlan`.

- [ ] Write failures for 300 ms autosave flushing at Apply, missing/expired revision, disjoint changes merging, same-field conflict refusing writes, failed atomic save preserving previous bytes, backup pruning retaining 20 plus unresolved-recovery references, and a macro-slot change preserving the other aggregate slots.
- [ ] Run `swift test --package-path native --filter ProjectStoreTests` plus `python3.12 -m unittest discover -s service/tests -p 'test_*validation*.py' -v` and `-p test_diff.py`; verify targeted failures.
- [ ] Implement atomic owner-only JSON storage and the portable project format. Do not add SQLite or iCloud live-file synchronization. Match `.vil` semantics, separate lighting from it, preserve unknown fields, and reject unsupported/unsafe writes before transport access.
- [ ] Re-run tests with injected file-write/rename failures and two editor revisions. Assert no backup contains permissions/credentials and no test touches Application Support in the actual home directory; supply a test storage root.
- [ ] Commit after review.

**Exit:** Draft/backup behavior is verified entirely in scratch storage; no device writes.

### Task 5: Verified Apply coordinator, helper-generation handoff and recovery

**Files:** Create `ApplyCoordinator.swift`, `ApplyCoordinatorTests.swift`, `test_apply_regions.py`, `tests/integration/device-apply.md`.

**Interfaces:** Consume task 2 transport/worker, task 3 TriggerPlan and task 4 storage/diff. Produce `ApplyCoordinator.preview(_ draft: Draft) async throws -> ChangePlan`, `apply(_ plan: ChangePlan) async -> ApplyResult`, `recover(_ journal: RecoveryJournal, choice: RecoveryChoice) async -> ApplyResult`. Consume a `HelperGenerationStore` protocol implemented by the native agent later; use a strict test double now. Its exact methods are `stage(_ configuration: HelperConfiguration) throws -> UUID`, `activate(generationID: UUID) throws`, `current() -> HelperConfiguration?`, and `pauseAffectedInputs(_ inputs: Set<InputID>, reason: String)`. Activation clears only the matching verified transition's pause; failure preserves it.

- [ ] Write failing tests for backup failure causing zero writes; same-field physical drift causing conflict; disjoint device change being retained; disconnect after the second operation causing partial status; ambiguous timeout followed by readback and no blind retry; macro aggregate preservation; lighting backup; host activation failure keeping affected actions paused; recovery refusing a different selected device.
- [ ] Run `swift test --package-path native --filter ApplyCoordinatorTests` and `python3.12 -m unittest discover -s service/tests -p test_apply_regions.py -v`; inspect failure causes.
- [ ] Implement SPEC §8's ordered state machine and durable recovery journal. Hardware writes are sequential, not a database transaction. Preflight/re-read logical regions; recognize that an external Vial instance cannot be perfectly locked by our app. Only matching hardware readback plus helper activation permits verified completion.
- [ ] Re-run fault-injection tests for every interruption boundary, including worker restart and cancellation. Ensure recovery backs up before restoring only reviewed changed regions and is repeatable without duplicate changes.
- [ ] With Pippo, perform a reversible one-key apply/readback/restore on the real device and a controlled disconnect/reconnect test. Preserve the full baseline and wheel settings. Record actual before/after values and outcome; do not unplug during a firmware operation.
- [ ] Commit after review; unresolved device failures block feature-write integration.

**Exit:** Real narrow-save proof plus tested partial-save recovery; no false atomicity claim.

### Task 6: Agent lifecycle, automatic context and bounded action execution

**Files:** Create `AgentMain.swift`, `AgentService.swift`, `ContextRouter.swift`, `ActionExecutor.swift`, `ActionCatalog.swift`, `AgentServiceTests.swift`, `ContextRouterTests.swift`, `ActionExecutorTests.swift`, service plist and `tests/integration/app-actions.md`.

**Interfaces:** Produce `ContextRouter.snapshot() -> ContextSnapshot`, `resolve(bundleID: String?, bindings: ContextBindings) -> ResolvedBinding`, `beginPress(input: InputID, context: ContextSnapshot) -> PressToken`, `endPress(token: PressToken)`. Produce `ActionExecutor.check(_ action: ActionDescriptor) async -> Availability`, `execute(_ action: ActionDescriptor, press: PressToken) async -> ActionResult`; two-second deadline. `AgentService.perform(_ request: AgentRequest) async -> AgentResponse` is the sole public service API. Implement the task-5 `HelperGenerationStore` with durable generation activation.

- [ ] Write failures for Default inheritance versus explicit None, exact bundle-ID matching, KLAWOS editor preview using last external app while runtime still checks actual focus, focus changes during a held key, double dispatch/reentrant synthesized events, timeout, revoked permission, agent crash/restart and a stale generation after Apply. Official Vial launch suspends helper actions; its exit requires successful trigger-map revalidation before resuming.
- [ ] Run `swift test --package-path native --filter ContextRouterTests`, `--filter ActionExecutorTests`, and `--filter AgentServiceTests`; confirm relevant failures.
- [ ] Implement event-driven foreground tracking plus a fresh lookup at press start. Add typed shortcut/app/menu/macOS Shortcut adapters, with availability checks that never execute the action. Move slow app work off input callbacks and release held synthesized state on stop. Register a user-visible current-user service through macOS APIs; no root or Claude/Codex hooks.
- [ ] Reject an unauthorized XPC caller and unsupported operation. Confirm message-size/generation validation from task 1. Provide visible menu-bar Start/Stop/status and diagnostics; closing the editor does not stop the agent.
- [ ] Perform G3 candidate checks in the installed Codex/Claude on both Macs when available. Verify model/panel/new/close/mic/cancel candidates individually; keep absent or unsafe commands unavailable. Never execute a targeted-approval candidate until a real, clearly identified prompt is available for Pippo's physical test.
- [ ] Re-run native tests and record actual bundle IDs and per-Mac action results. Commit after review.

**Exit:** Automatic context behavior proven, and advertised action availability has evidence. A catalogue may contain unavailable entries with reasons; it may not invent readiness.

### Task 7: Complete feature read/write operations and parity matrix

**Files:** Extend the task-2 feature/macros/lighting modules; create `service/tests/{test_features,test_macros,test_lighting,test_security}.py`; update `docs/CAPABILITIES.md` and worker operation allowlist.

**Interfaces:** Produce `feature_model(snapshot: Snapshot, feature: FeatureID) -> FeatureModel`, `validate_feature_edit(model: FeatureModel, edit: FeatureEdit) -> [FieldEdit]`, `encode_macro(events: [MacroEvent], capabilities: Capabilities) -> bytes`, `lighting_diff(old: LightingState, new: LightingState) -> [DeviceOperation]`. All persistent mutations flow through task 5. Security actions expose required physical interaction, separate reset confirmation and scoped backup.

- [ ] Write failing tests covering every SPEC §4 row: keycode ranges, modifier/layer semantics, encoder directions, all slot capacities, macro encoded-byte overflow, tap/hold/delay fields, combo/override masks, QMK min/max and unknown bits, unreadable lighting, lock/unlock/reset boundaries, and absent conditional features. Alt Repeat capacity zero must yield unsupported, not an empty advertised editor.
- [ ] Run `python3.12 -m unittest discover -s service/tests -p 'test_*.py' -v`; verify new behavior fails before it is implemented.
- [ ] Implement supported-feature operations from pinned Vial logic with complete field validation and no silent truncation. Preserve custom keycodes/settings. Keep physical unlock and reset outside ordinary Apply and show the exact affected scope. Add conditional firmware-package validation only if the device actually exposes its Vial bootloader and a legitimate package/recovery method is available; otherwise report its measured unavailable state.
- [ ] Re-run tests. Cross-check keycodes/macros against upstream reference vectors. Update parity matrix with supported/unsupported/not-established status and exact test ownership for each row.
- [ ] Physically verify representative changed values for each supported write family using backup/apply/readback/restore. Cover every entry/field shape in fixtures; do not waste device writes cycling every slot. Check RGB persistence after a replug separately from a model preview.
- [ ] Commit after review; no supported Vial feature is dropped to make the milestone pass.

**Exit:** Every supported family is implemented and parity status is explicit. Firmware/per-layer-color uncertainty remains accurately reported.

### Task 8: Native window, restricted web bridge and complete draft editor

**Files:** Create native host/WebBridge/AgentClient/PermissionGuide files, `WebBridgeTests.swift`, `ui/{index.html,styles.css,app.js,bridge.js,key-editor.js,advanced-editor.js,recovery-view.js}`, and UI tests. Use a simple labelled control-list board until the model arrives.

**Interfaces:** JavaScript `request(operation, payload, {deviceGeneration, draftRevision}) -> Promise<AgentResponse>` and `subscribeState(listener) -> unsubscribe`. `renderControlEditor({snapshot, draft, capabilities, selectedInput, inspectedContext})` calls draft patches only. Swift `WebBridge.handle(_ message: BridgeMessage) async -> BridgeResponse` validates the allowlist, JSON shape and 4 MiB limit before XPC.

- [ ] Write native tests for unauthorized navigation/bridge operations, caller paths/commands, oversize messages, stale replies and XPC loss. Write UI tests for each supported feature editor, draft-only changes, revision conflict, partial-save recovery, no-device drafts, honest capability reasons and wheel subinput separation. Example: `assert.equal(fakeAgent.deviceWrites.length, 0)` after an editor change before Apply.
- [ ] Run `swift test --package-path native --filter WebBridgeTests` and `node --test tests/ui/editor.test.mjs tests/ui/advanced.test.mjs tests/ui/recovery.test.mjs`; confirm test failures indicate the missing flow.
- [ ] Implement a 1280 × 860 native window, 880 × 640 minimum, loading bundled assets only. Adapt copies of the Micro compact editor and viewer patterns; do not modify their originals. Use native file dialogs; no user-supplied filesystem path in a web message. Implement all advanced feature editors and draft/apply statuses, not just the key picker.
- [ ] Implement Apply summary and explicit recovery choices from task 5. Inspection of a Codex/Claude profile changes only the editor view; automatic runtime following remains active. Keep unsupported features visible with a reason.
- [ ] Re-run tests and perform visible native-window checks with sanitized fixture data: click each control and feature, create a draft, inspect diff, conflict, disconnect and recovery states. Record that fixture UI checks are not physical acceptance.
- [ ] Commit after review.

**Exit:** Complete editing/recovery flows work before adding the final geometry.

### Task 9: Screenshot-based KLAWOS geometry and accessible board selection

**Files:** Create the `art/board/` and `ui/models/` assets, adapt `board-viewer.js`, add `tests/ui/board.test.mjs`, `service/tests/test_model_asset.py`, and `tests/ui/accessibility.test.mjs`.

**Interfaces:** `control-map.json` maps stable input IDs `key:r:c` and `encoder:0:ccw/cw` to model metadata; wheel press stays `key:0:3`. `selectInput(inputID)` opens the same editor path as the control list. Model metadata never carries runtime action scripts.

- [ ] Use the four actual-device photos and two website screenshots saved in `reference/hardware/2026-10-14/`; read `docs/HARDWARE-REFERENCE.md`. Reference intake is complete, but this asset task is not executed. Record visible geometry and estimates; actual photos and Pippo's gold-knob/transparent-key instruction take priority over website variants. Confirm control positions against the live Vial definition; do not infer matrix addresses solely from the image.
- [ ] Write failing tests requiring all 16 matrix inputs and two encoder directions to be accounted for, no duplicate interactive IDs, consistent list/model selection, wheel-direction controls, fallback if GLB/WebGL fails, and no unsupported per-LED capability implied by rendering.
- [ ] Run `node --test tests/ui/board.test.mjs tests/ui/accessibility.test.mjs` and `python3.12 -m unittest discover -s service/tests -p test_model_asset.py -v`; confirm failures before assets/viewer integration.
- [ ] Rebuild the hardware as an editable Blender scene and self-contained GLB; retain source reference and estimates. Reuse vendored Three.js 0.180.0 and its notices. Add Top/3D view, rotation, zoom, selection highlight, hover labels and editable app icons; avoid physical-lighting claims from UI colors.
- [ ] Re-run tests and visibly check every control, fallback, keyboard-only path, 200% text zoom, focus return, reduced motion and minimum window size. Compare front/angled renders with the provided screenshot and ask Pippo to review reconstruction fidelity.
- [ ] Record G4 review/evidence and commit intended hardware assets only. Do not mark screenshot-based side/depth estimates as measured CAD.

**Exit:** Reviewed KLAWOS model with verified selectable controls and accessible fallback. The image dependency is supplied; model construction and Pippo's visual acceptance still require the later implementation phase.

### Task 10: Integrated helper/action editor and privacy-scoped macro recording

**Files:** Extend action editor/agent integration; create `MacroRecorder.swift`, `MacroRecorderTests.swift`, `tests/ui/actions.test.mjs`, and `tests/integration/work-profiles.md`.

**Interfaces:** `setContextBinding(inputID, contextID, actionDescriptor, revision)` patches a draft. `startMacroRecording(sessionID: UUID) -> RecordingStatus`, `stopMacroRecording(sessionID: UUID) -> [MacroEvent]`; recording is explicit and separate from the device-scoped helper route. `MacroRecorder` does not persist recorded event text outside the chosen draft macro.

- [ ] Write failures for profile inheritance/None, assigning helper actions creating draft trigger changes, hardware/helper generation mismatch, duplicate click saves, a still-held key on app switch, imported unavailable actions, and 64-bit UID round trip through the JS bridge.
- [ ] Write recording tests for visible start/stop, permission denial, Escape/Stop ending capture, editor close/agent error ending capture, no content in logs/diagnostics, and recorded encoded capacity validation before Apply. A stopped recording cannot continue receiving events.
- [ ] Run `node --test tests/ui/actions.test.mjs`, `swift test --package-path native --filter MacroRecorderTests`, and context/action tests; inspect failures.
- [ ] Implement the action picker with availability reasons and “Helper required” labels. Wire trigger allocation and staged generation activation to Apply. Offer macro recording only as an explicit foreground recording session with a privacy description and stop control; it must not expand ordinary helper input scope silently.
- [ ] Re-run tests and physical G3 acceptance: Default, Codex and Claude actions, rapid app switches, editor-frontmost preview versus actual execution, helper stopped, missing app/Shortcut, revoked permission and restart. Do not treat catalogue presence as proof an action worked.
- [ ] Commit after review.

**Exit:** The full app-aware flow and explicit recorder are integrated without hidden input logging.

### Task 11: Portable import/export, external drift and user-facing recovery

**Files:** Add `service/klawos_device/project_format.py`, `test_project_format.py`, native `ImportExport.swift`/`ImportExportTests.swift`, extend recovery UI and acceptance procedures.

**Interfaces:** `import_project(document: bytes, target: DeviceIdentity, capabilities: Capabilities) -> ImportPreview`; `export_project(snapshot: Snapshot, metadata: AppMetadata, profiles: PortableProfiles) -> bytes`; `export_vil(snapshot: Snapshot) -> bytes`. Native file dialogs produce bytes/selected destinations; imported scripts/paths never become executable ActionDescriptor values.

- [ ] Write failures for wrong UID/dimensions, malformed counts/masks/nesting, numeric unknown-key round trips, future safe extensions, `.vil` lighting omission being clearly explained, full native lighting backup, foreign-Mac paths/Shortcut IDs, imported executable content, macro size overflow, same-field Vial drift, and unknown dangerous fields preventing writes.
- [ ] Run `python3.12 -m unittest discover -s service/tests -p test_project_format.py -v`, `swift test --package-path native --filter ImportExportTests`, and recovery UI tests; observe relevant failures.
- [ ] Implement UTF-8 JSON `.klawos` format 1, native dialogs and preview. Resolve local app/Shortcut bindings per machine without exporting paths/permission state. Retain uneditable imported data without writing it to firmware. Import never runs an action or applies automatically.
- [ ] Re-run tests and a native round trip: export on Workbook, import on personal Mac as a draft, inspect missing local action bindings, verify six layers/helper metadata/lighting, then apply only after review. Also reproduce a controlled Vial edit between read and Apply; retain unrelated edits and show a same-field conflict.
- [ ] Commit after review.

**Exit:** Explicit portability and truthful drift/recovery behavior; private-repo access is not treated as configuration sync.

### Task 12: Self-contained packages, permissions, update and rollback on both Macs

**Files:** Create packaging files and build/package/verify scripts, `native/Tests/KlawosTests/LifecycleTests.swift`, `tests/integration/install-update-rollback.md`, `docs/RELEASE.md`; update build manifest.

**Interfaces:** Future `scripts/build-app.sh --arch <arm64|x86_64> --version <version>` produces `dist/KLAWOS Studio.app`; `scripts/verify-package.sh <app-path>` returns a structured check report. App/agent IDs are `com.pippo.klawos.studio` and `com.pippo.klawos.agent`. `AgentClient.start()/stop()/status()` reflects actual current-user service state, not registration intent.

- [ ] Write failing lifecycle/package checks for missing Python/UI/model assets, stale or wrong-architecture runtime, editor quit leaving agent intentionally active, Stop releasing held state, login-registration denial, permission revocation, worker crash, partial migration and downgrade unreadable-format rollback.
- [ ] Run `swift test --package-path native --filter LifecycleTests` and the future package-check harness on an intentionally incomplete fixture bundle; confirm failure explains actual missing pieces.
- [ ] Implement architecture-matched self-contained bundling and stable identities. Build from pinned manifests. Use macOS per-user service registration and clear permission guidance; never copy another Mac's permissions or credentials. Measure both Macs before claiming compatibility. Keep updater manual: install versioned package from private release, no stored GitHub token or updater service.
- [ ] Check Developer ID/team/notarization availability. If unavailable, produce an honestly labelled local test build; do not present it as a verified distributed release. Sign/verify every nested executable/runtime when signing is available and validate transferred-package Gatekeeper behavior without bypasses.
- [ ] On both Macs, run from Finder/Dock with development-tool access removed from the test environment. Verify G1/G2/G3, login helper, editor close, stop/restart, actual permissions, export/import, fresh install and upgrade. Keep the previous app and data-format backup, induce a migration failure in scratch data, and prove rollback reads the matched backup.
- [ ] Record exact build, architecture, OS, signing result, action availability and physical outcomes; any unperformed machine check stays unverified. Commit after review.

**Exit:** G5 is verified on both machines or the remaining delivery block is explicitly recorded.

### Task 13: Redacted diagnostics, final review, private repository and release

**Files:** Create `Diagnostics.swift`, `DiagnosticsTests.swift`, `scripts/check.sh`, `docs/{ACCEPTANCE,REVIEW}.md`; complete provenance/release manifest and README.

**Interfaces:** `Diagnostics.export(state: DiagnosticState, destination: URL) throws -> URL` exports version/capability/permission/operation metadata only. Future `scripts/check.sh` runs Python unittest, Swift tests, JavaScript contracts and package validation; it does not grant itself live-device writes.

- [ ] Write seeded-secret failures for every diagnostic source: macro/user text, paths, serial, raw HID/input sequences, Shortcut arguments, scripts, clipboard/chat content, environment/credentials and malformed upstream error text. Example: `XCTAssertFalse(exported.contains(seededSecret))` for every seeded field.
- [ ] Run `swift test --package-path native --filter DiagnosticsTests`; observe failures. Implement bounded metadata diagnostics and stable error-code/plain-reason formatting, never a raw state/config dump. Re-run redaction tests.
- [ ] Run `scripts/check.sh` and `scripts/verify-package.sh 'dist/KLAWOS Studio.app'`. Expected: zero failing focused/full suites and an explicit per-check package result; physical and cross-machine results remain separate evidence. Do not relax an assertion to fix a failure.
- [ ] Walk every SPEC §4/§12 acceptance item against CAPABILITIES/ACCEPTANCE and the final native UI. Include both-Mac wheel direction, helper-off gaming, physical Work actions, saves/recovery, all supported feature editors, asset review, accessibility and diagnostics. No supported feature or required machine check can disappear from the completion report.
- [ ] Obtain final code/design review under the human's chosen execution method; record confirmed fixes and remaining limitations. Claude owns final review under the user's standing domain split. Do not message another chat or create review agents without the required authorization.
- [ ] After later coding/repository authorization, verify the authenticated account and `klawos-studio` name, create the private repository, inspect its visibility via API, and inspect staged history/files for excluded user material before the first push. Existing documentation-only local files do not imply a repository was already created.
- [ ] Freeze version/tag, generate artifact hashes, package corresponding source/license material, and publish only the verified intended private release. Confirm private visibility after publication. Record install/update/rollback instructions and unresolved gate failures; any such failure blocks a “complete on both Macs” claim.

**Exit:** Versioned private release with required acceptance evidence and redacted diagnostics. Publishing and coding are not authorized by the current planning-only request.

## Task order and dependencies

1 → 2 → 3 establishes shared contracts and both feasibility gates. Tasks 4–5 then establish safe persistence and Apply. Task 6 implements the agent/context/actions using the proven input route. Task 7 completes the device feature matrix. Task 8 provides the full editor. Task 9 has the hardware reference and still requires model construction and review; it can overlap later backend work only if the user subsequently authorizes that execution method. Tasks 10–11 integrate context/recording and portability. Tasks 12–13 require both-Mac acceptance, delivery and final review.

No execution starts until Pippo explicitly asks to code. G1/G2 failure stops the affected branch of work and requires a revised reviewed design. The visual reference has been supplied. Final asset production and visual acceptance remain future work after implementation authorization. Exact initial key/game presets are user configuration: preserve the current mappings and provide editors rather than inventing them.

## Document self-review and execution handoff

Self-review checklist for this document:

- [x] Every specification section maps to a task; full device-supported Vial parity remains in scope.
- [x] Shared contract names/interfaces are defined before consumers; UID and direction semantics are explicit.
- [x] Five Review Focus conditions have test owners and individual assertions in those tasks.
- [x] Runtime gates, external screenshots, physical tests and both-Mac checks are labelled as future work, not completed proof.
- [x] No product code, dependency installation, helper registration, repository creation or device write is part of the planning-only request.
- [x] Safe-save failure, unknown imports, lighting backup, security controls, macro recording privacy and conditional firmware paths are covered.
- [x] Execution method and final review remain later human decisions; do not select delegation implicitly.

The spec and plan are ready for Pippo's review together. The hardware reference input is now supplied; do not begin model or code work until Pippo authorizes implementation. Keep implementation on hold; do not turn design approval into a coding instruction. When Pippo later authorizes execution, re-read both documents, inspect current workspace/device/app state, use the authorized execution method, and preserve all current configuration and concurrent work.

## Approved commissioning update — 14 October 2026

Pippo approved both temporary use of the top-left Work key with restoration and explicit mappings in affected transparent gaming-layer cells to preserve their verified output. Include those cells in the Apply preview and backup; do not infer a resolved output for arbitrary stacked layers. Unknown resolution remains blocked until verified. Prior byte-identical gaming-layer constraints are superseded only for these reviewed preservation edits. Wheel and unrelated mappings stay unchanged. Initial unmodified macOS candidates are F13–F20; wider candidates remain gated.
