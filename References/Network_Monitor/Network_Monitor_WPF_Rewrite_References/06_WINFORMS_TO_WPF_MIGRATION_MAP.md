# WinForms To WPF Migration Map

Generated: 2026-06-23

## Purpose

This document maps the current WinForms/PowerShell implementation to the resolved WPF rewrite structure. Use it to avoid missing behavior during the rewrite.

## Current Source Inventory

Current app root:

`Scripts\Network_Monitor`

Current files:

| Current File | Role |
|---|---|
| `Network_Monitor.ps1` | Entry point, app root detection, STA relaunch, module load, startup error handling |
| `Run_Network_Monitor.cmd` | Visible shim that starts VBS |
| `Run_Network_Monitor.vbs` | Hidden launcher, prefers `pwsh.exe`, falls back to `powershell.exe` |
| `Scripts\Logging.ps1` | Debug logging and startup error logging |
| `Scripts\Validation.ps1` | Column definitions, config validation, address/color/numeric validation |
| `Scripts\Config.ps1` | Defaults, JSON conversion, strict load, invalid backup, atomic save, transactional edit |
| `Scripts\MonitorState.ps1` | Target state, health/status/RTT/loss calculations |
| `Scripts\PingEngine.ps1` | WinForms timer based async ping cycle and completion polling |
| `Scripts\UiHelpers.ps1` | Theme, WinForms window/title helpers, custom icon drawing |
| `Scripts\Presentation.ps1` | Column text/color/paint-kind presentation |
| `Scripts\SettingsForm.ps1` | WinForms settings window and commit behavior |
| `Scripts\MainForm.ps1` | Main window, grid, placement, runtime effects, startup |
| `Tests\Invoke-NetMonChecks.ps1` | Current nonvisual test harness |
| `config\NetworkMonitor.config.json` | Runtime mutable config |

## High-Level Port Strategy

Port with these buckets:

1. Reuse nearly unchanged:
   - validation
   - config
   - monitor state
   - logging
2. Adapt:
   - presentation colors/types
   - ping engine timers/dispatcher
   - launch scripts naming/path
3. Rewrite in WPF:
   - UI helpers
   - main window
   - settings window
   - icons
   - grid rendering
   - test harness UI construction checks

Resolved WPF choices:

- Build first in `Scripts\Network_Monitor_WPF`.
- Use PowerShell-hosted WPF with separate XAML files under `Views`.
- Prefer `pwsh.exe`, but probe WPF assembly availability and fall back to `powershell.exe` if needed.
- Use WPF `DataGrid` for the main monitor grid.
- Use WPF `SolidColorBrush` values for direct binding.
- Start with `PSCustomObject` row/settings view models plus explicit refresh/rebinding where needed.
- Avoid C# helper classes unless binding or interop problems make them materially simpler.
- Use dark-styled `TextBox` controls for numeric settings.
- Try `WindowChrome` first for the custom title bar and resizing.

## File Mapping

| Current WinForms File | WPF Destination | Notes |
|---|---|---|
| `Network_Monitor.ps1` | `Network_Monitor_WPF.ps1` | Preserve app-root, STA, startup error handling; load WPF assemblies instead of WinForms/Drawing |
| `Run_Network_Monitor.cmd` | `Run_Network_Monitor_WPF.cmd` | Same pattern; update script names |
| `Run_Network_Monitor.vbs` | `Run_Network_Monitor_WPF.vbs` | Same pattern plus WPF assembly probe/fallback from `pwsh.exe` to `powershell.exe` |
| `Logging.ps1` | `Logging.ps1` | Reuse with minor path/name updates |
| `Validation.ps1` | `Validation.ps1` | Reuse almost directly |
| `Config.ps1` | `Config.ps1` | Reuse almost directly |
| `MonitorState.ps1` | `MonitorState.ps1` | Reuse almost directly |
| `Presentation.ps1` | `Presentation.ps1` | Adapt from `System.Drawing.Color`/WinForms alignment to WPF `SolidColorBrush` values/alignment |
| `PingEngine.ps1` | `PingEngine.ps1` | Replace WinForms timers with WPF dispatcher timers |
| `UiHelpers.ps1` | `WpfTheme.ps1`, `WpfXaml.ps1`, `WpfWindowChrome.ps1` | Rewrite; do not carry WinForms/GDI drawing |
| `MainForm.ps1` | `MainWindow.ps1` + `Views\MainWindow.xaml` | Rewrite using WPF layout/binding |
| `SettingsForm.ps1` | `SettingsWindow.ps1` + `Views\SettingsWindow.xaml` | Rewrite using WPF controls/binding |
| `Invoke-NetMonChecks.ps1` | `Invoke-NetMonWpfChecks.ps1` | Adapt tests to WPF XAML/window construction |

## Function-Level Mapping

### Entry Point

| Current Function/Block | WPF Equivalent | Preserve |
|---|---|---|
| `Get-NMEntryRoot` | `Get-NMEntryRoot` | yes |
| `Get-NMPreferredPowerShell` | `Get-NMPreferredPowerShell` | yes, with WPF runtime probe/fallback |
| STA relaunch block | STA relaunch block | yes |
| WinForms `Add-Type` | WPF assembly `Add-Type` | adapt; avoid custom C# `Add-Type` unless needed |
| `$modulePaths` load order | WPF module load order | adapt |
| top-level `try/catch` | top-level `try/catch` | yes |

### Logging

| Current Function | WPF Equivalent | Preserve |
|---|---|---|
| `Write-NMDebugLog` | same | yes |
| `Write-NMStartupErrorLog` | same | yes |

Add WPF:

- `Register-NMWpfExceptionHandlers`
- Dispatcher unhandled exception handling.

### Validation

All current validation functions should carry over:

- `Get-NMSupportedColumnIds`
- `Test-NMMapKey`
- `Test-NMIntegerInRange`
- `Test-NMIPv4Address`
- `Test-NMHostName`
- `Test-NMAddress`
- `Test-NMHtmlColor`
- `Add-NMConfigError`
- `Test-NMConfig`

Column definitions should keep ids, headers, defaults, widths, and min widths.

### Config

All current config functions should carry over:

- `ConvertTo-NMHashtable`
- `Copy-NMDeepValue`
- `Get-NMDefaultConfig`
- `Backup-NMInvalidConfig`
- `Save-NMConfig`
- `Initialize-NMConfig`
- `Get-NMConfigColumn`
- `Save-NMCurrentConfig`
- `Invoke-NMConfigEdit`

Potential WPF additions:

- helper to notify settings/main bindings after transactional edit
- helper to export config into observable target/column view models

### Monitor State

All current monitor-state functions should carry over:

- `Get-NMEnabledTargets`
- `Get-NMTargetByName`
- `New-NMTargetState`
- `Initialize-NMMonitorState`
- `Reset-NMMonitorState`
- `Update-NMStateFromPingResults`
- `Get-NMStatusText`
- `Get-NMHealthName`
- `Get-NMRttHealthName`
- `Get-NMLossHealthName`
- `Get-NMRttText`
- `Get-NMLossText`
- `Get-NMNeutralValue`

WPF-specific state must not creep into this file. Keep it UI-independent.

### Presentation

Current:

- `New-NMColumnPresentation`
- `Get-NMReplyValueText`
- `Get-NMReplyValueColor`
- `Get-NMHistorySampleColor`
- `Get-NMColumnPresentation`

WPF adaptation:

- Replace `System.Drawing.Color` with WPF `SolidColorBrush` values for direct binding.
- Replace WinForms font/alignment values with WPF-compatible values:
  - `FontWeight`
  - `HorizontalContentAlignment`
  - `TemplateKind`

Do not move health logic into XAML triggers.

### Ping Engine

Current functions:

- `Initialize-NMPingEngine`
- `Update-NMPingTimerInterval`
- `Start-NMMonitoring`
- `Stop-NMMonitoring`
- `Clear-NMPingCycleJobs`
- `New-NMFailedPingJob`
- `Invoke-NMPingCycle`
- `Complete-NMPingCycleIfReady`

WPF adaptation:

- Keep function names if practical.
- Replace `[System.Windows.Forms.Timer]` with `[System.Windows.Threading.DispatcherTimer]`.
- Completion polling interval can stay `50 ms`.
- Preserve `NMPingCycleBusy`, `NMPingCycleJobs`, `NMPingCycleGeneration`.
- Preserve generation discard logic.
- Preserve `Invoke-NMOnPingResults` call, but ensure it runs on dispatcher.

### UI Helpers

Current WinForms helpers to replace:

- `NetworkMonitorForm` C# resize subclass.
- `NetworkMonitorNative`.
- `Initialize-NMTheme` returning Drawing colors/fonts.
- `New-NMAppWindow`.
- `New-NMTitleBar`.
- `Enable-NMWindowDrag`.
- `New-NMIconButton`.
- `Draw-NMIcon`.
- WinForms label/button/textbox theming.

WPF equivalents:

- XAML resource dictionary for colors/fonts.
- Shared XAML title bar layout or builder.
- Path-based icons.
- `WindowChrome` first; custom drag/hit testing only as fallback.
- Reusable style resources for buttons, tabs, DataGrid cells.

### Helper Function Disposition

Disposition meanings:

- `PORT`: preserve the behavior in WPF, with the same function name only if useful.
- `REPLACE`: replace with XAML, WPF resources, styles, binding, or WPF-specific helpers.
- `RETIRE`: do not carry forward because the helper only exists for WinForms/GDI mechanics.

Current `UiHelpers.ps1` helpers not otherwise mapped:

| Current Helper | Disposition | WPF Direction |
|---|---|---|
| `Get-NMPoint` | `RETIRE` | Use XAML layout, WPF DIPs, or direct WPF constructors where needed. |
| `Get-NMSize` | `RETIRE` | Use XAML layout, WPF DIPs, or direct WPF constructors where needed. |
| `Get-NMRectangle` | `RETIRE` | Replace GDI rectangle use with XAML layout, `Rect`, or template sizing only where needed. |
| `Get-NMThemeColor` | `PORT` | Provide WPF theme brush/color lookup with the same fallback behavior to primary text. |
| `ConvertTo-NMDrawingColor` | `REPLACE` | Use a WPF hex-to-`Color`/`SolidColorBrush` helper for target colors. |
| `Add-NMSafeEvent` | `PORT` | Preserve safe handler behavior through explicit WPF event wrapper or localized try/catch with startup/debug logging. |
| `Set-NMTitleButtonMargin` | `REPLACE` | Define title-button margin/padding in shared WPF button style. |
| `Invoke-NMFormMaximizeToggle` | `PORT` | Implement `Invoke-NMWpfMaximizeToggle` or equivalent and update maximize/restore state. |
| `Use-NMButtonTheme` | `REPLACE` | Replace with WPF `Button` styles/resources. |
| `Use-NMTextBoxTheme` | `REPLACE` | Replace with WPF `TextBox` styles/resources. |
| `Set-NMIconButtonKind` | `PORT` | Preserve icon-kind switching for maximize/restore through binding or direct path/icon update. |
| `Enable-NMTitleDrag` | `REPLACE` | Replace with shared WPF title drag/`WindowChrome` behavior; do not reintroduce separate settings-title drag helpers. |

Current `SettingsForm.ps1` helpers not otherwise mapped:

| Current Helper | Disposition | WPF Direction |
|---|---|---|
| `Set-NMNumericCommittedValue` | `PORT` | Preserve committed-value tracking for TextBox numeric rollback. |
| `Invoke-NMNumericCommit` | `PORT` | Preserve Enter/lost-focus commit, no-op when unchanged, transactional edit, and rollback on failure. |
| `Update-NMColumnWidthEditor` | `PORT` | Preserve selected-column width editor synchronization, including min width and last committed value. |
| `New-NMNumericSetting` | `REPLACE` | Replace with XAML label/TextBox rows plus shared commit wiring. |
| `New-NMCheckboxSetting` | `REPLACE` | Replace with XAML CheckBox controls plus shared click/rollback commit wiring. |
| `New-NMSettingsNumericRow` | `REPLACE` | Replace with XAML threshold rows plus shared commit wiring. |

### Main Window

Current `MainForm.ps1` behaviors to preserve:

| Current Behavior | WPF Implementation Target |
|---|---|
| `$script:NMWindowTitle` exact string | Window/title text exact string |
| title bar button commands | WPF routed/event handlers |
| bottom-left placement | WPF window placement helper |
| off-screen saved position fallback | WPF placement helper |
| save placement on close | WPF `Closing` handler |
| debounced column persistence | WPF dispatcher timer debounce |
| persistent rows | observable row view models updated in place |
| centralized presentation | row view model fields from `Presentation.ps1` |
| `Status` custom paint | status data template |
| `History` custom paint | history items template |
| selected health colors preserved | WPF selected cell style override |
| `Shown` auto-start | WPF `Loaded` or `ContentRendered` |
| reset/refresh | reset state, update rows, start ping |
| pin/topmost | `Window.Topmost` and config edit |
| settings active icon | bound active state or direct style update |

Current WinForms rendering helpers to translate:

- `Draw-NMStatusCell` -> `StatusCellTemplate`.
- `Draw-NMHistoryCell` -> `HistoryCellTemplate`.
- `Fill-NMGridCellBackground` -> DataGrid row styles.
- `Draw-NMGridCellBorder` -> DataGrid gridline/cell border style.

### Settings Window

Current `SettingsForm.ps1` behavior to preserve:

| Current Function | WPF Equivalent |
|---|---|
| `Set-NMSettingsFeedback` | update bound feedback text/brush |
| `Register-NMNumericCommit` | WPF textbox/numeric commit handlers |
| `Use-NMTabTheme` | TabControl style |
| `Sync-NMTargetsGrid` | refresh/bind target observable collection |
| `Update-NMTargetColorPreview` | bound selected target color preview |
| `Commit-NMTargetCell` | transactional target edit command |
| `New-NMUniqueTargetName` | same |
| `Add-NMTargetFromSettings` | same behavior |
| `Remove-NMSelectedTarget` | same behavior |
| `Move-NMSelectedTarget` | same behavior |
| `Sync-NMColumnsControls` | refresh/bind column controls |
| `Move-NMSelectedColumn` | same behavior |
| `New-NMTimingTab` | XAML section + handlers |
| `New-NMHealthTab` | XAML section + handlers |
| `New-NMGeneralTab` | XAML section + handlers |
| `Build-NMSettingsForm` | load settings XAML, wire events |
| `Show-NMSettingsForm` | one-instance owner window logic |

## Current Runtime Globals To Replace Or Keep

Acceptable durable script state:

- `$script:NMAppRoot`
- `$script:NMConfig`
- `$script:NMConfigPath`
- `$script:NMTargetStates`
- `$script:NMGeneration`
- `$script:NMPingTimer`
- `$script:NMPingCompletionTimer`
- `$script:NMPingCycleBusy`
- `$script:NMPingCycleJobs`
- `$script:NMPingCycleGeneration`
- `$script:NMMainWindow`
- `$script:NMSettingsWindow`
- row/view-model collection references

Avoid script state for:

- temporary selected target/column objects
- local window/control variables that event handlers reference later
- handler callback values
- WPF binding scratch values

Use explicit closure or stable `Tag`/view-model references for delayed handlers.

View-model directive:

- Start with `PSCustomObject` row/settings models and observable collections.
- Use explicit grid row refresh/rebinding if PSCustomObject property changes do not notify reliably.
- Use small local C# `INotifyPropertyChanged` helpers only if the PSCustomObject approach becomes unreliable or materially more complex.

## Current Test Mapping

| Current Test | WPF Test Equivalent |
|---|---|
| Parser | Parse all WPF `.ps1` files |
| Module Load | Load WPF modules and assemblies |
| Config | Same |
| Form Construction | XAML load and WPF window construction |
| Presentation | Same scenarios, WPF brush comparison |
| Grid Selection Colors | Verify selected DataGrid cell retains bound foreground |
| Ping State | Same |
| Ping Engine | Same with dispatcher pump |
| Event Capture Audit | Audit WPF `.Add_*` and handler captures |

## Legacy Console Features Not To Port

Do not port these from `References\Network_Monitor\Network_Monitor.ps1` unless separately requested:

- Console dashboard drawing.
- Console ANSI/unicode padding.
- Console cursor positioning.
- EMA average RTT as primary RTT.
- Console window title summary.
- `-RefreshSeconds` command line as the primary config mechanism.
- Console debug/error log trimming behavior.
- History bitmask implementation.

The WPF target follows the current WinForms app, not the legacy console dashboard.

## Migration Acceptance Checklist

For each current file, verify:

- Behavior is ported or intentionally retired.
- No config schema field is lost.
- No setting is missing.
- No grid column is missing.
- No health/status threshold rule is duplicated inconsistently.
- No UI update happens from a non-dispatcher thread.
- No title bar command is missing.
- No settings commit path bypasses transactional config edits.
