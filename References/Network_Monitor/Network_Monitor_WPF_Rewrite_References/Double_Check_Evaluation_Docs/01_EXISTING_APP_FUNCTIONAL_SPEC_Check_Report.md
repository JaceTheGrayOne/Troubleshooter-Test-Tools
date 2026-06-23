# 01_EXISTING_APP_FUNCTIONAL_SPEC Check Report

Source document checked:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`

Source material checked against:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Run_Network_Monitor.cmd`
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`
- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\Logging.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`

## Verification Notes

- Core feature inventory is source-supported: the current WinForms app is a standalone PowerShell monitor with hidden launch shims, STA startup, three default targets, asynchronous ping execution, configurable targets, configurable columns, timing settings, health thresholds, window placement persistence, reset-to-defaults behavior, debug logging, and startup error logging.
- The state and display rules are source-supported: `MonitorState.ps1` computes consecutive failures, loss percentage, target health, RTT health, loss health, and display strings; `MainForm.ps1` projects those values into the grid and custom paints status/history cells.
- The config lifecycle is source-supported: `Config.ps1` creates defaults, strictly validates loaded config, backs up invalid config files, saves atomically, and applies live edits transactionally.
- The WPF rewrite methodology is generally justified: preserving config schema and behavior while replacing WinForms UI/timer controls with WPF equivalents is consistent with the existing implementation boundaries.

## ISSUE-01-001 - Debug Logging Coverage Is Overstated

Status: `RESOLVED`

Resolution:

- Updated `01_EXISTING_APP_FUNCTIONAL_SPEC.md` on 2026-06-23.
- The Debug mode section now lists the verified debug-only diagnostics and states that target validation/settings commit failures are primarily surfaced through inline feedback unless they pass through `Show-NMConfigError`.

Document location:

- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`, Logging Behavior, lines 606-610

Current wording:

- "Can log config events, ping-cycle errors, target validation errors, settings commit failures, and paint/render errors."

Source verification:

- `Logging.ps1` lines 1-16 only writes debug log entries when `$script:NMConfig.DebugMode` is enabled.
- Verified debug log call sites are limited to specific runtime paths:
  - Column persistence failure: `MainForm.ps1` line 224.
  - Grid paint failure: `MainForm.ps1` line 587.
  - Runtime config effect reason strings: `MainForm.ps1` line 635.
  - Config-error message text after failed config edits: `MainForm.ps1` line 719.
  - Close-save failure: `MainForm.ps1` line 786.
  - Ping start and ping result errors: `PingEngine.ps1` lines 149 and 164.
- Target validation failures in the settings grid primarily set inline feedback messages, for example `SettingsForm.ps1` lines 186, 196, 202, 212, and 221. They are not independently logged at the validation point.
- Settings commit failures are shown through inline feedback or `Show-NMConfigError`; they are not all guaranteed to create separate, category-specific debug log entries.

Why this matters:

- A future WPF implementation could overbuild logging behavior if it treats this sentence as a complete source-verified logging matrix.

Recommended correction:

- Reword the debug logging description to say the current app logs selected debug-only diagnostics, including ping start/result errors, runtime config effect messages, config edit errors surfaced through `Show-NMConfigError`, column persistence failures, grid paint failures, and close-save failures. Target validation and settings commit failures should be described as primarily surfaced through UI feedback unless they pass through `Show-NMConfigError`.

Resolution verification:

- Implemented.
