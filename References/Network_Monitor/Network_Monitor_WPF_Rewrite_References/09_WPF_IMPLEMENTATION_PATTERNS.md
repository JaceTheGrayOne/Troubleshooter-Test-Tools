# WPF Implementation Patterns

Generated: 2026-06-23

## Purpose

This document provides concrete implementation patterns for a PowerShell-hosted WPF rewrite. It is not the full implementation, but it gives a fresh session enough structure to avoid common WPF/PowerShell traps.

Resolved implementation choices:

- PowerShell-hosted WPF with runtime-loaded XAML files.
- Separate XAML files under `Views`.
- WPF `DataGrid` for the main monitor.
- WPF `SolidColorBrush` presentation values for direct binding.
- `PSCustomObject` view models first; C# helpers only if needed.
- Dark-styled `TextBox` controls for numeric settings.
- `WindowChrome` first for custom title bar/resizing; manual/native fallback only if needed.

## Assembly Loading

Startup assembly load:

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
```

If `System.Xaml` is unavailable or unnecessary under the selected runtime, remove it only after XAML load tests pass.

The launcher should probe these assemblies under `pwsh.exe` first. If the probe fails, it should retry under `powershell.exe`.

## WPF Application Loop

Application loop:

```powershell
$app = [System.Windows.Application]::new()
$window = Build-NMMainWindow -AppRoot $script:NMAppRoot
[void]$app.Run($window)
```

Do not create multiple `Application` instances in the same process.

For tests, build windows without starting `Run()`.

## XAML Loading

Helper shape:

```powershell
function Import-NMXaml {
    param([Parameter(Mandatory)][string]$Path)

    $reader = $null
    try {
        $reader = [System.Xml.XmlReader]::Create($Path)
        return [System.Windows.Markup.XamlReader]::Load($reader)
    }
    finally {
        if ($reader) { $reader.Close() }
    }
}
```

Named control lookup:

```powershell
function Get-NMNamedElement {
    param(
        [Parameter(Mandatory)][System.Windows.FrameworkElement]$Root,
        [Parameter(Mandatory)][string]$Name
    )

    $element = $Root.FindName($Name)
    if (-not $element) {
        throw "Required XAML element '$Name' was not found."
    }
    return $element
}
```

## Resource Names

Use stable resource names for colors:

```text
WindowBrush
TitleBarBrush
TitleBarHoverBrush
TitleBarPressedBrush
SurfaceBrush
SurfaceAltBrush
GridBrush
GridAltBrush
GridLineBrush
BorderBrush
TextBrush
MutedBrush
AccentBrush
AccentDarkBrush
GreenBrush
YellowBrush
OrangeBrush
RedBrush
DisabledBrush
```

Use stable resource names for fonts/sizes:

```text
TitleFontFamily
GridFontFamily
SettingsFontFamily
TitleFontSize
GridFontSize
GridHeaderFontSize
SettingsFontSize
TitleBarHeight
GridHeaderHeight
GridRowHeight
```

## WPF Color Creation In PowerShell

Hex to brush:

```powershell
function New-NMWpfBrush {
    param([Parameter(Mandatory)][string]$Hex)

    $brush = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
    )
    $brush.Freeze()
    return $brush
}
```

If a brush needs to change dynamically, do not freeze that brush. For fixed theme colors, freezing is fine.

## View Model Fallback Ladder

### Step A - Simple PSCustomObject

Good for initial implementation:

```powershell
$target = $script:NMConfig.Targets | Where-Object { $_.Enabled } | Select-Object -First 1

[pscustomobject]@{
    Name = [string]$target.Name
    Address = [string]$target.Address
    NodeForeground = New-NMWpfBrush -Hex ([string]$target.Color)
    StatusText = 'UP'
    StatusForeground = $script:NMBrushes.Green
    RttText = 'NA'
    RttForeground = $script:NMBrushes.Red
    LossText = '0.0%'
    LossForeground = $script:NMBrushes.Green
    HistorySamples = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
}
```

Target node foreground must come from the target's configured `Color` value. Do not hard-code target colors as theme brushes such as `Magenta` or `Cyan`. If brush caching is added, cache by normalized target color hex value.

When changing values, WPF may not update every binding automatically unless the object supports property notifications. If unreliable, replace the row object or use Step B/C.

### Step B - Observable Hashtable/Dictionary Pattern

Use a row object with stable properties plus explicit grid refresh:

```powershell
$grid.Items.Refresh()
```

Use sparingly. Refreshing the whole grid every cycle can be acceptable for small target counts, but the current app's design prefers row updates in place.

### Step C - Small C# INotifyPropertyChanged

Use only if needed. This requires runtime C# compilation through `Add-Type -TypeDefinition`, so it is a fallback rather than the starting point.

```csharp
public class NetMonRow : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    private void OnChanged(string name) {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
```

This is more WPF-correct but adds in-memory compilation complexity.

Resolved direction: start with `PSCustomObject`; use this C# pattern only if WPF binding refresh becomes unreliable or the non-C# workaround is materially more complex.

## Observable Collections

PowerShell can create observable collections:

```powershell
$rows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$rows.Add($row)
$monitorGrid.ItemsSource = $rows
```

All collection changes must occur on the UI dispatcher.

## DataGrid Column Creation

PowerShell pattern:

```powershell
$column = [System.Windows.Controls.DataGridTextColumn]::new()
$column.Header = 'RTT'
$column.Binding = [System.Windows.Data.Binding]::new('RttText')
$column.Width = [System.Windows.Controls.DataGridLength]::new(130)
$column.MinWidth = 105
$column.CanUserSort = $false
```

Foreground binding for text columns can use `ElementStyle`:

```powershell
$style = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
$binding = [System.Windows.Data.Binding]::new('RttForeground')
$setter = [System.Windows.Setter]::new(
    [System.Windows.Controls.TextBlock]::ForegroundProperty,
    $binding
)
$style.Setters.Add($setter)
$column.ElementStyle = $style
```

If this becomes too cumbersome in PowerShell, define column styles/templates in XAML and only bind generated columns to those templates.

## Status Template

XAML shape:

```xml
<DataTemplate x:Key="StatusCellTemplate">
  <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="18,0,6,0">
    <Ellipse Width="16" Height="16" Fill="{Binding StatusForeground}"/>
    <TextBlock
      Text="{Binding StatusText}"
      Foreground="{Binding StatusForeground}"
      FontFamily="Consolas"
      FontSize="11"
      FontWeight="Bold"
      Margin="12,0,0,0"
      VerticalAlignment="Center"/>
  </StackPanel>
</DataTemplate>
```

## History Template

XAML shape:

```xml
<DataTemplate x:Key="HistoryCellTemplate">
  <ItemsControl ItemsSource="{Binding HistorySamples}" Margin="12,0,12,0">
    <ItemsControl.ItemsPanel>
      <ItemsPanelTemplate>
        <UniformGrid Rows="1"/>
      </ItemsPanelTemplate>
    </ItemsControl.ItemsPanel>
    <ItemsControl.ItemTemplate>
      <DataTemplate>
        <Rectangle
          Width="5"
          Height="24"
          Fill="{Binding Brush}"
          HorizontalAlignment="Center"
          VerticalAlignment="Center"/>
      </DataTemplate>
    </ItemsControl.ItemTemplate>
  </ItemsControl>
</DataTemplate>
```

If `UniformGrid` is unavailable in namespace context, add the proper XML namespace for `System.Windows.Controls`.

## Selection Color Preservation

Problem to avoid:

- WPF `DataGridCell` selection style can override text foreground.

Pattern:

- Define a `DataGridCell` style that does not force selected foreground to white.
- Bind `TextBlock.Foreground` directly in cell templates/styles.
- Keep selected background subtle.

Example XAML idea:

```xml
<Style TargetType="{x:Type DataGridCell}">
  <Setter Property="Background" Value="Transparent"/>
  <Setter Property="BorderBrush" Value="{StaticResource GridLineBrush}"/>
  <Setter Property="BorderThickness" Value="0,0,1,1"/>
  <Style.Triggers>
    <Trigger Property="IsSelected" Value="True">
      <Setter Property="Background" Value="{StaticResource TitleBarHoverBrush}"/>
      <Setter Property="Foreground" Value="{Binding RelativeSource={RelativeSource Self}, Path=Foreground}"/>
    </Trigger>
  </Style.Triggers>
</Style>
```

The exact trigger may need adjustment. The acceptance check is more important than the exact style shape.

## Title Bar Buttons

Title button approach:

- Use WPF `Button` controls with custom style.
- Content is a `Path` or small `Grid` of paths.
- Store `Kind`/active state in `Tag` or bind to a simple view model.

Button style requirements:

- Width/height about `38`.
- Background transparent/title bar.
- Hover `TitleBarHoverBrush`.
- Pressed `TitleBarPressedBrush`.
- Foreground `TextBrush`.
- Active foreground `AccentBrush`.
- No visible rectangular text labels.
- Tooltips present.

## Path Icons

Use inline path geometry, not font glyphs.

Possible icon resource names:

```text
SettingsIconGeometry
RefreshIconGeometry
PinIconGeometry
MinimizeIconGeometry
MaximizeIconGeometry
RestoreIconGeometry
CloseIconGeometry
```

Exact geometry does not need to match WinForms GDI drawing perfectly. It should be visually equivalent and compact.

## Window Chrome And Drag

Use `System.Windows.Shell.WindowChrome` first. It should provide native-like resizing while allowing the custom title bar. If `WindowChrome` cannot be made reliable under the selected PowerShell host, use the manual drag pattern below as the fallback.

Basic manual drag pattern:

```powershell
$titleBar.Add_MouseLeftButtonDown({
    param($sender, $eventArgs)
    if ($eventArgs.ClickCount -eq 2) {
        Invoke-NMWpfMaximizeToggle -Window $script:NMMainWindow
        return
    }
    $script:NMMainWindow.DragMove()
}.GetNewClosure())
```

Important:

- Do not call `DragMove()` from title bar button clicks.
- If using `WindowChrome`, mark title buttons as hit-test visible client areas.

## DispatcherTimer Pattern

```powershell
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds([int]$script:NMConfig.RefreshMilliseconds)
$timer.Add_Tick({ Invoke-NMPingCycle })
$timer.Start()
```

Completion polling timer:

```powershell
$completion = [System.Windows.Threading.DispatcherTimer]::new()
$completion.Interval = [TimeSpan]::FromMilliseconds(50)
$completion.Add_Tick({ Complete-NMPingCycleIfReady })
```

These handlers run on the dispatcher thread.

## Async Ping Pattern

Start:

```powershell
$ping = [System.Net.NetworkInformation.Ping]::new()
$task = $ping.SendPingAsync($address, [int]$script:NMConfig.PingTimeoutMilliseconds)
```

Poll:

```powershell
if (-not $task.IsCompleted) { return }
$reply = $task.GetAwaiter().GetResult()
```

Dispose:

```powershell
if ($ping) { $ping.Dispose() }
```

Do not update UI/state from a task continuation unless you explicitly use:

```powershell
$dispatcher.Invoke({ ... })
```

Polling on `DispatcherTimer` is simpler and matches the current fixed implementation.

## Settings Commit Pattern

TextBox commit:

```powershell
function Register-NMTextCommit {
    param(
        [Parameter(Mandatory)]$TextBox,
        [Parameter(Mandatory)][scriptblock]$OnCommit
    )

    $TextBox.Tag = [pscustomobject]@{
        LastCommitted = [string]$TextBox.Text
        Committing = $false
        OnCommit = $OnCommit
    }

    $TextBox.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Key -eq [System.Windows.Input.Key]::Enter) {
            Invoke-NMTextCommit -TextBox $sender
            $eventArgs.Handled = $true
        }
    })

    $TextBox.Add_LostKeyboardFocus({
        param($sender, $eventArgs)
        [void]$eventArgs
        Invoke-NMTextCommit -TextBox $sender
    })
}
```

Commit must:

- Ignore if already committing.
- Compare to `LastCommitted`.
- Invoke transactional config edit.
- Update `LastCommitted` on success.
- Restore textbox text on failure.

## Checkbox Commit Pattern

Checkboxes can commit on click/check:

```powershell
$checkBox.Add_Click({
    param($sender, $eventArgs)
    $checked = [bool]$sender.IsChecked
    # transactional config edit
})
```

On failure, restore prior checked state while suppressing recursive commits.

## Settings Feedback

Use one helper:

```powershell
Set-NMSettingsFeedback -Message 'Target settings saved.' -Error:$false
Set-NMSettingsFeedback -Message 'Target name cannot be blank.' -Error
```

WPF equivalent:

- Set text.
- Set foreground to muted or red.
- Set visibility visible.

## WPF Exception Handlers

Register:

```powershell
$app.add_DispatcherUnhandledException({
    param($sender, $eventArgs)
    Write-NMStartupErrorLog -Message $eventArgs.Exception.ToString()
    $eventArgs.Handled = $true
    [System.Windows.MessageBox]::Show($eventArgs.Exception.Message, 'Network Monitor Error')
})

[System.AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $eventArgs)
    Write-NMStartupErrorLog -Message ("Unhandled exception: {0}" -f $eventArgs.ExceptionObject)
})
```

If handling dispatcher exceptions and continuing could leave state corrupt, show error and close. Decide during implementation based on exception category.

## Avoid These Patterns

Avoid:

- Duplicating health logic in XAML triggers.
- Updating WPF collections from non-dispatcher threads.
- Mutating live config before validation.
- Saving config on every keystroke.
- Relying on emoji/font icons.
- Using external WPF libraries.
- Rebuilding all row objects every ping cycle unless `INotifyPropertyChanged` is deliberately not used and performance remains acceptable.
- Letting selected cell styles override bound health foregrounds.
