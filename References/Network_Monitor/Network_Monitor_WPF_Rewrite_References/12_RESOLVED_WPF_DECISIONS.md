# Resolved WPF Decisions

Generated: 2026-06-23

## Purpose

This document distills the user responses from:

`08_WPF_DECISION_POINTS_UNDECIDED.md`

This does not erase or rewrite the raw decision log. Treat this document as the authoritative implementation directive version of those answers.

If `08_WPF_DECISION_POINTS_UNDECIDED.md` still contains `Status: UNDECIDED` labels, those labels are historical and are not open implementation questions.

The raw decision log remains intentionally unmodified.

## Implementation Directives

### DP-001 - Hosting Model

Decision:

- Use PowerShell-hosted WPF with runtime-loaded XAML.

Implementation impact:

- Do not create a compiled .NET WPF project by default.
- Do not require Visual Studio, MSBuild, NuGet, or a build step.
- Load XAML at runtime from files under `Views`.

### DP-002 - PowerShell Runtime Fallback

Decision:

- Prefer `pwsh.exe`.
- Add a WPF assembly-load probe.
- Fall back to `powershell.exe` if WPF assemblies cannot load under PowerShell 7.

Implementation impact:

- Launcher/runtime logic must not blindly assume PowerShell 7 can host WPF.
- Probe at least:
  - `PresentationFramework`
  - `PresentationCore`
  - `WindowsBase`
  - `System.Xaml` if the implementation requires it.
- Only surface a fatal runtime error if both preferred and fallback hosts fail.

### DP-003 - Target Folder

Decision:

- Build in `Scripts\Network_Monitor_WPF` first.

Implementation impact:

- Do not overwrite `Scripts\Network_Monitor`.
- Keep the current WinForms app intact for comparison and fallback.
- WPF config/log paths resolve relative to `Scripts\Network_Monitor_WPF`.

### DP-004 - XAML File Strategy

Decision:

- Use separate XAML files under `Views`.

Implementation impact:

- Main XAML file: `Views\MainWindow.xaml`.
- Settings XAML file: `Views\SettingsWindow.xaml`.
- PowerShell scripts load these at runtime.
- Avoid embedding large XAML here-strings in `.ps1` files.

### DP-005 - Window Chrome Implementation

Decision:

- Try WPF `WindowChrome` first.
- Use manual/native fallback only if `WindowChrome` does not behave correctly under the selected PowerShell host.

Implementation impact:

- Start with `System.Windows.Shell.WindowChrome`.
- Preserve custom title bar, drag, double-click maximize/restore, resize, minimize, maximize/restore, and close behavior.
- Mark title-bar buttons as client/clickable regions as needed.
- Add manual `DragMove()` or native `SendMessage` only as a fallback.

### DP-006 - Main Monitor Control

Decision:

- Use WPF `DataGrid`.

Implementation impact:

- Do not build a custom main `ItemsControl` table.
- Use DataGrid support for headers, scrolling, resizing, reordering, visibility, and persisted widths.
- Use template columns for `Status` and `History`.
- Disable sorting.

### DP-007 - Presentation Color Values

Decision:

- Expose WPF brushes for direct binding.

Implementation impact:

- Presentation objects should use `SolidColorBrush` values, not `System.Drawing.Color`.
- Freeze fixed theme brushes where practical.
- Avoid color converters unless a concrete implementation problem appears.

### DP-008 - View Model Type

Decision:

- Start with `PSCustomObject` plus explicit row refresh/rebinding if sufficient.
- Use small C# `INotifyPropertyChanged` helpers only if WPF binding refresh becomes unreliable.

Implementation impact:

- Do not start with compiled C# row/view-model helpers.
- Prefer PowerShell objects and observable collections.
- If bindings do not update reliably, first try explicit row replacement or `Items.Refresh()`.
- Use `Add-Type -TypeDefinition` C# only as a deliberate fallback.

### DP-009 - Settings Numeric Controls

Decision:

- Use plain dark-styled `TextBox` controls with numeric validation and Enter/lost-focus commit.

Implementation impact:

- Do not build or import a custom spinner dependency.
- Implement validation and rollback in PowerShell.
- Preserve current commit semantics:
  - Enter commits.
  - Lost focus commits.
  - Invalid values restore the previous committed value.

### DP-010 - Main Window Default Size

Decision:

- Compute first-run default size from visible columns and enabled target count, with minimum `820 x 260`.
- Use `1040 x 270` as the generated config baseline.

Implementation impact:

- Do not hard-code `1120 x 330` as the default just because the screenshot uses that size.
- First-run placement should calculate a compact non-clipping window.
- The screenshot remains the visual reference, not the default bounds contract.

### DP-011 - Settings Window Resizability

Decision:

- Keep the settings window fixed-size initially.

Implementation impact:

- Use `ResizeMode="NoResize"` for settings.
- Preserve approximately `800 x 470`.
- Do not spend implementation time on responsive settings resizing during the first WPF rewrite.

### DP-012 - Config Location

Decision:

- Keep config next to the script.

Implementation impact:

- Use `Scripts\Network_Monitor_WPF\config\NetworkMonitor.config.json`.
- Do not move settings to AppData or another per-user location.
- Preserve current behavior even if a shared network folder can cause multi-user config collisions.

### DP-013 - Existing WinForms App Retirement

Decision:

- Keep WinForms as fallback until WPF is verified on the target air-gapped machine.

Implementation impact:

- Do not delete or overwrite current WinForms code during WPF implementation.
- Keep both apps available until target-machine WPF validation passes.

### DP-014 - Launcher Catalog Integration Timing

Decision:

- Defer ToolLauncher integration until standalone WPF testing passes.

Implementation impact:

- Do not update `ToolLauncher.ps1` or `Tools\tools.json` during the initial WPF rewrite unless separately requested.
- First goal is standalone launch and target-PC validation.

### DP-015 - Pixel Match Strictness

Decision:

- Match layout, palette, typography, column widths, and visual hierarchy closely, but allow WPF-native rendering differences.

Implementation impact:

- The WPF app should look recognizably like `Network_Monitor_Winform_UI.png`.
- Do not chase exact pixel parity at the cost of behavior, maintainability, or WPF-native layout.

### DP-016 - Add-Type C# Helpers

Decision:

- Avoid C# helpers until needed.
- Allow only small, local helper classes if they reduce complexity materially.

Implementation impact:

- Remember that C# via `Add-Type -TypeDefinition` requires runtime compilation into an in-memory assembly.
- Use it only for a concrete binding/interoperability problem.
- Keep any C# helper small, local, documented, and optional where possible.

## Final Resolved Path

The WPF rewrite should be:

- PowerShell-hosted.
- Runtime-XAML based.
- Built first in `Scripts\Network_Monitor_WPF`.
- Launched through its own CMD/VBS shims.
- Configured from a JSON file next to the WPF script.
- Implemented with WPF `DataGrid`.
- Styled to match the current dark WinForms dashboard closely.
- Verified standalone before ToolLauncher integration.
- Implemented without C# helpers unless PowerShell-only binding/window behavior proves unreliable.
