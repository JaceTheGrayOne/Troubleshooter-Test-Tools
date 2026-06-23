# Network Monitor WPF Rewrite Phased Implementation Plan

Generated: 2026-06-23

## Purpose

This document is the execution prompt for a fresh autonomous implementation session. Use it to rewrite the current PowerShell WinForms Network Monitor as a PowerShell-hosted WPF application in phases.

The implementation session should complete the entire rewrite without manual phase approval. It must still enforce its own phase gates: do not advance from one phase to the next until the previous phase has met the verification criteria listed here, or until a blocker is documented with enough detail for the user to resolve it.

Some checks require the target machine or target network. Those checks may be marked `DEFERRED_TARGET` only when the implementation has verified everything possible locally and has documented the exact target-side check that remains.

## Global Instructions

Before coding, read these documents in this folder:

1. `Network_Monitor_WPF_Rewrite_Phased_Implementation_Plan.md`
2. `00_README_WPF_REWRITE_HANDOFF.md`
3. `12_RESOLVED_WPF_DECISIONS.md`
4. `01_EXISTING_APP_FUNCTIONAL_SPEC.md`
5. `02_EXISTING_UI_VISUAL_SPEC.md`
6. `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`
7. `04_WPF_TARGET_ARCHITECTURE.md`
8. `05_IMPLEMENTATION_PLAN.md`
9. `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`
10. `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`
11. `09_WPF_IMPLEMENTATION_PATTERNS.md`
12. `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`
13. `11_SOURCE_AUDIT_AND_PRIOR_CONVERSATION_ANALYSIS.md`

Use `08_WPF_DECISION_POINTS_UNDECIDED.md` only as the raw historical decision log. The authoritative implementation decisions are in `12_RESOLVED_WPF_DECISIONS.md`.

Authoritative current source:

- `Scripts\Network_Monitor`
- `Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`
- `References\Network_Monitor\Network_Monitor_WPF_Rewrite_References\Network_Monitor_Winform_UI.png`

Target implementation root:

- `Scripts\Network_Monitor_WPF`

Do not overwrite or delete `Scripts\Network_Monitor`. Keep the WinForms app intact as the fallback and comparison baseline.

## Phase Gate Rules

At the end of every phase, produce a short phase result note in the implementation session output or in a local implementation run log. Include:

- Phase number and name.
- Files changed.
- Verification commands run.
- Results of those commands.
- Any deferred target-only checks.
- Gate decision: `PASS`, `FAIL`, or `BLOCKED`.

The session may continue automatically when the gate is `PASS`.

The session must not advance when:

- A parser/module/load test fails.
- A WPF window or XAML file cannot be constructed under STA.
- A behavior test for completed code fails.
- A check is skipped without a concrete reason.
- A source-backed requirement is knowingly missing.

When a gate fails, fix the phase until it passes. Mark a phase `BLOCKED` only if progress depends on external information or target-machine state that cannot be discovered locally.

## Baseline Commands

Run these early and keep using equivalents as the rewrite develops.

Current WinForms baseline:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1
```

Local WPF availability probe:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.Window]::new() | Out-Null; 'WPF OK in pwsh'"
```

WPF rewrite test harness, once created:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor_WPF\Tests\Invoke-NetMonWpfChecks.ps1
```

The WPF test harness should build windows and controls without entering the blocking application loop.

## Phase 0 - Orientation And Baseline

Goal:

Establish that the planning pack, source baseline, and local WPF host are usable before writing WPF code.

Required context:

- `00_README_WPF_REWRITE_HANDOFF.md`
- `11_SOURCE_AUDIT_AND_PRIOR_CONVERSATION_ANALYSIS.md`
- `12_RESOLVED_WPF_DECISIONS.md`
- Current source under `Scripts\Network_Monitor`

Actions:

1. Read the required documents listed in Global Instructions.
2. Confirm that `12_RESOLVED_WPF_DECISIONS.md` is treated as authoritative.
3. Run the current WinForms test harness.
4. Run the local WPF availability probe under `pwsh.exe`.
5. Inspect existing worktree changes before editing. Do not revert user changes.
6. Confirm the target folder `Scripts\Network_Monitor_WPF` does not require overwriting the WinForms implementation.

Gate criteria:

- Current WinForms harness passes, or any failure is proven unrelated to the rewrite and documented.
- WPF probe succeeds under `pwsh.exe`, or fallback requirements for `powershell.exe` are documented and implemented in Phase 1.
- Required reference files and screenshot exist.
- No edits have been made to `Scripts\Network_Monitor` except intentionally read-only inspection.

## Phase 1 - WPF Skeleton, Launchers, And Runtime Host

Goal:

Create the standalone WPF app skeleton and prove it can load under the chosen PowerShell host without depending on ToolLauncher.

Required context:

- `00_README_WPF_REWRITE_HANDOFF.md`
- `04_WPF_TARGET_ARCHITECTURE.md`
- `05_IMPLEMENTATION_PLAN.md`, Phase 1
- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`, launcher and entry-point sections
- `09_WPF_IMPLEMENTATION_PATTERNS.md`, Assembly Loading and XAML Loading
- Current `Scripts\Network_Monitor\Network_Monitor.ps1`
- Current `Scripts\Network_Monitor\Run_Network_Monitor.cmd`
- Current `Scripts\Network_Monitor\Run_Network_Monitor.vbs`

Actions:

1. Create the target layout under `Scripts\Network_Monitor_WPF`.
2. Add `Network_Monitor_WPF.ps1`.
3. Add `Run_Network_Monitor_WPF.cmd`.
4. Add `Run_Network_Monitor_WPF.vbs`.
5. Add `Views\MainWindow.xaml` and `Views\SettingsWindow.xaml`.
6. Add placeholder module files from the planned architecture.
7. Implement app-root detection, STA enforcement, WPF assembly loading, module load order, startup error logging, and fatal startup error display.
8. Implement launcher preference for `pwsh.exe` with WPF probe and fallback to `powershell.exe`.
9. Create `Tests\Invoke-NetMonWpfChecks.ps1` with initial parser, module load, assembly load, and basic XAML construction checks.

Gate criteria:

- All new `.ps1` files parse.
- WPF assemblies load in the selected host.
- Main and settings XAML load under STA.
- A minimal WPF window can be constructed by the test harness without starting `Application.Run()`.
- Direct PS1 launch path is present and syntactically valid.
- CMD and VBS launchers point to the WPF app and do not reference the WinForms folder.
- Startup error handling can be forced and produces visible/logged diagnostics.

## Phase 2 - Nonvisual Core Port

Goal:

Port the current nonvisual behavior before building the full UI.

Required context:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`
- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`
- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`
- Current modules:
  - `Scripts\Network_Monitor\Scripts\Logging.ps1`
  - `Scripts\Network_Monitor\Scripts\Validation.ps1`
  - `Scripts\Network_Monitor\Scripts\Config.ps1`
  - `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
  - `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
  - `Scripts\Network_Monitor\Scripts\Presentation.ps1`

Actions:

1. Port logging behavior, including debug-off quiet behavior and startup error log exception.
2. Port strict config validation, default config creation, invalid backup behavior, and atomic save behavior.
3. Port monitor state rules, including generation handling, reset semantics, rolling history, latest RTT, TTL, bytes, failure counts, and loss calculation.
4. Port ping engine behavior around `SendPingAsync`, one ping per enabled target per cycle, concurrency, timeout as failed sample, skipped busy cycles, and `Ping` disposal.
5. Port presentation rules to WPF brush/text output without duplicating health logic in XAML triggers.
6. Expand `Invoke-NetMonWpfChecks.ps1` for config, validation, monitor state, presentation, and ping-engine checks.

Gate criteria:

- WPF test harness passes parser/module/config/validation/monitor-state/presentation checks.
- Ping-engine tests pass using deterministic local or simulated inputs where possible.
- No routine logs are written when debug is off, except startup/fatal error cases.
- Invalid config is backed up and replaced according to the current contract.
- Default config matches the current WinForms defaults.
- WPF presentation output matches current health/status/RTT/loss/history rules.

## Phase 3 - Theme, XAML Layout, And Window Chrome

Goal:

Build the WPF visual shell for main and settings windows before wiring full behavior.

Required context:

- `02_EXISTING_UI_VISUAL_SPEC.md`
- `04_WPF_TARGET_ARCHITECTURE.md`
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, construction and visual checks
- `09_WPF_IMPLEMENTATION_PATTERNS.md`, Resource Names, Status Template, History Template, Title Bar Buttons, Window Chrome
- Screenshot: `Network_Monitor_Winform_UI.png`
- Current `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`
- Current `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- Current `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`

Actions:

1. Implement WPF theme resources using verified current color/font intent.
2. Implement custom main title bar with settings, reset, pin, minimize, maximize/restore, and close buttons.
3. Implement settings title bar with close button only.
4. Use `WindowChrome` first for resize/drag behavior; add manual/native fallback only if needed.
5. Build the main grid area as a WPF `DataGrid`.
6. Add status and history templates.
7. Build the fixed-size dark settings shell with tabs: Targets, Columns, Timing, Health, General.
8. Keep icon-only title buttons with tooltips.

Gate criteria:

- Main and settings windows construct under STA.
- Required named controls from `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md` exist.
- Theme resources used by XAML resolve.
- Main window has custom title bar, DataGrid, status template, and history template.
- Settings window is fixed-size, non-modal-capable, dark, tabbed, and has a close button only.
- No external fonts, images, icon libraries, NuGet packages, or web assets are required.

## Phase 4 - Main Grid Binding And Column Behavior

Goal:

Implement the WPF main dashboard data model, row rendering, and column layout persistence.

Required context:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`, main grid and presentation sections
- `02_EXISTING_UI_VISUAL_SPEC.md`, grid visual spec
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`, row/grid rebuild and column rules
- `04_WPF_TARGET_ARCHITECTURE.md`, `WpfBindings.ps1`
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, row model and column checks
- `09_WPF_IMPLEMENTATION_PATTERNS.md`, View Model Fallback Ladder and DataGrid Column Creation
- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`, Main Grid and Settings rows

Actions:

1. Create row objects from enabled targets in config order.
2. Bind rows through an observable collection.
3. Use PSCustomObject-first row models with explicit refresh/replacement as needed.
4. Use direct WPF brush bindings for presentation values.
5. Derive node foreground from each target's configured `Color`.
6. Generate/apply DataGrid columns from config order, visibility, width, and min-width definitions.
7. Disable sorting.
8. Preserve selection health colors.
9. Implement column resize/reorder persistence and settings-driven visibility/order/width changes.

Gate criteria:

- Default row collection contains SMS, MPS, MPG in order.
- Disabled targets are hidden.
- Default visible columns are Node, Address, Status, RTT, Loss, History.
- TTL and Bytes exist in config and can be shown, but are hidden by default.
- Column resize, reorder, visibility, min width, and last-visible-column guard are covered by tests or scripted/manual checks.
- Selection/current cell styles do not override bound health foreground colors.
- Target address/color changes can update presentation immediately and reset monitor state/history.

## Phase 5 - Monitoring Loop And Runtime Interaction

Goal:

Wire the main WPF UI to real monitoring behavior.

Required context:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`, monitoring behavior
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`, generation/reset semantics
- `04_WPF_TARGET_ARCHITECTURE.md`, dispatcher and ping-cycle architecture
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, ping and manual monitoring checks
- `09_WPF_IMPLEMENTATION_PATTERNS.md`, DispatcherTimer and Async Ping Pattern
- Current `PingEngine.ps1`, `MonitorState.ps1`, and `MainForm.ps1`

Actions:

1. Use `DispatcherTimer` for refresh ticks.
2. Use a completion polling timer or equivalent dispatcher-safe mechanism for async ping completion.
3. Ensure only one cycle runs at a time and busy ticks are skipped without queued cycles.
4. Start monitoring on window show when `AutoStart` is true.
5. Implement reset button behavior: clear samples/history and start a fresh cycle.
6. Implement generation discard for stale ping completions after reset/config changes.
7. Keep UI updates on the dispatcher thread.

Gate criteria:

- Automated tests prove state updates for success, timeout/failure, down threshold, loss, history, reset, and generation discard.
- Busy-cycle skip behavior is covered.
- Ping objects are disposed.
- Loopback or controlled local ping test passes where available.
- Target-network-specific unreachable/reachable behavior is either manually checked locally or marked `DEFERRED_TARGET` with exact target-machine steps.
- UI remains constructible and responsive in local smoke testing.

## Phase 6 - Settings Behavior

Goal:

Complete the settings window behavior with transactional commits and parity with current WinForms settings semantics.

Required context:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`, settings behavior
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, manual settings checks
- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`, Settings section
- Current `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`

Actions:

1. Implement non-modal single-instance settings behavior owned by main.
2. Keep settings above main and mirror topmost behavior.
3. Implement inline feedback.
4. Implement text/numeric commit on Enter and lost focus, with rollback on validation failure.
5. Implement checkbox commit with rollback on failure.
6. Implement Targets tab:
   - add
   - delete
   - move up/down
   - edit name/address/color
   - color preview
   - enable/disable
   - duplicate/blank/invalid validation
   - last-enabled-target guards
7. Implement Columns tab:
   - visibility
   - last-visible-column guard
   - order
   - selected width editor
8. Implement Timing tab:
   - refresh interval
   - ping timeout
   - history length
   - auto-start toggle and start-on-enable behavior
9. Implement Health tab:
   - failure thresholds
   - RTT thresholds and ordering validation
   - loss thresholds and ordering validation
10. Implement General tab:
   - always-on-top
   - debug logging
   - reset window position
   - reset to defaults confirmation/cancel/confirm behavior

Gate criteria:

- Settings construction checks pass.
- Config transaction tests pass for valid and invalid edits.
- Targets tab checks pass, including last-enabled-target guards.
- Columns tab checks pass, including last-visible-column guard and persisted width/order/visibility.
- Timing tab checks pass, including auto-start persistence and start-on-enable behavior.
- Health tab checks pass, including invalid threshold ordering rollback.
- General tab checks pass, including reset window position and reset-to-defaults closing settings after successful confirm.
- Monitoring continues while settings is open.

## Phase 7 - Persistence, Lifecycle, And Launch Verification

Goal:

Finish app lifecycle behavior, persistence, launch shims, and error handling.

Required context:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`, window and lifecycle behavior
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`, persistence rules
- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`, launcher and helper disposition
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, launch/window/debug checks
- Current `Run_Network_Monitor.cmd`, `Run_Network_Monitor.vbs`, `MainForm.ps1`, `Config.ps1`, `Logging.ps1`

Actions:

1. Persist window bounds, pin state, target settings, column layout, thresholds, timing, auto-start, and debug mode.
2. Implement first-run bottom-left placement and off-screen fallback.
3. Ensure main close exits completely and settings close closes only settings.
4. Ensure settings cog focuses existing instance and active state clears on settings close.
5. Verify pin/topmost behavior for main and settings.
6. Verify launcher behavior through direct PS1, CMD, and VBS paths where possible.
7. Verify fatal startup errors are visible and logged.

Gate criteria:

- Relaunch tests show persisted bounds, topmost, and config changes.
- Off-screen fallback can be tested by seeded config.
- Direct PS1 launch works.
- CMD launcher command path is correct and launchable.
- VBS launcher path is correct; no-console behavior may be marked `DEFERRED_TARGET` only if the current local environment cannot verify it.
- Debug-off and debug-on logging behavior matches the spec.
- No ToolLauncher integration has been added unless separately requested.

## Phase 8 - Visual Refinement And Operator Continuity

Goal:

Make the WPF app look close to the current WinForms app while accepting WPF-native rendering differences.

Required context:

- `02_EXISTING_UI_VISUAL_SPEC.md`
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, manual visual checks
- `12_RESOLVED_WPF_DECISIONS.md`, DP-015
- Screenshot: `Network_Monitor_Winform_UI.png`

Actions:

1. Compare main window against the screenshot for layout, palette, typography, column widths, and visual hierarchy.
2. Check title bar height, grid header height, row height, status dot/text layout, and history bars.
3. Check default first-run window size behavior against the resolved decision.
4. Check text clipping at default size.
5. Check horizontal scrolling when columns require it.
6. Check settings visual language against the main app.
7. Adjust WPF styles/resources as needed without adding external dependencies.

Gate criteria:

- The WPF app is recognizably the same compact dark utility as the WinForms screenshot.
- Main content remains grid-only.
- Default six columns and three default rows match.
- Node colors match configured target colors.
- Status, RTT, Loss, and History colors match behavior.
- WPF-native rendering differences are limited to expected text/grid rendering differences.
- No text clipping or incoherent overlap is visible at default size.

## Phase 9 - Final Acceptance And Handoff

Goal:

Prove the local rewrite is complete and produce a concise handoff for target-machine validation.

Required context:

- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`
- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`
- All phase result notes

Actions:

1. Run the full WPF test harness.
2. Run the current WinForms harness again as a baseline guard.
3. Re-run parser/module/XAML construction checks.
4. Perform every feasible manual check in `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`.
5. Audit `10_REQUIREMENTS_TRACEABILITY_MATRIX.md` row by row and confirm each applicable row is implemented or documented as target-deferred.
6. Document target-only checks that remain:
   - target-machine launch under `pwsh.exe`
   - VBS no-console behavior if not locally verified
   - real target-network reachable/unreachable observations
   - final operator visual acceptance on the target display
7. Do not delete or overwrite WinForms fallback.

Gate criteria:

- Full WPF test harness passes.
- Current WinForms test harness still passes.
- All completed WPF source files parse.
- Main and settings XAML load under STA.
- All local source-backed requirements are implemented.
- All target-only gaps are explicitly listed with exact verification steps.
- Final output tells the user what was implemented, what was verified, and what remains target-only.

## Failure Handling

If a phase cannot pass:

1. Stay in the phase.
2. Identify the failing requirement and source document.
3. Inspect the current WinForms source for the behavior.
4. Fix the implementation or the test if the test is wrong.
5. Re-run the phase gate.
6. Continue only after the gate passes.

If a blocker is external:

1. Mark the phase `BLOCKED`.
2. Document the exact missing condition.
3. Document what was completed and verified before the blocker.
4. Do not claim the rewrite is complete.

## Completion Definition

The rewrite is complete when:

- `Scripts\Network_Monitor_WPF` launches standalone.
- The app does not depend on ToolLauncher, internet, NuGet, external modules, or external visual assets.
- The current WinForms fallback remains intact.
- The WPF app preserves the current monitoring, config, settings, lifecycle, and visual behavior documented in this planning pack.
- Phase 9 passes with only legitimate target-machine checks deferred.
