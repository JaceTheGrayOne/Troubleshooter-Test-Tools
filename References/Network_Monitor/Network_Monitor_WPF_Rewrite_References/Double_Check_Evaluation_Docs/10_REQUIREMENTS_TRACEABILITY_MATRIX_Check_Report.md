# 10_REQUIREMENTS_TRACEABILITY_MATRIX Check Report

Source document checked:

- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`

Source material checked against:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`
- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\Logging.ps1`

## Verification Notes

- Launch/runtime, main-window, main-grid, monitoring, health/presentation, config, visual-design, and decision-trace rows are generally source-supported.
- Current topmost, taskbar, placement, maximize/restore, close, and settings ownership behavior is represented at a high level.
- Current ping behavior is represented at a high level.
- Current config lifecycle is represented at a high level.

## ISSUE-10-001 - Settings Traceability Is Too Coarse And Misses Specific Source Behaviors

Status: `RESOLVED`

Document location:

- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`, Settings section, lines 97-116

Current wording:

- Tracks the existence of tabs and generic commit/rollback/transaction behavior.

Source verification:

- Current `SettingsForm.ps1` implements many specific settings requirements that are not individually traceable in the matrix:
  - Target add: `SettingsForm.ps1` lines 258-275.
  - Target delete and last-enabled guard: `SettingsForm.ps1` lines 278-307.
  - Target move up/down: `SettingsForm.ps1` lines 310-335.
  - Target name/address/color/enable validation and commit: `SettingsForm.ps1` lines 160-238.
  - Color preview: `SettingsForm.ps1` lines 144-158 and 423-430.
  - Column visibility, last-visible guard, order, and selected width: `SettingsForm.ps1` lines 435-590.
  - Timing settings and auto-start toggle: `SettingsForm.ps1` lines 675-732.
  - Health/RTT/loss threshold settings and ordering validation through full config validation: `SettingsForm.ps1` lines 736-817 plus `Validation.ps1` lines 292-333.
  - Always-on-top and debug logging toggles: `SettingsForm.ps1` lines 819-854.
  - Reset Window Position: `SettingsForm.ps1` lines 857-869.
  - Reset to Defaults confirmation, default restoration, monitor reset, and settings close: `SettingsForm.ps1` lines 872-905.

Why this matters:

- The matrix is intended as a final audit before claiming the rewrite is complete. A fresh implementation session could satisfy the current broad "Targets tab"/"Columns tab"/"General tab" rows while missing specific behaviors such as last-visible-column blocking, target color preview, auto-start start-on-enable behavior, or reset-to-defaults close behavior.

Recommended correction:

- Expand the Settings section with rows for each concrete operation/control group:
  - Target add/delete/move/edit/enable plus validation.
  - Column visibility/order/width plus last-visible guard.
  - Timing fields plus auto-start behavior.
  - Health/RTT/loss threshold fields plus ordering rejection.
  - Always-on-top, debug logging, reset window position, and reset to defaults.
- Include verification references to automated or manual checks for each row.

Resolution:

- Expanded the `10_REQUIREMENTS_TRACEABILITY_MATRIX.md` Settings section from broad tab/commit rows into granular traceability rows for the concrete settings behaviors verified in `SettingsForm.ps1`.
- Added target add/delete/move/edit/enable rows, including duplicate/blank name rejection, invalid address/color rejection, color preview, and last-enabled-target guards.
- Added column visibility/order/width rows, including last-visible-column blocking and selected-width behavior.
- Added timing, auto-start, health, RTT, loss, always-on-top, debug logging, reset-window-position, and reset-to-defaults rows.
- Added verification references to the existing automated checks and manual Settings checks in `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`.
