# WPF Target Architecture

Generated: 2026-06-23

## Purpose

This document defines the target architecture for the WPF rewrite.

The goal is to preserve the current app's behavior while using WPF where it is strongest:

- XAML layout.
- Centralized styles/resources.
- Data binding.
- Data templates.
- Cleaner visual states.
- Dispatcher-safe UI updates.

## Resolved Architecture Summary

Use this approach:

- PowerShell-hosted WPF app.
- Runtime-loaded XAML files.
- Modular PowerShell scripts for config, validation, state, ping engine, and WPF window wiring.
- No compiled project.
- No NuGet packages.
- No external icons/fonts/images.
- WPF `DataGrid` for the main monitor grid.
- XAML `DataTemplate`s for `Status` and `History`.
- `ObservableCollection` or collection views for rows and settings lists.
- `DispatcherTimer` or WPF dispatcher polling for ping completion.
- Centralized presentation model so selected rows preserve health colors.

These choices are resolved in `12_RESOLVED_WPF_DECISIONS.md`.

## Target Folder Layout

Resolved isolated rewrite folder:

```text
Scripts\Network_Monitor_WPF\
  Network_Monitor_WPF.ps1
  Run_Network_Monitor_WPF.cmd
  Run_Network_Monitor_WPF.vbs
  config\
    NetworkMonitor.config.json
  logs\
  Scripts\
    Logging.ps1
    Validation.ps1
    Config.ps1
    MonitorState.ps1
    PingEngine.ps1
    Presentation.ps1
    WpfTheme.ps1
    WpfXaml.ps1
    WpfWindowChrome.ps1
    WpfBindings.ps1
    MainWindow.ps1
    SettingsWindow.ps1
  Views\
    MainWindow.xaml
    SettingsWindow.xaml
  Tests\
    Invoke-NetMonWpfChecks.ps1
```

Rationale:

- Keeps current WinForms implementation intact for comparison.
- Keeps WPF XAML separate from behavior scripts.
- Preserves the existing modular structure.
- Lets a fresh implementation session port core modules with minimal churn.

## Module Responsibilities

### `Network_Monitor_WPF.ps1`

Responsibilities:

- Resolve app root.
- Enforce STA.
- Prefer `pwsh.exe`, probe WPF assembly availability, and fall back to `powershell.exe` if WPF cannot load under PowerShell 7.
- Load WPF assemblies:
  - `PresentationFramework`
  - `PresentationCore`
  - `WindowsBase`
  - `System.Xaml` if needed.
- Load modules in correct order.
- Initialize app state.
- Build main window.
- Start WPF application loop.
- Handle fatal startup errors.

Must not contain:

- Settings UI layout.
- Ping state calculations.
- Config validation logic.
- Per-column health/presentation rules.

### `Logging.ps1`

Same responsibility as current app:

- Debug log only when `DebugMode = true`.
- Startup error log regardless of debug mode for fatal hidden-launch failures.

Add WPF-specific logging entry points if useful:

- Dispatcher unhandled exception.
- XAML load failure.
- Binding diagnostic fallback messages if a binding path cannot be found during manual diagnostics.

### `Validation.ps1`

Same responsibility as current app:

- Supported column definitions.
- Address, hostname, color, integer-range validation.
- Strict full-config validation.

Implementation should be nearly reusable.

### `Config.ps1`

Same responsibility as current app:

- Convert JSON to ordered dictionaries/maps.
- Generate default config.
- Strict load validation.
- Invalid backup.
- Atomic save.
- Transactional edit helper.

Implementation should be nearly reusable.

### `MonitorState.ps1`

Same responsibility as current app:

- Enabled target retrieval.
- Target lookup by name.
- Runtime target state creation.
- Reset all monitor state.
- Apply ping results.
- Calculate status text, health names, RTT text, loss text, neutral values.

Implementation can remain UI-framework independent.

### `PingEngine.ps1`

Responsibilities:

- One async `SendPingAsync()` ping per enabled target per cycle.
- Concurrent pings.
- Skip overlapping cycles.
- Dispose every `Ping` object.
- Return completed results to UI dispatcher/runspace.

WPF approach:

- Use `System.Windows.Threading.DispatcherTimer` for refresh ticks.
- Use a second `DispatcherTimer` or task-continuation marshaled to the dispatcher for completion polling.
- Avoid invoking PowerShell scriptblocks directly from arbitrary task threads.
- Preserve generation checking.

### `Presentation.ps1`

Responsibilities:

- Convert target state and config into row presentation values.
- Own every text/color/template decision for main-grid columns.
- Provide history sample color mapping.

WPF equivalent presentation object:

```powershell
[pscustomobject]@{
    Text = 'timeout'
    Foreground = $script:NMBrushes.Red
    FontWeight = 'Normal'
    TemplateKind = 'Text'
    HorizontalAlignment = 'Left'
}
```

Presentation objects should expose WPF `SolidColorBrush` instances for direct binding. Use frozen brushes for fixed theme colors where practical.

Do not split RTT/loss/status color decisions across XAML triggers and PowerShell functions. XAML should consume presentation state, not recalculate health rules.

### `WpfTheme.ps1`

Responsibilities:

- Create WPF resource dictionaries or provide XAML resource definitions.
- Define theme color names.
- Define font families, sizes, row heights, title bar heights, spacing, border thickness, icon geometry constants.

Theme approach:

- Put static colors/styles in XAML resources.
- Keep PowerShell-accessible hashtable for code-side color mapping.

### `WpfXaml.ps1`

Responsibilities:

- Load XAML files safely.
- Build name maps for controls.
- Surface useful errors if XAML fails to parse.

Required helper behavior:

- Read XAML as text.
- Use `[System.Windows.Markup.XamlReader]::Load()`.
- Return root window and named controls.
- Do not rely on generated code-behind.

### `WpfWindowChrome.ps1`

Responsibilities:

- Implement custom title bar behavior.
- Implement drag, double-click maximize/restore, minimize, close, and resize behavior.
- Keep main and settings windows visually consistent.

Resolved approach:

1. `System.Windows.Shell.WindowChrome` with `WindowStyle=None`.
2. Manual `DragMove()` plus resize grips/hit testing.
3. Native `SendMessage` fallback only if needed.

Try `WindowChrome` first. Use manual/native fallback only if `WindowChrome` does not behave correctly under the selected PowerShell host.

### `WpfBindings.ps1`

Responsibilities:

- Create/update row view models.
- Maintain observable collections.
- Current WinForms rebuilds rows for every target settings change.
- Deliberate WPF improvement:
  - Update target address/color row properties in place when practical.
  - Still reset monitor state/history for address/color changes.
  - Rebuild row identity/order for target add, delete, rename, enable/disable, and reorder.
- Update row properties in place after ping cycles.
- Apply column visibility/order/width to the WPF grid.
- Persist changed column widths/order.

### `MainWindow.ps1`

Responsibilities:

- Load `Views\MainWindow.xaml`.
- Wire title bar commands.
- Initialize main grid columns.
- Initialize row collection.
- Apply window placement.
- Start monitoring on `Loaded` or `ContentRendered`.
- Save placement/config on closing.
- Open/focus settings window.
- Handle reset/refresh/pin/minimize/maximize/close.

Must not contain:

- Low-level config validation.
- Ping result health math.
- Repeated settings control construction.

### `SettingsWindow.ps1`

Responsibilities:

- Load `Views\SettingsWindow.xaml`.
- Wire tab controls and settings editors.
- Bind target list, column list, and thresholds.
- Commit text/numeric settings on Enter/lost focus.
- Commit checkbox settings on click.
- Use transactional config edit helper.
- Show inline validation feedback.
- Keep only one settings window open.

## WPF Main Window Structure

Target XAML structure:

```xml
<Window
    WindowStyle="None"
    ResizeMode="CanResize"
    ShowInTaskbar="True"
    Background="{StaticResource WindowBrush}"
    Title="Network Monitor - Troubleshooter Test Tools">
  <Border BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <Grid x:Name="TitleBar" Grid.Row="0">
        <!-- title left, icon buttons right -->
      </Grid>

      <DataGrid x:Name="MonitorGrid" Grid.Row="1"/>
    </Grid>
  </Border>
</Window>
```

Required visual behaviors:

- Main content grid starts immediately under title bar.
- DataGrid columns do not auto-stretch to fill all available width by default.
- Row height stable around `52`.
- Header height stable around `38`.
- No row header.
- Read-only.
- No sorting.
- Column resize and reorder enabled.

## Main Grid Data Model

Row view model fields:

```text
Name
Address
TargetColor
StatusText
StatusBrush
RttText
RttBrush
LossText
LossBrush
TtlText
TtlBrush
BytesText
BytesBrush
HistorySamples
```

`HistorySamples` should be a fixed-length list for display:

```text
[
  { Value = null, Brush = YellowBrush },
  { Value = true, Brush = GreenBrush },
  { Value = false, Brush = RedBrush }
]
```

Use precomputed WPF brush/display fields for the row model. Avoid color converters unless a concrete implementation problem makes them worthwhile.

## Column Handling In WPF

WPF `DataGrid` columns should be generated/managed from config:

- Create supported columns in config order.
- Set `Visibility` from config.
- Set `Width` from config.
- Set `MinWidth` from column definitions.
- Set `CanUserSort = false`.
- Allow user reorder and resize.
- Persist order/width/visibility after user changes, with debounce for width/order changes.

Column implementation:

- Rebuild DataGrid columns when the `Columns` config changes.
- Use text columns for:
  - Node
  - Address
  - RTT
  - Loss
  - TTL
  - Bytes
- Use template columns for:
  - Status
  - History

Selection colors:

- Override `DataGridCell` selected foreground behavior so bound health foreground remains visible.
- Set selected background close to current row background or title hover.
- Do not allow selected health text to become white unless white is the presentation color.

## WPF Settings Window Structure

Target XAML structure:

```xml
<Window
    WindowStyle="None"
    ResizeMode="NoResize"
    ShowInTaskbar="False"
    Background="{StaticResource WindowBrush}"
    Title="Network Monitor Settings">
  <Border BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="34"/>
      </Grid.RowDefinitions>

      <Grid x:Name="TitleBar" Grid.Row="0"/>

      <TabControl x:Name="SettingsTabs" Grid.Row="1">
        <TabItem Header="Targets"/>
        <TabItem Header="Columns"/>
        <TabItem Header="Timing"/>
        <TabItem Header="Health"/>
        <TabItem Header="General"/>
      </TabControl>

      <TextBlock x:Name="FeedbackText" Grid.Row="2"/>
    </Grid>
  </Border>
</Window>
```

Settings window requirements:

- Owner is main window.
- Topmost mirrors main pinned state.
- One instance only.
- Close button only.
- Non-modal.
- Monitoring continues.

## Event And Runspace Safety

PowerShell-hosted WPF still needs careful delayed handler behavior.

Rules:

- Event handlers that reference local variables should explicitly capture them with `.GetNewClosure()` or store stable state in control `Tag`.
- Do not invoke PowerShell functions from arbitrary worker/task threads unless marshaled to the UI dispatcher/runspace.
- UI collections must be updated on the dispatcher thread.
- Ping task completion should be polled or marshaled back to dispatcher before touching PowerShell state/UI.

## Dispatcher Rules

All UI updates must run on the WPF dispatcher.

State updates should also run on the UI dispatcher unless the state layer is made thread-safe. The current app assumes UI-runspace state mutation. Preserve that assumption for simplicity.

Dispatcher pattern:

- Ping tasks run asynchronously.
- Completion polling timer runs on dispatcher.
- When all tasks complete, collect results on dispatcher by reading task results.
- Apply state and row updates on dispatcher.

## Error Handling

Top-level:

- Catch fatal startup errors.
- Write startup error log.
- Show message box when possible.

WPF runtime:

- Register `Application.DispatcherUnhandledException`.
- Register `AppDomain.CurrentDomain.UnhandledException`.
- Log startup/runtime failures.
- Avoid routine debug logs unless `DebugMode = true`.

## What To Reuse From Current App

Strong reuse candidates:

- Config defaults and validation logic.
- JSON conversion/deep clone logic.
- Atomic save and transactional edit design.
- Target state model.
- Health/status/RTT/loss calculations.
- Ping engine semantics.
- Launch shims, adapted names/paths.
- Test harness structure.

Rewrite rather than directly reuse:

- WinForms UI helpers.
- GDI icon drawing.
- DataGridView rendering.
- WinForms settings form layout.
- WinForms event registration helpers.

Replace with WPF:

- XAML resource dictionary.
- XAML vector icons.
- WPF DataGrid templates.
- WPF window chrome/title bar.
- WPF styled TabControl/settings controls.

## Architecture Completion Criteria

The WPF architecture is acceptable when:

- UI layer consumes centralized presentation values.
- Config edits are transactional.
- Ping completion cannot mutate UI/state from a worker thread.
- Main/settings windows share title bar and theme resources.
- Main grid rows update in place.
- Column layout is persisted.
- Settings commit semantics match current app.
- The rewrite can run offline with no extra packages.
