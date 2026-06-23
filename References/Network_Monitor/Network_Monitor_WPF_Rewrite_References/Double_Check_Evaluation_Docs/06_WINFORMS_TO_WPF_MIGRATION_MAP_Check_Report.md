# 06_WINFORMS_TO_WPF_MIGRATION_MAP Check Report

Source document checked:

- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`

Source material checked against:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Run_Network_Monitor.cmd`
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`
- `Scripts\Network_Monitor\Scripts\*.ps1`
- `Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`
- `References\Network_Monitor\Network_Monitor.ps1`

## Verification Notes

- Current source inventory is accurate. The listed files exist and their roles match the current implementation.
- Launch shim descriptions match `Run_Network_Monitor.cmd` lines 1-4 and `Run_Network_Monitor.vbs` lines 1-40.
- File-level mapping is generally source-supported and methodologically sound.
- Validation, config, monitor-state, presentation, and ping-engine function lists match actual functions in the current source.
- Legacy console features not to port are source-supported by `References\Network_Monitor\Network_Monitor.ps1`; verified references include `-RefreshSeconds`, console cursor handling, ANSI formatting, EMA RTT, window-title summary, log trimming, and history bitmask behavior.

## ISSUE-06-001 - Helper Function Mapping Is Not Complete

Status: `RESOLVED`

Resolution:

- Updated `06_WINFORMS_TO_WPF_MIGRATION_MAP.md` on 2026-06-23.
- Added a `Helper Function Disposition` subsection.
- The subsection defines `PORT`, `REPLACE`, and `RETIRE`.
- It explicitly maps the previously omitted `UiHelpers.ps1` and `SettingsForm.ps1` helpers, including numeric commit rollback, selected-column width synchronization, maximize/restore icon switching, and safe handler behavior.

Document location:

- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`, UI Helpers and Settings Window mapping, lines 207-280

Current wording:

- The UI Helpers section lists selected helpers to replace.
- The Settings Window section maps selected settings functions to WPF equivalents.

Source verification:

- Actual `UiHelpers.ps1` functions include several helpers not mapped or explicitly retired:
  - `Get-NMPoint`, `Get-NMSize`, `Get-NMRectangle`: `UiHelpers.ps1` lines 101, 106, and 111.
  - `Get-NMThemeColor`: `UiHelpers.ps1` line 116.
  - `ConvertTo-NMDrawingColor`: `UiHelpers.ps1` line 126.
  - `Add-NMSafeEvent`: `UiHelpers.ps1` line 132.
  - `Set-NMTitleButtonMargin`: `UiHelpers.ps1` line 191.
  - `Invoke-NMFormMaximizeToggle`: `UiHelpers.ps1` line 197.
  - `Use-NMButtonTheme`: `UiHelpers.ps1` line 319.
  - `Use-NMTextBoxTheme`: `UiHelpers.ps1` line 380.
  - `Set-NMIconButtonKind`: `UiHelpers.ps1` line 559.
  - `Enable-NMTitleDrag`: `UiHelpers.ps1` line 569.
- Actual `SettingsForm.ps1` functions include helpers not mapped or explicitly retired:
  - `Set-NMNumericCommittedValue`: `SettingsForm.ps1` line 16.
  - `Invoke-NMNumericCommit`: `SettingsForm.ps1` line 34.
  - `Update-NMColumnWidthEditor`: `SettingsForm.ps1` line 460.
  - `New-NMNumericSetting`: `SettingsForm.ps1` line 598.
  - `New-NMCheckboxSetting`: `SettingsForm.ps1` line 624.
  - `New-NMSettingsNumericRow`: `SettingsForm.ps1` line 646.

Why this matters:

- Some omitted helpers are simple WinForms implementation details, but others represent behavior that must be preserved or consciously replaced: maximize/restore state, icon kind switching, safe handler capture, numeric commit rollback, and selected-column width synchronization.

Recommended correction:

- Add a "Helper Function Disposition" subsection that lists every current helper not already mapped and marks each as one of:
  - `PORT`: preserve logic in WPF.
  - `REPLACE`: replaced by XAML/style/binding/WindowChrome.
  - `RETIRE`: not needed in WPF.
- At minimum, explicitly map numeric commit helpers, column width editor sync, maximize/restore icon switching, and safe handler-capture behavior to WPF equivalents.

Resolution verification:

- Implemented.
