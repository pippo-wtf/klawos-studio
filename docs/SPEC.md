# KLAWOS Studio — product and technical specification

Version: 1.2 · 14 October 2026 · Owner: Pippo

Status: complete planning document for review. Pippo approved the separate-app approach and requested this specification and the build plan. Implementation is explicitly on hold. “KLAWOS Studio” is the working product name.

## 1. Outcome and confirmed decisions

Give Pippo a separate, double-clickable Mac app for configuring his KLAWOS through a selectable 3D model, based on the existing Micro Studio experience. Cover every Vial configuration feature that the connected KLAWOS supports. Add Mac actions whose Work assignments automatically follow the active application. Deliver the app on the Workbook and personal MacBook, with source and versioned releases in a private repository.

Confirmed:

- Separate app; preserve the existing Micro Studio, FreeMicro installation, live Micro config, and dirty source tree.
- Full device-supported Vial coverage, rather than a shortcuts-only editor.
- Work actions automatically follow Codex, Claude, or the Default Work context.
- Wheel press retains Work → Dota → Wardogs → Work. Work rotation retains scroll up/down.
- App delivery targets both Macs. Windows app development is outside this scope; ordinary keyboard-resident mappings remain portable according to their target OS and keyboard layout.
- Project home is `/Users/philip.scholl/_WORK/KLAWOS`. Private-repository creation belongs to the later implementation phase.
- Hardware references received: four actual-device photos and two website screenshots. Pippo confirms a gold knob and transparent keys. Use his photos as the appearance authority; exact dimensions remain unmeasured. See `HARDWARE-REFERENCE.md` and the verified local reference manifest.
- Do not start coding yet. Completing or approving these documents does not itself authorize implementation.

No telemetry, cloud account, subscription, mandatory network connection, automatic configuration synchronization, or firmware modification is required. No changes to protected Claude/Codex configuration or the MainBrain architecture are part of this project.

## 2. Evidence baseline and its limits

The installed official Vial 0.7.5 app recognizes `KLAWOS KLAWOS` on the Workbook. A fresh export is semantically identical to the latest handover `.vil`. The original and intermediate exports remain intact. These observations establish discovery and configuration readback, not physical-key or application acceptance.

| Baseline | Observed value |
|---|---|
| USB identity | VID `0x5241`, PID `0x1234` |
| Raw HID interface | Usage page `0xFF60`, usage `0x61` |
| Vial definition UID | Decimal string `6994672159869375106` |
| Protocols | Vial 5, VIA 9 |
| Matrix / layers | 4 × 4, six layers |
| Physical inputs represented | Fifteen ordinary switches, wheel press, one encoder with two directions |
| Wheel press matrix address | Row 0, column 3; `TO(1)`, `TO(2)`, `TO(0)` on layers 0–2 |
| Work encoder export | `KC_WH_U`, `KC_WH_D` in Vial's encoded direction order |
| Macro slots | 100; total byte capacity must be queried |
| Tap dance / combos / key overrides | 32 entries each |
| QMK settings | 21 exported IDs |
| Alt Repeat Key | Zero exported entries; not advertised as supported without a capability read |
| Lighting UI | Effect, color, brightness, speed, Save; includes Direct Control and Solid Color |

Limits:

- The UID identifies a keyboard definition, not necessarily an individual physical unit. VID/PID alone also do not uniquely select one pad. Select one actual HID path and validate its UID/capabilities. If two matching pads exist, ask the user to choose; never write to both.
- A reconnect can change the HID path. Use a measured unique serial if available; otherwise require explicit device selection for recovery when more than one unit or an identity ambiguity is present. Do not equate a shared definition UID with proof of the same physical unit.
- `.vil` does not carry lighting in the inspected Vial 0.7.5 serializer. A `.vil` backup alone is incomplete for this app's lighting features.
- Vial writes settings sequentially. A multi-setting save cannot be represented as an atomic device transaction.
- Configurable per-layer indicator colors are not exposed in the observed Lighting UI. Dota red and Wardogs brown remain desired colors, not promised firmware behavior. Direct Control is an effect label, not evidence of a per-layer color API.
- A reliable native route for capturing and consuming KLAWOS helper triggers has not been proven. Section 10 makes that an explicit early gate.
- The current Vial protocol code imports Qt-based helpers. It must be adapted, not described as a ready-made headless library.
- The personal Mac's installed software, permissions, OS, and architecture must be measured during acceptance. Do not infer parity from the Workbook.

## 3. User experience

### Main window

Use Micro Studio's light, quiet visual treatment and compact editor as the precedent. Header: device/connection status, selected layer, inspected Work context, helper status, pending-change count, Apply, Import/Export, and Advanced tools. Footer: product version and diagnostics.

The center shows the KLAWOS model with top/angled presets, drag rotation, bounded zoom, selection highlight, hover labels, and optional assignment icons. Selecting a control opens the compact editor without losing the board. Wheel press and rotation are separate editable inputs. A keyboard-accessible control list provides the identical path and becomes the default fallback if 3D cannot load.

Layers 0–2 display Work, Dota, Wardogs. Layers 3–5 remain editable and can be named. Names and icons are app metadata. Changing a name never changes a hardware layer index. The editor's selected layer is not labelled as the currently active hardware layer unless an authoritative device signal proves it; ordinary Vial layer selection only selects which map is being edited.

### Editing and applying

1. Read the selected device and its capabilities. Save a baseline project backup before the first write.
2. Select a control, layer, and editing context. Hardware bindings apply at the selected device layer. Codex/Claude/Default context overrides apply only to helper-managed Work inputs.
3. Save each editor change into a local draft and show “Saved to draft”. Do not silently write to the device.
4. Apply opens a summary of changed hardware values, helper assignments, and lighting. Device-independent icon/name changes need no hardware write.
5. Re-read the device, check conflicts, back up, apply, and verify. Only a matching readback permits “Applied and verified”.
6. Cancel keeps the draft. Discard draft explicitly returns to its baseline; it does not change the keyboard.

A persistent strip distinguishes “Draft”, “Applying”, “Applied and verified”, “Another app changed the keyboard”, “Some changes could not be verified”, and “Keyboard disconnected”. Recovery preserves both the draft and pre-write backup.

### Work context

Default preview follows the most recent external foreground app. While KLAWOS Studio itself is active, show that the preview is following the last external app; do not imply that Claude is still the current OS foreground app. An inspect selector permits reviewing Default Work, Codex, or Claude without changing runtime selection.

At physical key-down, resolve the real foreground bundle identifier again. Exact configured bundle-ID match selects Codex or Claude; otherwise select Default Work. Capture that context for the complete press/release sequence so switching apps while holding a key does not leave modifiers stuck. An action that activates an app does not retroactively change the context that selected it.

## 4. Feature coverage

“Full Vial coverage” means an in-app editor/test path for every feature the device exposes, with its capacities and validation rules. A link opening Vial is not a substitute for a supported configuration editor.

| Feature | Required behavior |
|---|---|
| Keymap | Complete supported keycode catalogue, modifiers/nested keycodes, layer actions, transparent/disabled keys, consumer/media/mouse and custom firmware keycodes. Display and preserve unknown numeric keycodes; allow validated raw 16-bit input. Do not evaluate arbitrary expressions. |
| Encoder | Both directions on every supported layer; wheel press uses its matrix address. Retain source direction semantics and verify physical orientation rather than infer it from the array index. |
| Layers / layout | All six layers and supported layout options. Capability-driven counts; no hardcoded truncation. Preserve untouched hidden matrix positions. |
| Macros | All 100 slots; text, tap, press, release, and delay events supported by the protocol. Show used/available encoded byte capacity. Editing/reordering/deleting is draft-only. Macro recording is explicit, visibly active, user-stoppable, and scoped to that recording session; no background recording or diagnostics containing text. |
| Lighting | Device-reported effects, HSV/color, brightness, speed and explicit persistence. Supported value ranges come from the device. Project backups include readable lighting state; mark unavailable fields as unreadable rather than manufacturing a value. |
| Tap dance | All 32 entries and their supported single/double tap/hold fields and timing. Explain each behavior in plain language. |
| Combos | All 32 entries, their input keys and output action; enforce firmware limits and preserve inactive entries. |
| Key overrides | All 32 entries, trigger/replacement, layer mask, positive/negative/suppressed modifiers, and options. |
| QMK settings | All supported IDs, names/types/ranges from the pinned settings schema. Preserve unrecognized settings and expose read-only raw values when editing is unsafe. Reset is scoped and previewed with a backup. |
| Matrix tester | User-started live switch highlighting with a visible stop control; release polling on exit. No permanent polling to guess runtime layers. |
| Import/export | Vial-compatible `.vil`; native `.klawos` project; preview and device-definition validation before Apply. Import does not execute host actions or overwrite the device immediately. |
| Keyboard layout | Display/input-layout selection and layout-aware shortcuts. An app display-layout choice does not change macOS's system keyboard layout. |
| Security | Device-reported lock status, official physical unlock sequence, lock, and reset. A physical unlock is performed by Pippo. Never unlock silently on launch or weaken the firmware protection. Reset is a separate confirmed operation with its own backup. |
| Device information | UID, firmware protocol, selected device, capacities, readable features, and reasons for absent features. |
| Conditional Vial features | Alt Repeat Key, custom layout controls, extra protocol features and Vial bootloader firmware updates appear only when advertised. A supported feature gets a proper editor and validation. Firmware update additionally requires a compatible maker-supplied package and a documented recovery method; this plan never invents KLAWOS firmware. |

The capability matrix records each feature as supported, unsupported, or not established, with evidence. Version one is not complete if a feature supported by this KLAWOS is simply deferred. Preserve app names/icons/preview colors independently of keyboard lighting. Per-layer colors must not be offered as working until a supported mechanism is proven.

## 5. Mac actions and helper behavior

The helper supports per-input Default Work bindings plus exact Codex and Claude overrides. Missing override inherits Default Work. Explicit None suppresses the helper action; it is different from a missing override. Hardware actions remain available as an alternative to helper actions.

Action types are: ordinary shortcut, app launch, named macOS Shortcut, validated application-menu command, an app-specific verified command, and None. Built-in candidates include app switching, new conversation, terminal/sidebar/browser toggles, model chooser, cancel, close conversation, and microphone toggle. Each gets an independent availability check and a physical acceptance record on each Mac. The current Micro config supplies migration candidates, not evidence that they work now.

No automatic import of arbitrary shell scripts or AppleScript from the Micro config. A named macOS Shortcut can contain user-authored logic outside this app; list it and explain that it is local to the Mac. Action adapters must not install hooks, alter Claude/Codex settings, or inspect chat text for status. Approval is offered only if a supported adapter can identify the current waiting prompt/session and target that prompt safely; otherwise it remains unavailable with a reason. A blind Enter/Yes binding is never substituted for targeted approval.

Helper actions use stable globally reserved trigger chords for Work, allocated only when the user assigns a helper action. The allocator scans all layers, encoder mappings, macros, combos, tap dance and overrides for collisions. It never reuses an emitted gaming sequence as a helper trigger. Default candidate bank is F13–F24 followed by modifier-qualified F13–F24 sequences; the early gate must validate the selected bank and global reserved-chord consumption before allocation is enabled. Do not rewrite hardware bindings on app-focus events or maintain a guessed active-layer counter from wheel presses.

Decision approved by Pippo on 14 October 2026: reserve shortcuts globally. While the helper is active and the verified KLAWOS configuration is connected, an assigned reserved chord from any keyboard invokes the current app binding. Only allocated chords are reserved; show their global scope in the action editor and helper status. Pass unrelated input through. Stop, disconnect, permission loss, or configuration drift disables reservations and releases held helper output. Conflicts with other apps or macOS shortcuts cannot be exhaustively detected: provide a per-Mac test and reallocation workflow. Physical device attribution is not claimed.

Use ordered candidates F13–F24, Shift+F13–F24, then Control+Shift+F13–F24, skipping collisions. Consumption tests cover the modifier events too. Detect official Vial (`today.vial`) launch/termination through native application lifecycle notifications: suspend helper-managed actions while another known configurator is using the device, then re-read/reconcile the trigger map before re-enabling them. Unknown external tools can still change firmware; any observed drift suspends affected actions. Do not claim perfect cross-application exclusivity.

While the helper runs, one physical key-down produces one action unless repeat behavior is explicitly selected. Release/hold lifecycle is paired, the active reservation is checked, synthesized output is excluded from input handling, and actions are bounded to two seconds with a visible error when they cannot complete. Avoid arbitrary sleeps on the input callback. Dispatch app work away from the hardware reader.

When the helper is off or permission is missing, the UI says “Mac actions need the helper”. A helper trigger remains the hardware keycode/chord assigned to it; do not promise it is universally inert when the helper is absent. Plain Vial bindings, the wheel cycle, Work scrolling, Dota, and Wardogs must still behave as keyboard-resident mappings. Document that distinction in the action editor and export summary.

The helper has a menu-bar status item, Start/Stop, Open KLAWOS Studio, and diagnostics. Closing the editor leaves it active. Start at login is a user-visible per-Mac setting through macOS's supported service-registration API. Stopping it releases device/event resources and held synthesized modifiers. A crash/restart must not replay an old action queue.

## 6. Architecture and boundaries

Use four cooperating units, without a new public web service:

| Unit | Responsibility |
|---|---|
| Native editor host | Cocoa window, bundled WKWebView assets, restricted message bridge, file dialogs, app/helper lifecycle and permission guidance. |
| Native agent | Foreground app context, device-scoped input, action execution, single owner of HID transport, serialized device operations, project storage, XPC interface. |
| Python device worker | Adapted pinned Vial protocol/keycode/macro/settings logic, capability decoding, serialization, diff planning, and readback comparison. No Qt UI or direct access to the live Micro config. |
| Bundled board/editor UI | Reused local Three.js viewer and compact editing patterns, KLAWOS-specific model/control mapping, feature editors, draft state and recovery views. |

The editor communicates with the agent over a current-user XPC service. The agent launches the bundled Python worker with anonymous pipes, request IDs and deadlines; the worker requests raw report exchanges through the agent. IOKit handles generic HID transport; Vial protocol packet semantics remain in the adapted upstream Python code. Transport adaptation is validated early before UI work depends on it.

The agent owns one serialized raw-HID operation stream per selected device. Runtime action dispatch has a separate bounded queue. A long capability read, macro write or disconnected device must not freeze ordinary Work input. The worker has no network access in the product design and no reason to read credentials. Include only required pure-Python parser support from pinned/audited sources; no Qt GUI, package manager, or development interpreter at runtime.

The WKWebView reads only bundled UI/model assets. Its bridge accepts a fixed operation allowlist and schema-validated payloads, with a maximum 4 MiB message and no caller-supplied command name, shell command, or filesystem path. External URLs open in the user's browser only through an explicit user link. Validate the XPC client's current-user identity and app signing identity. No HTTP listener, remote control, or public endpoint is needed.

### Interfaces

These are design contracts, not implemented APIs:

- `DeviceDescriptor`: HID path token, VID/PID, transport, serial when available. Do not expose raw paths in diagnostics.
- `DeviceIdentity`: descriptor plus definition UID as a decimal string, protocol versions, definition hash. String storage prevents JavaScript precision loss for this 64-bit UID.
- `Capabilities`: matrix dimensions, layer/encoder/slot counts, macro byte capacity, supported keycode/features/settings, lighting ranges, unlock description and optional bootloader support.
- `Snapshot`: identity, complete `.vil` values, readable lighting values, unreadable-field list, native app metadata, canonical revision and capture time.
- `Draft`: baseline Snapshot, proposed values, dirty field paths, source-revision token, helper configuration generation.
- `ChangePlan`: ordered persistent operations, verified expected old/new values, changed aggregate regions, backup reference, required unlock/reset decisions, staged helper generation.
- `ApplyResult`: verified fields, unresolved fields, final revision, backup reference, helper-generation activation status, and one terminal state: verified / conflict / disconnected / partial / cancelled.
- `ContextSnapshot`: actual frontmost bundle ID, last external bundle ID, resolved profile and permission/helper state.
- `ActionResult`: action ID, completion/availability state and redacted reason; no text, clipboard, prompt or script payload.

Root agent request operations: status, select/read device, patch draft, discard draft, preview/apply/recover, import/export, feature capability/read, start/stop matrix test or macro recording, security operations, helper settings, recheck action and diagnostics. Worker operations: decode/read, validate, serialize, plan diff, verify; transport exchanges are nested correlated messages. Correlation IDs and operation generations reject delayed replies from a previous device/worker.

Device revision is SHA256 over canonical UTF-8 JSON of definition identity, protocol/capabilities, hardware values and readable lighting. Canonical JSON sorts object keys and preserves array order and numeric values. Exclude capture timestamps, opaque HID paths, helper status, foreground app and other volatile runtime data. Draft revision additionally covers portable metadata, proposed values and helper generation. A repeated read of unchanged values must not create a false conflict merely because its timestamp changed.

## 7. Data, portability and safe persistence

Store app data under `~/Library/Application Support/KLAWOS Studio/`, with owner-only permissions for project/action data. Store no user secrets in the repository. Draft autosave is atomic and debounced by 300 ms; Apply flushes it first. Retain the last 20 pre-write project backups per device definition; never delete a backup referenced by an unresolved recovery record. A user-exported backup is never included in automatic pruning.

Native project format `.klawos` is UTF-8 JSON with `format_version: 1`, app version, device identity, capability summary, `.vil` body, separate lighting state, app metadata, portable action IDs/parameters, and unknown preserved extension fields. It contains no permission grants, authentication, absolute machine paths, or executable script bodies. Local machine bindings to app/Shortcut identities live outside the portable export. Import shows missing apps/Shortcuts and asks the user to resolve them; it never runs an imported action.

`.vil` import/export preserves known and unknown fields and numeric keycodes. Writing unknown feature data is refused unless its schema and capability are understood; the file is still retained and exportable. No malformed field is silently normalized into a valid-looking value. Reject a different device definition, invalid counts, invalid masks/values, oversized macros, excessive nesting, and files above 4 MiB before any device write. UID comparison uses strings/integer-safe parsing across all languages.

Maximum imported JSON nesting is 32 levels. Parse `.vil` raw bytes in the integer-safe native/Python boundary before exposing a model to JavaScript; export its UID as the exact numeric token Vial expects. Native `.klawos` and UI/IPC models represent that UID as a decimal string. Reject duplicate JSON object keys rather than silently choose one value.

Two editor windows use optimistic draft revisions. Independent field changes merge; a same-field clash refuses the later change and asks for reload/resolve. A missing or expired revision never falls back to the newest draft. Physical-device optimistic checks occur separately at Apply time. Vial does not provide an inter-app transaction lock: detect known busy access, preflight and re-read around each logical operation, but do not claim another configurator cannot race a write. Ask the user to close it when contention is detected.

## 8. Apply, verification and recovery

1. Validate the draft and target; flush autosave. Allocate helper triggers only after its feasibility gate has passed.
2. Read a fresh snapshot. Three-way compare baseline, fresh device and desired draft. Merge disjoint changes, block same-field changes, preserve unrelated values.
3. Save a complete pre-write project backup, including readable lighting and the current helper generation, then a recovery journal. Backup failure prevents all writes.
4. Stage the next helper configuration but keep it inactive. Pause dispatch only for helper-managed inputs involved in the transition; never consume gaming input because an Apply is running.
5. Apply one logical operation at a time. Aggregate regions such as macro memory are treated as a whole: a narrow macro change must preserve every other slot in that region. Physical unlock is prompted only when required for the operation.
6. Read back each logical region and compare. After an ambiguous timeout, read the device to determine what happened; never blindly replay a write. On uncertain identity, disconnect, drift, or verification mismatch, stop and journal the observed result.
7. Activate the staged helper generation only after its corresponding hardware triggers and host config have been verified. If host activation fails, keep affected Mac actions paused and mark the save partial. Never advertise a matching runtime generation that was not activated.
8. Read a final complete snapshot, mark only verified fields clean, and retain unresolved draft fields. “Applied and verified” requires full intended hardware verification and helper activation.

Recovery is user-driven: reconnect the same selected device, read it, compare journal/pre-write backup/desired draft, then offer Keep current, Complete the intended changes, or Restore the backed-up changed regions. Show the diff before writing. Never automatically restore an entire snapshot over unrelated new changes. If a region is unreadable, explain that its restoration cannot be verified. Recovering again is idempotent and produces its own backup.

Lighting preview on the 3D model is always labelled as a preview. A physical live-lighting preview, if offered, requires an explicit toggle, captures readable prior state, and restores it on Cancel; it is separate from persistent Save. Do not add a live preview if restoring the required state cannot be supported.

## 9. Geometry, accessibility and copy

Build a KLAWOS GLB plus an editable Blender source and front/angled reference renders from the supplied photos/screenshots after implementation is authorized. Use stable matrix/encoder input IDs in mesh metadata; never derive control identity from mesh order or screen coordinates. All 16 switch inputs, including wheel press, and both encoder directions must be accounted for. UI claims must reflect the physical-reference limits: proportions can be reconstructed; hidden depth/materials require estimates unless measured/model source is supplied.

Personal-device appearance: fifteen transparent/translucent square keycaps, gold rounded-top diamond-knurled knob, silver metallic-looking case and black inner plate. Use the actual photographs for materials and the website shots only as secondary geometry references. The photographed blue/purple glow is not a fixed-color or per-layer capability requirement.

Retain Top view, 3D view, rotation and zoom. Icons and labels are editor metadata. The board cannot imply that an LED is individually configurable unless the capability supports it. Use a neutral model until approved material/color references are available; no invented status lighting.

Keyboard-only users must be able to choose every control and edit every supported feature. Focus is contained in the editor, Escape/Done returns it to the originating control, error text is announced, and selection/status never rely only on color. Honor reduced motion. The UI remains functional at 200% text zoom and at the minimum window size of 880 × 640. Default window is 1280 × 860. Copy is plain English and actionable; no raw traceback or protocol jargon in the normal editing flow.

## 10. Implementation gates and stop conditions

| Gate | Required evidence | Failure action |
|---|---|---|
| G1 Device adapter | Read identity/capabilities/full configuration through the adapted backend on KLAWOS; same semantic `.vil` as fresh Vial; independent lighting reads; clean disconnect behavior. | Stop device integration; report unsupported transport/protocol behavior and revise the adapter. |
| G2 Helper input | Globally reserved chord consumption, exactly-once action, synthetic-output exclusion, no trigger leakage while running, unrelated keys and gaming unchanged, cleanup after restart/disconnect. The identical reserved chord from another keyboard intentionally invokes the same action. | Stop richer-action integration if consumption or cleanup cannot be proven. No whole-keyboard seizure, layer polling, or firmware changes. |
| G3 Application actions | Verify foreground bundle IDs and candidate action adapters in installed Codex/Claude on each Mac. Press-level tests confirm advertised actions. | Mark individual actions unavailable with the measured reason; do not claim all Micro actions migrated. |
| G4 Assets | Screenshot received; control topology checked against device definition; model selection verified and visual reconstruction reviewed by Pippo. | Core backend work may continue after coding authorization; final model and visual acceptance remain gated. |
| G5 Delivery | Clean install, permissions, launch/restart/update/rollback, physical operation and diagnostics verified on both Macs; packaged runtime is self-contained. | Do not mark release complete or publish it as a verified two-Mac build. |

These gates are work to perform later, not passing results. Exact hardware/helper feasibility remains an honest limitation of the current planning evidence.

## 11. Build, versions and repository

Technology baseline: macOS 14 or later; Swift/Cocoa, WebKit, IOKit and XPC; bundled Python 3.12 runtime; adapted Vial GUI source tag `v0.7.5`; locally vendored Three.js `0.180.0`; plain JavaScript/CSS. Use native platform capabilities and Python standard library where possible. Any required parser/runtime component is pinned by exact source revision and hash in the build manifest; resolve and verify those pins during the first build task, without silently introducing an alternative stack.

Repository working name: `klawos-studio`, private, under the authenticated account Pippo selects/uses at implementation time. Check owner/name/visibility before pushing. Initial product version `0.1.0`; specification/project format has independent version 1. Released versions/tags are immutable; changes require a new version. Release manifest includes source revision, upstream revisions/licenses, exact Python version, architecture, minimum macOS, artifact hashes and signing result.

Package `KLAWOS Studio.app` with its native agent, service-registration plist, device worker, runtime, UI and models. The installed app needs neither FreeMicro, Vial, Blender, Homebrew, pipx, git nor a development checkout. Build architecture-matched packages after measuring each Mac; produce a universal artifact only if all embedded components are actually universal. No Rosetta dependency in the new target build. Blender is a development asset tool only.

Use stable app/agent bundle identifiers `com.pippo.klawos.studio` and `com.pippo.klawos.agent`. Inspect Developer ID/team/notarization availability before signing distribution builds; do not promise those services from memory. A local ad-hoc build is labelled as such and is not a verified transferable release. Never disable Gatekeeper, MDM, or Input Monitoring to make a test pass.

Initial update channel is explicit installation from private releases: export/backup, stop agent cleanly, install the new version, migrate local data atomically, restart, verify. No in-app GitHub token storage or automatic updater in version one. Preserve the prior app and format backup for rollback; if downgrade cannot read migrated data, restore the matched backup rather than reinterpret it.

Preserve Vial `GPL-2.0-or-later` notices and record reused licenses/source provenance in the repository and release package. Do not commit the existing raw handover transcripts, live keymaps, machine-specific logs, installer images or personal config backups; use deliberately sanitized fixtures. Screenshots/model references enter source control only after confirming they contain just intended hardware/design material.

## 12. Diagnostics, acceptance and completion

One action exports a redacted diagnostic file containing versions, selected device's non-sensitive identity/capabilities, permission availability, gate/operation outcomes, error codes, helper generation and changed-field counts. It contains no raw HID reports, key sequences, macro text, shortcut arguments, clipboard, chat content, scripts, environment, credentials, usernames, home paths or device serial. Redaction tests seed secrets in every candidate source. Logs are bounded metadata, not input history.

Release acceptance requires:

- Supported-feature matrix complete and all supported editors usable in-app; absent features have truthful reasons.
- Import/export preserves the source layout, six layers, custom/unknown values and separate lighting metadata.
- Narrow changes preserve unrelated fields; concurrent edits, partial macro writes, host activation failure, cable removal and reconnect have explicit tested recovery.
- Automatic foreground following is correct for Default Work, Codex and Claude, including held keys, rapid focus changes and the editor being frontmost.
- Every advertised Mac action is physically checked on both machines; unavailable actions retain their reason.
- Wheel cycle and Work direction physically confirmed; Dota/Wardogs standard mappings work with the helper stopped. Game-specific mapping/target layout is validated when Pippo assigns it; no invented gaming preset ships.
- Screenshot-based model reviewed, all control selection paths checked, keyboard fallback and reduced motion checked.
- Packaged app verified from Finder/Dock on both Macs without development tools or source checkout; update/rollback and permission revocation covered.
- Diagnostic redaction, XPC/bridge caller validation, import limits and revision rejection verified.

Do not turn a static check, simulator or mock transport into a physical/device or two-Mac claim. Keep a dated acceptance matrix with build/version/machine, input, observed outcome and evidence. Planning completion means this specification and its build plan have passed a document review; product completion requires the above evidence.

## 13. Requirement-to-plan map and evidence sources

| Specification area | Build-plan tasks |
|---|---|
| Baseline, runtime, privacy and provenance | 1, 2, 13 |
| Vial adapter and capability parity | 2, 3, 7, 8 |
| Draft/apply/recovery and portability | 4, 5, 11 |
| Automatic context/helper/action behavior | 3, 6, 10 |
| Full editor and 3D/accessibility | 8, 9, 10 |
| Both-Mac packaging/release/acceptance | 12, 13 |

Primary local evidence: `handover/START-HERE.md`, `handover/CONVERSATION.md`, `configs/KLAWOS-workbook-readback-2026-10-14.vil`, `docs/DISCOVERY.md`, and `reference/vial-gui-v0.7.5.tar.gz` (SHA256 `bd7f84eb18a6fc5fd8eb0db2aec1804098f0e9773e8bcb0d6f533e6143c1a07b`). Reuse reference: `/Users/philip.scholl/Tools/padgui/README.md`, `docs/REVIEW-2026-09-05.md`, `macos/MicroStudio.swift`, and `padgui/web/board-viewer.js`.

Upstream: [Vial manual](https://get.vial.today/manual/), [Vial source at v0.7.5](https://github.com/vial-kb/vial-gui/tree/v0.7.5). Source inspection found the Qt coupling, sequential writes, `.vil` lighting omission, conditional bootloader UI and protocol field shapes. No reference archive or product code was executed during planning.

## Reference intake — specification revision 1.1

All six supplied images were inspected and copied with verified hashes to `reference/hardware/2026-10-14/`. The visual-reference receipt is complete; model construction and gate G4 review remain future work. The original planning documents are preserved in `docs/history/planning-before-hardware-reference-2026-10-14/`. No implementation authorization changed.
