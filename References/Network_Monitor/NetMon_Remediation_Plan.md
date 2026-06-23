# Network Monitor Full Remediation Plan

Generated: 2026-06-23

## Fresh Session Instructions

This document is intended to be usable by a fresh implementation session with no prior conversation context. Before editing code, read these files in this order:

1. `References\Network_Monitor\NetMon_Fresh_Session_Handoff.md`
2. `References\Network_Monitor\Network_Monitor_Contract.md`
3. `References\Network_Monitor\Network_Monitor_Remediation.md`
4. `References\Network_Monitor\NetMon_Architecture_Contract.md`
5. `References\Network_Monitor\NetMon_Verification_Checklist.md`
6. `References\Network_Monitor\Network_Monitor_Mockup.png`
7. Current implementation under `Scripts\Network_Monitor`

Do not begin by patching individual symptoms. The remediation is an architecture pass. The first implementation goal is to make the structure safe and predictable:

- safe event handler capture
- shared app-window/title-bar helpers
- one column presentation API
- runspace-safe ping completion
- interaction-based verification

The code must remain compact, modular, and practical to hand-transcribe into an airgapped machine terminal. Do not introduce external dependencies, package downloads, WPF, HTML, web assets, or generated code that is difficult to type by hand.

## Companion Documents

This plan is the phased remediation strategy. It is supported by:

- `NetMon_Fresh_Session_Handoff.md`
  - Exact no-context implementation briefing, required reading, and hard constraints.
- `NetMon_Architecture_Contract.md`
  - Required module boundaries, helper APIs, event-capture rules, and presentation contracts.
- `NetMon_Verification_Checklist.md`
  - Required parser, construction, ping-state, presentation, and manual interaction checks.

If this plan conflicts with `Network_Monitor_Contract.md`, the original contract wins unless the conflict is explicitly about correcting a later implementation defect.

## Purpose

This plan is for a full remediation pass on the Network Monitor app under:

`Scripts\Network_Monitor`

The goal is to stop patching visible symptoms and correct the design failures that made small bugs recur across rendering, settings, event handling, and monitoring. The app should remain a compact native PowerShell WinForms application with no external dependencies and no internet/package requirements.

The reference console script must remain untouched:

`References\Network_Monitor\Network_Monitor.ps1`

## Problem Statement

The current implementation has improved, but it still carries structural problems:

- UI behavior is too dependent on script-scope globals.
- Event handlers are registered in ways that can capture or resolve the wrong variables later.
- Settings and main window behavior are not built from one shared window framework.
- Grid rendering originally had separate code paths for values, colors, selection colors, and custom painting.
- Verification focused on parser/build checks and missed real interactions such as dragging the settings title bar.
- Patches were made incrementally under pressure, which fixed individual symptoms without first restoring clean boundaries.

This is not a PowerShell limitation by itself. The failure is that the app code did not establish strict enough local patterns for PowerShell WinForms.

## Current Known State

The current `Scripts\Network_Monitor` app has had several symptom fixes applied, but it is not trusted as a clean base. Known repaired or partially repaired areas include:

- The original full-surface `Graphics.Clear()` grid painting bug has been addressed.
- Ping completion was moved away from unsafe `BackgroundWorker` callback behavior.
- Some column presentation logic has been centralized.
- Some unsafe title-bar event capture has been patched.
- Settings styling and Health tab layout have been partially repaired.

However, those fixes were applied incrementally. A fresh implementation session should verify and refactor the architecture rather than assuming the current code is clean.

Treat these as still requiring audit:

- every `.Add_*` event handler
- every helper-created callback
- every use of `$script:` state
- grid selection and formatting behavior
- settings window ownership/topmost/drag behavior
- config edit transaction behavior
- ping-cycle completion and skipped-cycle behavior

## Root Cause

### 1. Unsafe Event Handler Capture

PowerShell scriptblocks registered as .NET event handlers do not behave like ordinary local closures unless they are explicitly closed with `.GetNewClosure()` or the target object is stored somewhere stable.

Examples of high-risk patterns:

```powershell
function Some-Helper {
    param($Form)
    $control.Add_MouseDown({
        [Native]::SendMessage($Form.Handle, ...)
    })
}
```

That scriptblock may later resolve `$Form` from an unexpected scope. In the app, that produced a concrete bug: dragging the settings title bar moved the main monitor window.

Required pattern:

```powershell
function Some-Helper {
    param($Form)
    $targetForm = $Form
    $control.Add_MouseDown({
        [Native]::SendMessage($targetForm.Handle, ...)
    }.GetNewClosure())
}
```

Or better, store the target form in a small typed/tag object attached to the control.

### 2. Global State Bleed

The app uses many `$script:` variables. Some of these are legitimate process-wide state, but too many UI handlers implicitly rely on them.

Legitimate script state:

- Current config.
- Target states.
- Timers.
- Main form reference.
- Settings form reference.

Problematic script state:

- Temporary form/control variables.
- Event-handler targets.
- Current row/column assumptions.
- UI construction intermediates.

The remediation must reduce script state to durable app state only.

### 3. Divergent Presentation Paths

Status display was split across multiple places:

- Cell values.
- Cell formatting.
- Custom painting.
- Selected-row formatting.
- History/status drawing.

That allowed inconsistent behavior such as selected-row RTT and Loss text turning white while other rows were red.

The correct model is one presentation contract per column:

- Text.
- Color.
- Font.
- Paint mode.
- Optional custom draw behavior.

All rendering paths must consume the same column presentation object.

### 4. UI Framework Drift

The main form and settings form were implemented as separate one-off windows. This caused:

- Different title bar behavior.
- Different styling.
- Different close/drag semantics.
- Settings tabs that visually drifted from the main app.

Both windows need to use the same local helper functions for:

- Borderless form frame.
- Title bar.
- Icon buttons.
- Drag behavior.
- Topmost/owner behavior.
- Border painting.

### 5. Verification Was Not Interaction-Based

Parser checks and form construction checks are necessary but not sufficient. The app needs manual and automated interaction checks for:

- Dragging the main window.
- Dragging the settings window.
- Clicking title bar buttons.
- Opening/focusing settings.
- Pinging reachable and unreachable targets.
- Selected-row rendering.
- Committing settings by Enter and focus leave.

## Remediation Principles

- Fix design boundaries before visual polish.
- Prefer fewer generic helpers over many one-off event blocks.
- Every event handler created inside a helper must explicitly capture required local values.
- Keep ordinary grid text rendering native; custom paint only where truly needed.
- All displayed status values must go through one presentation API.
- Main and settings windows must use shared app-window helpers.
- No hidden magic through temporary `$script:` variables.
- Keep code compact enough for manual transcription to an airgapped machine.
- Keep modules narrow and hand-debuggable.
- Do not add external dependencies.

## Target Architecture

### Module Responsibilities

#### `Network_Monitor.ps1`

Responsibilities:

- App root detection.
- STA/PowerShell 7 relaunch.
- Assembly loading.
- Module loading.
- Top-level fatal startup handling.
- Start app.

Should not contain:

- UI construction logic.
- Ping logic.
- Config validation logic.

#### `Scripts\UiHelpers.ps1`

Responsibilities:

- Shared colors/fonts/theme.
- Basic geometry helpers.
- Borderless form subclass.
- Shared app window creation helpers.
- Shared title bar helpers.
- Shared icon button helpers.
- Safe event registration helpers.

Required new helpers:

- `Add-NMSafeEvent`
- `New-NMAppWindow`
- `New-NMTitleBar`
- `Enable-NMWindowDrag`
- `New-NMIconButton`
- `Set-NMIconButtonActive`

Event handlers inside this file must use `.GetNewClosure()` whenever they reference a local variable, parameter, or callback.

#### `Scripts\Presentation.ps1`

Required new module.

Responsibilities:

- Column presentation definitions.
- Text/color/font/paint-mode selection.
- Shared history color mapping.
- Shared health color mapping.
- Column custom-paint routing.

Key API:

```powershell
Get-NMColumnPresentation -State $state -Target $target -ColumnId $id
```

The returned object should include:

- `Text`
- `ForeColor`
- `Font`
- `PaintKind`
- Optional `Align`

This module should be the only place where RTT, Loss, TTL, Bytes, Status, Node, and future status columns decide their displayed text and color.

Load order requirement:

`Network_Monitor.ps1` must dot-source `Presentation.ps1` after theme/state helpers are available and before `MainForm.ps1`.

#### `Scripts\MainForm.ps1`

Responsibilities:

- Build main app window using shared window helpers.
- Build and maintain grid.
- Bind grid to target state.
- Handle title bar commands:
  - settings
  - reset/refresh
  - pin
  - minimize
  - maximize/restore
  - close
- Start monitoring from `Shown`.

Should not contain:

- Per-column status/color rules.
- Low-level icon drawing.
- Settings form layout.
- Ping implementation.

#### `Scripts\SettingsForm.ps1`

Responsibilities:

- Build settings window using shared window helpers.
- Build settings tabs.
- Commit settings through transactional config APIs.
- Show inline validation feedback.

Should not contain:

- Custom title bar behavior implemented differently from the main form.
- Direct config mutation before validation, except through a safe transaction helper.
- One-off event handlers that depend on uncaptured local variables.

#### `Scripts\Config.ps1`

Responsibilities:

- Default config generation.
- Strict config load validation.
- Invalid config backup.
- Atomic config writes.
- Transactional config edit helper.

Key API:

```powershell
Invoke-NMConfigEdit -Edit { param($config) ... }
```

The helper must:

- Clone current config.
- Apply proposed edit.
- Validate clone.
- Save clone atomically.
- Replace live config only after save success.

#### `Scripts\PingEngine.ps1`

Responsibilities:

- Start concurrent `SendPingAsync()` pings.
- Avoid UI thread blocking.
- Avoid PowerShell runspace callback bugs.
- Skip overlapping cycles.
- Return completed cycle results on the UI runspace.

Important constraint:

Do not use `BackgroundWorker` callbacks that invoke PowerShell scriptblocks from worker threads without a runspace. Prefer UI-timer polling or another runspace-safe design.

#### `Scripts\MonitorState.ps1`

Responsibilities:

- Target state initialization/reset.
- Applying ping results to state.
- Health calculations.
- Status text.
- RTT/loss text helpers if retained.

Should remain independent from WinForms controls.

#### `Scripts\Validation.ps1`

Responsibilities:

- Supported column definitions.
- Config validation.
- Address validation.
- Color validation.
- Numeric threshold validation.

## Phase 1 - Stabilize Event Handling

Objective:

Remove unsafe local variable capture from all WinForms event handlers.

Tasks:

1. Audit all `.Add_*` calls.
2. Categorize event handlers:
   - Does not reference local variables: safe.
   - References `$script:` durable state only: acceptable but review.
   - References helper parameters/local variables: must use `.GetNewClosure()` or store values in control `Tag`.
3. Patch helper-created handlers first:
   - `New-NMIconButton`
   - `New-NMButton`
   - `Enable-NMTitleDrag`
   - `Enable-NMSettingsTitleDrag`
   - numeric commit helpers
   - tab draw helpers
4. Patch form-specific handlers that use local `$form`, `$tabs`, `$target`, `$column`, or callbacks.
5. Remove any handler that depends on a variable that may later be reused for another form/control.

Acceptance checks:

- Dragging monitor title bar moves monitor only.
- Dragging settings title bar moves settings only.
- Settings close button closes settings only.
- Main close button exits app.
- Settings cog focuses existing settings window.

Implementation notes:

- Do not leave callback scriptblocks inside helper functions unclosed when they reference local variables.
- Use `.GetNewClosure()` on the scriptblock at registration time.
- Alternatively, put the target object into `Control.Tag` and read it from `$sender.Tag`.
- Avoid relying on a parameter name such as `$Form`, `$Control`, `$OnClick`, `$Target`, or `$Column` inside a delayed event scriptblock unless it is explicitly captured.

## Phase 2 - Create Shared Window Framework

Objective:

Stop implementing main and settings window behavior separately.

Tasks:

1. Add `New-NMAppWindow` helper.
2. Parameters should include:
   - title
   - size
   - minimum size
   - show in taskbar
   - topmost
   - resizable
3. Add `New-NMTitleBar` helper.
4. Parameters should include:
   - parent form
   - title text
   - buttons
   - drag enabled
   - maximize enabled
5. Main form and settings form must both use these helpers.
6. Remove duplicated title-bar construction from `MainForm.ps1` and `SettingsForm.ps1`.

Acceptance checks:

- Both windows share same dark frame and title bar style.
- Both windows drag independently.
- Close/minimize/maximize behavior is appropriate per window.
- Settings remains owned by and above main monitor.

## Phase 3 - Centralize Column Presentation

Objective:

Make all displayed grid text and colors flow through one reusable API.

Tasks:

1. Move presentation functions to `Scripts\Presentation.ps1`.
2. Implement:

```powershell
New-NMColumnPresentation
Get-NMColumnPresentation
Get-NMReplyValueText
Get-NMReplyValueColor
Get-NMHistorySampleColor
```

3. `MainForm.ps1` must call `Get-NMColumnPresentation` for:
   - row creation
   - row updates
   - cell formatting
   - custom painting
   - invalidating custom cells
4. Remove all direct RTT/Loss/TTL/Bytes/Status color logic from `MainForm.ps1`.
5. Add one rule for selection:
   - `SelectionForeColor` must equal presentation `ForeColor`.
6. Avoid full-row selection unless a future design explicitly needs it.

Acceptance checks:

- Status, RTT, Loss, TTL, Bytes are colored consistently for every row.
- Selected/current cell does not change health colors.
- Adding a new status column requires a single presentation case.

## Phase 4 - Reduce Grid Custom Painting

Objective:

Keep custom painting only where needed and make it presentation-driven.

Tasks:

1. Native text columns:
   - Node
   - Address
   - RTT
   - Loss
   - TTL
   - Bytes
2. Custom columns:
   - Status, for dot plus text.
   - History, for tick bars.
3. Custom paint must never call `Graphics.Clear()`.
4. Custom paint must fill only `CellBounds`.
5. Custom paint must use presentation object, not recalculate state.
6. History color must use one helper:

```powershell
Get-NMHistorySampleColor
```

Acceptance checks:

- No disappearing headers/text.
- No selected-row color mismatch.
- History shows yellow for unfilled, green for success, red for failure.

## Phase 5 - Isolate Runtime State

Objective:

Separate durable app state from temporary UI variables.

Tasks:

1. Define a small app state object or documented `$script:` state map.
2. Keep these as durable script state:
   - `NMConfig`
   - `NMTargetStates`
   - `NMForm`
   - `NMSettingsForm`
   - `NMGrid`
   - timers
3. Avoid script-state for:
   - local target variables
   - local form variables
   - event target forms
   - current tab/control variables
4. When a handler needs local data, capture it with `.GetNewClosure()` or store it in `Tag`.

Acceptance checks:

- Opening settings repeatedly does not redirect events to old/disposed forms.
- Closing/reopening settings does not leave stale handlers acting on old controls.
- Pin/settings active states remain correct.

## Phase 6 - Harden Ping Engine

Objective:

Make ping cycles reliable and runspace-safe.

Tasks:

1. Keep concurrent `SendPingAsync()` pings.
2. Do not call UI/state PowerShell functions from worker threads without a runspace.
3. Use a WinForms timer polling model or explicit runspace-safe marshaling.
4. Ensure every attempted ping produces exactly one sample:
   - success
   - timeout
   - failure
5. Ensure skipped overlapping ticks produce no sample.
6. Dispose `Ping` objects after each cycle.
7. Add debug logging for ping-cycle exceptions only when debug is enabled.

Acceptance checks:

- Unreachable default targets show timeout, 100% rolling loss, red history, and `DOWN` after threshold.
- Reachable target shows RTT, 0.0% loss, green history.
- Mixed reachable/unreachable targets render independently.
- UI remains responsive during timeout cycles.

## Phase 7 - Rework Settings Form With Shared Controls

Objective:

Make settings consistent, readable, and compact.

Tasks:

1. Use shared app-window/title-bar helpers.
2. Use shared dark tab styling.
3. Create reusable row helpers:
   - label + textbox
   - label + numeric
   - checkbox
   - button
4. Health tab must use explicit labeled rows.
5. Target tab must be visually consistent with main grid.
6. Commit behavior:
   - text/numeric fields commit on Enter or focus leave.
   - checkboxes commit on click.
   - invalid edits restore previous valid value.
7. All settings changes must go through `Invoke-NMConfigEdit`.

Acceptance checks:

- Health tab labels are visible and aligned.
- Settings window matches main app style.
- Settings drag moves only settings.
- Invalid input never remains active in memory.

## Phase 8 - Build Interaction Test Harness

Objective:

Catch the kinds of bugs parser checks cannot catch.

Tasks:

1. Add a developer-only test script under:

`Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`

2. Suggested tests:
   - Parse all scripts.
   - Load modules.
   - Build main form.
   - Build settings form.
   - Verify main/settings handles are distinct.
   - Verify title-drag handlers target the correct form handle where practical.
   - Simulate three failed ping cycles and assert `DOWN`, red, 100% loss.
   - Simulate success and assert green, RTT text, 0.0% loss.
   - Verify presentation for all supported columns.
3. Keep test scripts local and optional; do not add runtime dependencies.

Acceptance checks:

- One command can run the nonvisual checks before manual launch:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1
```

- Test output clearly reports pass/fail.

The test script must not require internet, external modules, or administrator rights.

## Phase 9 - Manual Acceptance Pass

Run these manual checks after the refactor.

### Main Window

- Launch direct PS1.
- Launch CMD/VBS shim.
- Window appears bottom-left on first run.
- Window appears in taskbar.
- Drag title bar moves main window.
- Minimize works.
- Maximize/restore works.
- Close exits completely.
- Pin toggles topmost and persists.
- Reset clears samples and starts fresh.

### Monitoring

- Unreachable targets show:
  - RTT `timeout`.
  - Loss `100.0%`.
  - Red history ticks.
  - `DOWN` after 3 consecutive failed samples.
- No selected row/cell changes health colors.
- Skipped cycles do not create history ticks.

### Settings

- Cog opens settings.
- Cog focuses existing settings window if already open.
- Settings window stays above monitor.
- Dragging settings title bar moves settings only.
- Close button closes settings only.
- Tabs are readable.
- Health tab is usable.
- Numeric edits commit on Enter/focus leave.
- Invalid edits are rejected and restored.
- Reset defaults confirms first.

## Implementation Order

1. Stop and checkpoint current app process.
2. Add or update test harness for current bug reproduction.
3. Stabilize event handler capture.
4. Extract shared app-window/title-bar helpers.
5. Move column presentation into `Presentation.ps1`.
6. Refactor main grid to use presentation object everywhere.
7. Refactor settings form to use shared window/control helpers.
8. Harden ping engine tests.
9. Run nonvisual tests.
10. Run manual acceptance pass.
11. Only then do visual polish.

Do not mark the remediation complete until the verification checklist in `NetMon_Verification_Checklist.md` has been run and the manual interaction checks have been performed against the visible running app.

## Definition Of Done

- No event handler created inside a helper depends on uncaptured local variables.
- Main and settings windows use shared frame/title helpers.
- Settings drag moves settings only.
- Main drag moves main only.
- All status-like column text/color comes from one presentation API.
- Selected/current grid cells do not override health colors.
- Ping timeouts reliably produce failed samples.
- Settings controls commit through transactional config edits.
- Health tab is readable and usable.
- Parser/build/presentation/ping-state tests pass.
- Manual interaction checklist passes.

## Non-Goals

- No WPF rewrite.
- No web/HTML frontend.
- No external icon/font packages.
- No new dependency downloads.
- No tray icon.
- No launcher integration beyond existing standalone shims.
- No average/min/max RTT columns unless separately requested later.

## Summary

The remediation should be treated as a small architecture repair, not a bug-fix sweep. The main design failure was allowing one-off PowerShell event handlers, global state, and split rendering rules to accumulate. The corrected app needs strict helper patterns:

- capture event targets explicitly
- reuse window/title helpers
- centralize column presentation
- keep ping completion on the UI runspace
- verify real interactions, not just syntax

That is the path to making future changes predictable and keeping the code compact enough to hand-enter on the target system.
