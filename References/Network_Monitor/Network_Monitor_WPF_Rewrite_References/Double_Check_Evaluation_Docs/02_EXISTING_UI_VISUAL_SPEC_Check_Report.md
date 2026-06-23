# 02_EXISTING_UI_VISUAL_SPEC Check Report

Source document checked:

- `02_EXISTING_UI_VISUAL_SPEC.md`

Source material checked against:

- `References\Network_Monitor\Network_Monitor_WPF_Rewrite_References\Network_Monitor_Winform_UI.png`
- `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`

## Verification Notes

- The visual direction is source-justified by the current custom borderless dark WinForms UI, the reference screenshot, and the theme initialized in `UiHelpers.ps1` lines 66-99.
- Theme color and font tables match `Initialize-NMTheme` in `UiHelpers.ps1` lines 66-99.
- Main window constants match `MainForm.ps1` lines 1-4 and `Build-NMMainForm` lines 738-746.
- Title bar composition, title text, button order, button size, separator, hover/pressed/active colors, and tooltips match `UiHelpers.ps1` lines 239-315 and 467-545 plus `MainForm.ps1` lines 606-615.
- Grid column widths and minimum widths match `Validation.ps1` lines 1-45 and current config lines 35-70.
- Grid visuals are source-supported by `MainForm.ps1` lines 160-184, 484-520, and 522-590.
- Status dot geometry is source-supported by `MainForm.ps1` lines 416-439.
- History bars and missing-success-failure colors are source-supported by `MainForm.ps1` lines 446-481 and `Presentation.ps1` lines 45-56.
- Settings window size, fixed/non-resizable behavior, tab names/order, tab dimensions, target-grid layout, columns layout, and feedback label location match `SettingsForm.ps1` lines 88-112, 338-430, 511-590, and 909-970.

## ISSUE-02-001 - Theme Source File Should Be Named Explicitly

Status: `RESOLVED`

Resolution:

- Updated `02_EXISTING_UI_VISUAL_SPEC.md` on 2026-06-23.
- The Main Theme Colors section now identifies `Scripts\Network_Monitor\Scripts\UiHelpers.ps1` as the source file for `Initialize-NMTheme`.

Document location:

- `02_EXISTING_UI_VISUAL_SPEC.md`, Main Theme Colors, lines 63-66

Current wording:

- "Current WinForms theme colors from `Initialize-NMTheme`:"

Source verification:

- `Initialize-NMTheme` exists, but it is defined in `Scripts\Network_Monitor\Scripts\UiHelpers.ps1` lines 66-99.
- There is no separate `Theme.ps1` source file.

Why this matters:

- A fresh rewrite session can still find the function by search, but naming the file removes ambiguity and makes the visual spec easier to verify against the current source.

Recommended correction:

- Reword this section to: "Current WinForms theme colors from `Initialize-NMTheme` in `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`."

Resolution verification:

- Implemented.
