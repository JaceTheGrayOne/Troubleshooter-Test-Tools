# 04_WPF_TARGET_ARCHITECTURE Check Report

Source document checked:

- `04_WPF_TARGET_ARCHITECTURE.md`

Source material checked against:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`
- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`

## Verification Notes

- The modular architecture is justified by the current module split loaded in `Network_Monitor.ps1` lines 54-64.
- STA startup, hidden relaunch, app-root discovery, fatal startup handling, and launch-shim adaptation are justified by `Network_Monitor.ps1` lines 3-103 and `Run_Network_Monitor.vbs` line 39.
- Config, validation, state, ping, and presentation reuse recommendations are justified by the current separation in `Config.ps1`, `Validation.ps1`, `MonitorState.ps1`, `PingEngine.ps1`, and `Presentation.ps1`.
- The ping engine guidance is source-supported: current implementation uses one `SendPingAsync()` task per enabled target, WinForms timers for refresh/completion polling, overlap prevention, `Ping` disposal, and generation checking in `PingEngine.ps1` lines 1-187.
- The dispatcher/runspace safety guidance is methodologically sound because the current app relies on WinForms timers and UI-thread callbacks, not arbitrary task-thread mutation.
- WPF DataGrid, templates, XAML resources, and WindowChrome are planned WPF implementation choices, not directly source-verifiable WinForms facts. They are reasonable replacements for DataGridView custom painting and custom borderless WinForms chrome.

## ISSUE-04-001 - WPF Row-Rebuild Strategy Is Narrower Than Current Source Behavior

Status: `RESOLVED`

Resolution:

- Updated `04_WPF_TARGET_ARCHITECTURE.md` on 2026-06-23.
- The architecture now documents the narrower row rebuild behavior as a deliberate WPF improvement, not source parity.
- The target rule is:
  - Current WinForms rebuilds rows for every target settings change.
  - WPF may update target address/color row properties in place when practical.
  - WPF must still reset monitor state/history for address/color changes.
  - WPF must rebuild row identity/order for target add, delete, rename, enable/disable, and reorder.
- Also updated `03_CONFIG_STATE_AND_VALIDATION_SPEC.md` to distinguish current WinForms rebuild behavior from the permitted WPF address/color in-place optimization.

Document location:

- `04_WPF_TARGET_ARCHITECTURE.md`, `WpfBindings.ps1` responsibilities, lines 240-244

Current wording:

- "Rebuild rows only when target/order/enabled changes."
- "Update row properties in place after ping cycles."

Source verification:

- Current WinForms target cell edits all call `Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target settings changed'` in `SettingsForm.ps1` line 229.
- That single path covers target `Name`, `Address`, `Color`, and `Enabled` edits in `SettingsForm.ps1` lines 174-227.
- `Apply-NMRuntimeConfigEffects` calls `Apply-NMColumnsToGrid` when `-RebuildGrid` is set in `MainForm.ps1` lines 646-648.
- `Apply-NMColumnsToGrid` rebuilds both columns and rows in `MainForm.ps1` lines 247-249.
- Therefore the current app rebuilds rows for target rename, address edit, color edit, and enable/disable, not only target/order/enabled changes.

Why this matters:

- Updating address/color in place may be a good WPF implementation choice, but it is not the current WinForms behavior. If the WPF plan keeps this optimization, it should be documented as a deliberate deviation while still preserving visible output and monitor reset semantics.

Recommended correction:

- Reword the responsibility to one of these:
  - Strict parity: "Rebuild rows when current WinForms would rebuild the grid: any target settings change, target add/delete/reorder, column changes, and reset to defaults."
  - Deliberate WPF improvement: "Current WinForms rebuilds rows for any target settings change. WPF may update address/color in place, but must still reset monitor state and must rebuild row identity/order for name, enable/disable, add/delete, and reorder."

Resolution verification:

- Implemented using the deliberate WPF improvement option.
