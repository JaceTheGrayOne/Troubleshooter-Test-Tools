# 03_CONFIG_STATE_AND_VALIDATION_SPEC Check Report

Source document checked:

- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`

Source material checked against:

- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`

## Verification Notes

- Default config in the document matches `Get-NMDefaultConfig` in `Config.ps1` lines 45-89.
- Column definitions and validation ranges match `Validation.ps1` lines 1-339.
- Config load, invalid backup, atomic save, UTF-8 no BOM write, and transactional clone-save-replace behavior match `Config.ps1` lines 91-199.
- Runtime target state initialization, reset, ping-result update, history trimming, and loss calculation match `MonitorState.ps1` lines 21-82.
- Presentation rules match `MonitorState.ps1` lines 84-157 and `Presentation.ps1` lines 1-95.
- Ping result shape matches `PingEngine.ps1` lines 136-172.
- Window placement behavior matches `MainForm.ps1` lines 6-93.

## ISSUE-03-001 - Grid Rebuild Trigger List Omits Target Rename/Address/Color Edits

Status: `RESOLVED`

Resolution:

- Updated `03_CONFIG_STATE_AND_VALIDATION_SPEC.md` on 2026-06-23.
- The grid rebuild trigger list now states that current WinForms behavior rebuilds the grid for any target settings change, including add, delete, rename, address, color, enable/disable, and reorder.
- A later WPF implementation note permits address/color row-property updates in place as a deliberate WPF improvement, while still requiring monitor state reset and immediate visible presentation updates.

Document location:

- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`, Config Changes And Runtime Effects, lines 501-507

Current wording:

- "These changes rebuild the grid:"
- Target add/delete/enable/disable/reorder.
- Column order/visibility/width.
- Reset to defaults.

Source verification:

- Target cell edits call `Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target settings changed'` in `SettingsForm.ps1` line 229.
- That target edit path is used for non-enabled target fields as well as enabled changes:
  - Name validation/edit: `SettingsForm.ps1` lines 192-207.
  - Address validation/edit: `SettingsForm.ps1` lines 209-215.
  - Color validation/edit: `SettingsForm.ps1` lines 218-224.
- The source therefore rebuilds the grid for target rename, address edit, and color edit, not only add/delete/enable/disable/reorder.

Why this matters:

- A future WPF rewrite could treat rename/address/color edits as in-place row updates only, which would differ from current runtime behavior and may miss row identity/order reconstruction side effects.

Recommended correction:

- Add target rename, target address edit, and target color edit to the grid rebuild trigger list, or replace the target-specific bullets with "Any target settings change, including add, delete, rename, address, color, enable/disable, and reorder."

Resolution verification:

- Implemented.
