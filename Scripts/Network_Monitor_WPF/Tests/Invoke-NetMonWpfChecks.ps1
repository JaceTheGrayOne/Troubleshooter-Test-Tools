$ErrorActionPreference = 'Stop'

$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:NMSuppressMessageBoxes = $true
$script:TestRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    Join-Path (Get-Location).Path 'Scripts\Network_Monitor_WPF\Tests'
}
$script:AppRoot = Split-Path -Parent $script:TestRoot

function Assert-NM {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [AllowEmptyString()][string]$Message = 'Assertion failed.'
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-NMEqual {
    param(
        [AllowNull()]$Actual,
        [AllowNull()]$Expected,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Actual -ne $Expected) {
        throw ("{0} Expected '{1}', got '{2}'." -f $Message, $Expected, $Actual)
    }
}

function Invoke-NMCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Check
    )

    try {
        & $Check
        Write-Host ("PASS {0}" -f $Name)
    }
    catch {
        $message = "FAIL {0}: {1}" -f $Name, $_.Exception.Message
        Write-Host $message
        $script:Failures.Add($message) | Out-Null
    }
}

function Import-NMWpfTestModules {
    $modulePaths = @(
        'Scripts\Logging.ps1'
        'Scripts\Validation.ps1'
        'Scripts\Config.ps1'
        'Scripts\MonitorState.ps1'
        'Scripts\Presentation.ps1'
        'Scripts\PingEngine.ps1'
        'Scripts\WpfTheme.ps1'
        'Scripts\WpfXaml.ps1'
        'Scripts\WpfWindowChrome.ps1'
        'Scripts\WpfBindings.ps1'
        'Scripts\SettingsWindow.ps1'
        'Scripts\MainWindow.ps1'
    )

    foreach ($modulePath in $modulePaths) {
        . (Join-Path $script:AppRoot $modulePath)
    }
}

function New-NMTempRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('NetMonWpfTest-{0}' -f [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Force -Path $root
    return $root
}

function Start-NMDispatcherPump {
    param([int]$Milliseconds = 50)

    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds($Milliseconds)
    $timer.Add_Tick({
        param($sender, $eventArgs)
        [void]$eventArgs
        $sender.Stop()
        $frame.Continue = $false
    }.GetNewClosure())
    $timer.Start()
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

foreach ($modulePath in @(
    'Scripts\Logging.ps1'
    'Scripts\Validation.ps1'
    'Scripts\Config.ps1'
    'Scripts\MonitorState.ps1'
    'Scripts\Presentation.ps1'
    'Scripts\PingEngine.ps1'
    'Scripts\WpfTheme.ps1'
    'Scripts\WpfXaml.ps1'
    'Scripts\WpfWindowChrome.ps1'
    'Scripts\WpfBindings.ps1'
    'Scripts\SettingsWindow.ps1'
    'Scripts\MainWindow.ps1'
)) {
    . (Join-Path $script:AppRoot $modulePath)
}

function Initialize-NMWpfCleanRuntime {
    $script:NMAppRoot = $script:AppRoot
    $configRoot = Join-Path $script:AppRoot 'config'
    if (-not (Test-Path -LiteralPath $configRoot)) {
        $null = New-Item -ItemType Directory -Force -Path $configRoot
    }
    $script:NMConfigPath = Join-Path $configRoot 'NetworkMonitor.config.json'
    $script:NMConfig = Get-NMDefaultConfig
    Save-NMConfig -Config $script:NMConfig
    Initialize-NetworkMonitorWpfCore -AppRoot $script:AppRoot
    $script:NMConfig.AutoStart = $false
}

Invoke-NMCheck -Name 'Parser' -Check {
    $errors = @()
    foreach ($file in Get-ChildItem -LiteralPath $script:AppRoot -Recurse -Filter '*.ps1') {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
        if ($parseErrors) {
            foreach ($error in $parseErrors) {
                $errors += ("{0}: {1}" -f $file.FullName, $error.Message)
            }
        }
    }
    Assert-NM -Condition ($errors.Count -eq 0) -Message ($errors -join '; ')
}

Invoke-NMCheck -Name 'Assembly Load' -Check {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Window]::new() | Out-Null

    $entry = Get-Content -Raw -LiteralPath (Join-Path $script:AppRoot 'Network_Monitor_WPF.ps1')
    Assert-NM -Condition ($entry -match 'Get-NMWpfCapablePowerShell') -Message 'Entry script does not contain WPF host fallback helper.'
    Assert-NM -Condition ($entry -match 'pwsh\.exe') -Message 'Entry script does not prefer pwsh.exe.'
    Assert-NM -Condition ($entry -match 'powershell\.exe') -Message 'Entry script does not contain Windows PowerShell fallback.'
}

Invoke-NMCheck -Name 'Module Load' -Check {
    foreach ($functionName in @(
        'Write-NMDebugLog',
        'Test-NMConfig',
        'Get-NMDefaultConfig',
        'Initialize-NMMonitorState',
        'Get-NMColumnPresentation',
        'Initialize-NMPingEngine',
        'Initialize-NMWpfTheme',
        'Import-NMWindowXaml',
        'Set-NMWpfWindowChrome',
        'Initialize-NMMonitorGridBinding',
        'Build-NMSettingsWindow',
        'Build-NMMainWindow'
    )) {
        Assert-NM -Condition ([bool](Get-Command $functionName -ErrorAction SilentlyContinue)) -Message "Missing function $functionName."
    }
}

Invoke-NMCheck -Name 'XAML Load' -Check {
    Initialize-NMWpfTheme
    $main = Import-NMWindowXaml -Path (Join-Path $script:AppRoot 'Views\MainWindow.xaml') -RequiredNames @(
        'MainWindowRoot',
        'TitleBar',
        'SettingsButton',
        'RefreshButton',
        'PinButton',
        'MinimizeButton',
        'MaximizeButton',
        'CloseButton',
        'MonitorGrid'
    )
    Assert-NM -Condition ($main.Window -is [System.Windows.Window]) -Message 'Main XAML root is not a Window.'
    $settings = Import-NMWindowXaml -Path (Join-Path $script:AppRoot 'Views\SettingsWindow.xaml') -RequiredNames @(
        'SettingsWindowRoot',
        'TitleBar',
        'SettingsCloseButton',
        'SettingsTabs',
        'FeedbackText',
        'TargetsGrid',
        'ColumnsVisibilityList',
        'ColumnsOrderList',
        'RefreshIntervalTextBox',
        'DownFailuresTextBox',
        'AlwaysOnTopCheckBox'
    )
    Assert-NM -Condition ($settings.Window -is [System.Windows.Window]) -Message 'Settings XAML root is not a Window.'
}

Invoke-NMCheck -Name 'Config' -Check {
    $tempRoot = New-NMTempRoot
    try {
        $script:NMAppRoot = $tempRoot
        $config = Initialize-NMConfig -AppRoot $tempRoot
        $script:NMConfig = $config
        Assert-NMEqual -Actual @($config.Targets).Count -Expected 3 -Message 'Default target count mismatch.'
        Assert-NMEqual -Actual ([string]$config.Window.Width) -Expected '1040' -Message 'Default window width mismatch.'
        Assert-NMEqual -Actual ([string]$config.Window.Height) -Expected '270' -Message 'Default window height mismatch.'
        Assert-NMEqual -Actual @($config.Columns).Count -Expected 8 -Message 'Default column count mismatch.'
        $errors = @()
        Assert-NM -Condition (Test-NMConfig -Config $config -Errors ([ref]$errors)) -Message ('Default config invalid: {0}' -f ($errors -join '; '))

        $before = Copy-NMDeepValue -Value $script:NMConfig
        try {
            Invoke-NMConfigEdit -Edit {
                param($candidate)
                $candidate.Targets[0].Name = ''
            } | Out-Null
            throw 'Invalid edit unexpectedly succeeded.'
        }
        catch {
            Assert-NMEqual -Actual ([string]$script:NMConfig.Targets[0].Name) -Expected ([string]$before.Targets[0].Name) -Message 'Invalid transactional edit mutated live config.'
        }

        '{ "Targets": [] }' | Set-Content -LiteralPath $script:NMConfigPath -Encoding UTF8
        $regenerated = Initialize-NMConfig -AppRoot $tempRoot
        Assert-NMEqual -Actual @($regenerated.Targets).Count -Expected 3 -Message 'Invalid config did not regenerate defaults.'
        $backup = Get-ChildItem -LiteralPath (Join-Path $tempRoot 'config') -Filter 'NetworkMonitor.config.invalid-*.json'
        Assert-NM -Condition (@($backup).Count -ge 1) -Message 'Invalid config backup was not created.'
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-NMCheck -Name 'Logging' -Check {
    $tempRoot = New-NMTempRoot
    try {
        $script:NMAppRoot = $tempRoot
        $script:NMConfig = Get-NMDefaultConfig
        $script:NMConfig.DebugMode = $false
        Write-NMDebugLog -Message 'quiet'
        $logRoot = Join-Path $tempRoot 'logs'
        Assert-NM -Condition (-not (Test-Path -LiteralPath $logRoot)) -Message 'Debug-off logging created a routine log.'
        Write-NMStartupErrorLog -Message 'startup test'
        Assert-NM -Condition (Test-Path -LiteralPath (Join-Path $logRoot 'NetworkMonitor.startup-error.log')) -Message 'Startup error log was not written.'
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Invoke-NMCheck -Name 'Presentation' -Check {
    Initialize-NMWpfTheme
    $script:NMConfig = Get-NMDefaultConfig
    Initialize-NMMonitorState
    $target = $script:NMConfig.Targets[0]
    $state = $script:NMTargetStates[[string]$target.Name]

    $status = Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status'
    Assert-NMEqual -Actual $status.Text -Expected 'UP' -Message 'No-sample status text mismatch.'
    Assert-NMEqual -Actual (Get-NMBrushHex -Brush $status.Foreground) -Expected '#61e243' -Message 'No-sample status brush mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -Expected 'NA' -Message 'No-sample RTT text mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Loss').Text -Expected '0.0%' -Message 'No-sample loss text mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'TTL').Text -Expected '--' -Message 'No-sample TTL text mismatch.'

    Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null })
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -Expected 'timeout' -Message 'Failed RTT text mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Loss').Text -Expected '100.0%' -Message 'Failed loss text mismatch.'

    Update-NMStateFromPingResults -Results @(
        [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null },
        [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null }
    )
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').Text -Expected 'DOWN' -Message 'Down-threshold status mismatch.'

    Reset-NMMonitorState
    Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $true; RttMs = 3; Bytes = 32; Ttl = 64 })
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -Expected '3 ms' -Message 'Successful RTT text mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'TTL').Text -Expected '64' -Message 'Successful TTL text mismatch.'
    Assert-NMEqual -Actual (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Bytes').Text -Expected '32' -Message 'Successful Bytes text mismatch.'
}

Invoke-NMCheck -Name 'Main Window Construction' -Check {
    Initialize-NMWpfCleanRuntime
    $window = Build-NMMainWindow -AppRoot $script:AppRoot
    try {
        Assert-NMEqual -Actual $window.Title -Expected 'Network Monitor - Troubleshooter Test Tools' -Message 'Main title mismatch.'
        Assert-NMEqual -Actual $script:NMRows.Count -Expected 3 -Message 'Default row count mismatch.'
        $rowNames = @($script:NMRows | ForEach-Object { $_.Name })
        Assert-NMEqual -Actual ($rowNames -join ',') -Expected 'SMS,MPS,MPG' -Message 'Default row order mismatch.'
        $visible = @($script:NMMonitorGrid.Columns | Where-Object { $_.Visibility -eq [System.Windows.Visibility]::Visible } | Sort-Object DisplayIndex | ForEach-Object { $_.SortMemberPath })
        Assert-NMEqual -Actual ($visible -join ',') -Expected 'Node,Address,Status,RTT,Loss,History' -Message 'Default visible columns mismatch.'
        $all = @($script:NMMonitorGrid.Columns | ForEach-Object { $_.SortMemberPath })
        Assert-NM -Condition ('TTL' -in $all -and 'Bytes' -in $all) -Message 'TTL and Bytes columns are missing.'
        Assert-NMEqual -Actual ([string]$window.WindowStyle) -Expected 'None' -Message 'Main window is not custom chrome.'
    }
    finally {
        $window.Close()
    }
}

Invoke-NMCheck -Name 'Settings Window Construction' -Check {
    Initialize-NMWpfCleanRuntime
    $main = Build-NMMainWindow -AppRoot $script:AppRoot
    $settings = Build-NMSettingsWindow -Owner $main
    try {
        Assert-NMEqual -Actual $settings.Title -Expected 'Network Monitor Settings' -Message 'Settings title mismatch.'
        Assert-NMEqual -Actual $script:NMSettingsControls.SettingsTabs.Items.Count -Expected 5 -Message 'Settings tab count mismatch.'
        $tabs = @($script:NMSettingsControls.SettingsTabs.Items | ForEach-Object { [string]$_.Header })
        Assert-NMEqual -Actual ($tabs -join ',') -Expected 'Targets,Columns,Timing,Health,General' -Message 'Settings tab order mismatch.'
        Assert-NM -Condition ($script:NMSettingsControls.TargetsGrid -is [System.Windows.Controls.DataGrid]) -Message 'Targets editor is missing.'
        Assert-NM -Condition ($script:NMSettingsControls.ColumnsVisibilityList -is [System.Windows.Controls.ListBox]) -Message 'Columns visibility list is missing.'
        Assert-NMEqual -Actual ([string]$settings.ResizeMode) -Expected 'NoResize' -Message 'Settings window must be fixed size.'
    }
    finally {
        if ($settings) { $settings.Close() }
        if ($main) { $main.Close() }
    }
}

Invoke-NMCheck -Name 'Row View Model Update' -Check {
    Initialize-NMWpfCleanRuntime
    $window = Build-NMMainWindow -AppRoot $script:AppRoot
    try {
        $first = $script:NMRows[0]
        Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = 'SMS'; Address = '192.168.51.20'; Success = $true; RttMs = 4; Bytes = 32; Ttl = 64 })
        Update-NMMonitorRowsFromState
        Assert-NM -Condition ([object]::ReferenceEquals($first, $script:NMRows[0])) -Message 'Ordinary ping update replaced the row object.'
        Assert-NMEqual -Actual $script:NMRows[0].RttText -Expected '4 ms' -Message 'Row RTT did not update.'
        Assert-NMEqual -Actual $script:NMRows[0].HistorySamples.Count -Expected ([int]$script:NMConfig.HistoryLength) -Message 'History display length mismatch.'
        $script:NMConfig.Targets[0].Address = 'localhost'
        $script:NMGeneration++
        Reset-NMMonitorState
        Update-NMMonitorRowsFromState
        Assert-NMEqual -Actual $script:NMRows[0].Address -Expected 'localhost' -Message 'Address edit did not update row presentation.'
        $script:NMConfig.Targets[0].Color = '#27d9e6'
        Update-NMMonitorRowsFromState
        Assert-NMEqual -Actual (Get-NMBrushHex -Brush $script:NMRows[0].NodeForeground) -Expected '#27d9e6' -Message 'Target color edit did not update node foreground.'
        $script:NMConfig.Targets[0].Enabled = $false
        Rebuild-NMMonitorRows
        Assert-NMEqual -Actual $script:NMRows.Count -Expected 2 -Message 'Disabled targets are not hidden.'
    }
    finally {
        $window.Close()
    }
}

Invoke-NMCheck -Name 'Column Persistence' -Check {
    Initialize-NMWpfCleanRuntime
    $window = Build-NMMainWindow -AppRoot $script:AppRoot
    try {
        $node = $script:NMMonitorGrid.Columns | Where-Object { $_.SortMemberPath -eq 'Node' } | Select-Object -First 1
        $node.Width = [System.Windows.Controls.DataGridLength]::new(135)
        Update-NMConfigFromGridColumns
        Assert-NMEqual -Actual ([int](Get-NMConfigColumn -Id 'Node').Width) -Expected 135 -Message 'Column width did not persist.'

        $candidate = Copy-NMDeepValue -Value $script:NMConfig
        foreach ($column in @($candidate.Columns)) { $column.Visible = $false }
        try {
            Save-NMConfig -Config $candidate
            throw 'Invalid all-hidden column config was saved.'
        }
        catch {
            Assert-NM -Condition ($_.Exception.Message -match 'At least one column') -Message 'All-hidden column config was not rejected.'
        }

        Invoke-NMConfigEditAndApply -RebuildGrid -Edit {
            param($config)
            $columns = @($config.Columns)
            $temp = $columns[0]
            $columns[0] = $columns[1]
            $columns[1] = $temp
            $config.Columns = @($columns)
        } | Out-Null
        $ordered = @($script:NMMonitorGrid.Columns | Sort-Object DisplayIndex | ForEach-Object { $_.SortMemberPath })
        Assert-NMEqual -Actual $ordered[0] -Expected 'Address' -Message 'Column reorder did not apply to DataGrid.'
    }
    finally {
        $window.Close()
    }
}

Invoke-NMCheck -Name 'Settings Transactions' -Check {
    Initialize-NMWpfCleanRuntime
    $main = Build-NMMainWindow -AppRoot $script:AppRoot
    $settings = Build-NMSettingsWindow -Owner $main
    try {
        Assert-NM -Condition (-not (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Name' -Value '')) -Message 'Blank target name was accepted.'
        Assert-NMEqual -Actual ([string]$script:NMConfig.Targets[0].Name) -Expected 'SMS' -Message 'Invalid target edit mutated config.'
        Assert-NM -Condition (-not (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Name' -Value 'MPS')) -Message 'Duplicate target name was accepted.'
        Assert-NM -Condition (-not (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Address' -Value '-bad-host-')) -Message 'Invalid address was accepted.'
        Assert-NM -Condition (-not (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Color' -Value 'red')) -Message 'Invalid color was accepted.'
        Assert-NM -Condition (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Address' -Value 'localhost') -Message 'Valid address edit failed.'
        Assert-NMEqual -Actual ([string]$script:NMConfig.Targets[0].Address) -Expected 'localhost' -Message 'Valid target edit did not persist.'

        Add-NMTargetFromSettings
        Assert-NMEqual -Actual ([string]$script:NMConfig.Targets[-1].Name) -Expected 'Node1' -Message 'Add target did not create expected unique name.'
        $script:NMSettingsTargetsGrid.SelectedIndex = @($script:NMConfig.Targets).Count - 1
        Remove-NMSelectedTarget
        Assert-NMEqual -Actual @($script:NMConfig.Targets).Count -Expected 3 -Message 'Delete target did not remove selected row.'

        Assert-NM -Condition (Commit-NMTargetCell -RowIndex 1 -ColumnName 'Enabled' -Value $false) -Message 'Could not disable second target for last-enabled guard setup.'
        Assert-NM -Condition (Commit-NMTargetCell -RowIndex 2 -ColumnName 'Enabled' -Value $false) -Message 'Could not disable third target for last-enabled guard setup.'
        Assert-NM -Condition (-not (Commit-NMTargetCell -RowIndex 0 -ColumnName 'Enabled' -Value $false)) -Message 'Last enabled target disable was accepted.'
        $script:NMConfig = Get-NMDefaultConfig
        Save-NMCurrentConfig
        Apply-NMRuntimeConfigEffects -ResetMonitor -RebuildGrid

        $script:NMSettingsColumnOrderList.SelectedIndex = 0
        Set-NMTextCommittedValue -TextBox $script:NMSettingsColumnWidthTextBox -Value '120'
        $script:NMSettingsColumnWidthTextBox.Text = '99'
        Invoke-NMTextCommit -TextBox $script:NMSettingsColumnWidthTextBox
        Assert-NMEqual -Actual ([int](Get-NMConfigColumn -Id 'Node').Width) -Expected 120 -Message 'Invalid column width mutated config.'

        $script:NMSettingsControls.RttYellowTextBox.Text = '10'
        Invoke-NMTextCommit -TextBox $script:NMSettingsControls.RttYellowTextBox
        Assert-NMEqual -Actual ([int]$script:NMConfig.RttThresholds.YellowMax) -Expected 100 -Message 'Invalid RTT ordering mutated config.'

        $script:NMSettingsControls.RefreshIntervalTextBox.Text = '1250'
        Invoke-NMTextCommit -TextBox $script:NMSettingsControls.RefreshIntervalTextBox
        Assert-NMEqual -Actual ([int]$script:NMConfig.RefreshMilliseconds) -Expected 1250 -Message 'Valid refresh interval did not persist.'

        $script:NMSettingsControls.AutoStartCheckBox.IsChecked = $false
        $script:NMSettingsControls.AutoStartCheckBox.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        Assert-NMEqual -Actual ([bool]$script:NMConfig.AutoStart) -Expected $false -Message 'Auto-start toggle did not persist.'
    }
    finally {
        if ($settings) { $settings.Close() }
        if ($main) { $main.Close() }
    }
}

Invoke-NMCheck -Name 'Ping State' -Check {
    $script:NMConfig = Get-NMDefaultConfig
    Initialize-NMMonitorState
    $failures = @()
    foreach ($target in @($script:NMConfig.Targets)) {
        $failures += [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null }
    }
    Update-NMStateFromPingResults -Results $failures
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['SMS'].History.Count) -Expected 1 -Message 'Failed ping did not add exactly one sample.'
    Update-NMStateFromPingResults -Results $failures
    Update-NMStateFromPingResults -Results $failures
    Assert-NMEqual -Actual (Get-NMStatusText -State $script:NMTargetStates['SMS']) -Expected 'DOWN' -Message 'Down threshold not applied.'
    Assert-NMEqual -Actual (Get-NMLossText -State $script:NMTargetStates['SMS']) -Expected '100.0%' -Message 'Rolling loss mismatch.'
    Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = 'SMS'; Address = '127.0.0.1'; Success = $true; RttMs = 1; Bytes = 32; Ttl = 128 })
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['SMS'].ConsecutiveFailures) -Expected 0 -Message 'Success did not reset consecutive failures.'
    $before = [int]$script:NMTargetStates['SMS'].History.Count
    Update-NMStateFromPingResults -Results @()
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['SMS'].History.Count) -Expected $before -Message 'Empty result set mutated state.'
}

Invoke-NMCheck -Name 'Ping Engine' -Check {
    $script:NMConfig = Get-NMDefaultConfig
    $script:NMConfig.Targets = @(
        [ordered]@{ Name = 'Loopback'; Address = '127.0.0.1'; Color = '#27d9e6'; Enabled = $true }
        [ordered]@{ Name = 'NoRoute'; Address = '203.0.113.1'; Color = '#ff40e6'; Enabled = $false }
    )
    $script:NMConfig.PingTimeoutMilliseconds = 100
    $script:NMConfig.RefreshMilliseconds = 250
    $script:NMGeneration = 1
    Initialize-NMMonitorState
    Initialize-NMPingEngine
    $skipBefore = [int]$script:NMPingSkippedTicks
    $script:NMPingCycleBusy = $true
    Invoke-NMPingCycle
    Assert-NMEqual -Actual ([int]$script:NMPingSkippedTicks) -Expected ($skipBefore + 1) -Message 'Busy ping cycle was not skipped.'
    $script:NMPingCycleBusy = $false

    Invoke-NMPingCycle

    $deadline = (Get-Date).AddSeconds(6)
    while ($script:NMPingCycleBusy -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 20
        Complete-NMPingCycleIfReady
    }
    Assert-NM -Condition (-not $script:NMPingCycleBusy) -Message 'Ping cycle did not complete.'
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['Loopback'].History.Count) -Expected 1 -Message 'Loopback did not produce one sample.'
    Assert-NM -Condition ([bool]$script:NMTargetStates['Loopback'].LatestSuccess) -Message 'Loopback ping did not succeed.'
    Assert-NM -Condition ([int]$script:NMPingDisposedCount -ge 1) -Message 'Ping objects were not disposed.'

    $script:NMPingCycleBusy = $true
    $script:NMPingCycleGeneration = [int]$script:NMGeneration
    $script:NMPingCycleJobs = @(New-NMFailedPingJob -Name 'NoRoute' -Address '203.0.113.1' -ErrorMessage 'simulated start failure')
    Complete-NMPingCycleIfReady
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['NoRoute'].History.Count) -Expected 1 -Message 'Simulated failed ping did not produce one sample.'
    Assert-NM -Condition (-not [bool]$script:NMTargetStates['NoRoute'].LatestSuccess) -Message 'Simulated failed ping unexpectedly succeeded.'

    Reset-NMMonitorState
    $script:NMPingCycleBusy = $true
    $script:NMPingCycleGeneration = 1
    $script:NMGeneration = 2
    $script:NMPingCycleJobs = @(New-NMFailedPingJob -Name 'Loopback' -Address '127.0.0.1' -ErrorMessage 'stale')
    Complete-NMPingCycleIfReady
    Assert-NMEqual -Actual ([int]$script:NMTargetStates['Loopback'].History.Count) -Expected 0 -Message 'Stale generation ping result mutated state.'
}

Invoke-NMCheck -Name 'Launch Shims' -Check {
    $cmd = Get-Content -Raw -LiteralPath (Join-Path $script:AppRoot 'Run_Network_Monitor_WPF.cmd')
    $vbs = Get-Content -Raw -LiteralPath (Join-Path $script:AppRoot 'Run_Network_Monitor_WPF.vbs')
    Assert-NM -Condition ($cmd -match 'Run_Network_Monitor_WPF\.vbs') -Message 'CMD shim does not start WPF VBS shim.'
    Assert-NM -Condition ($vbs -match 'Network_Monitor_WPF\.ps1') -Message 'VBS shim does not point to WPF entry script.'
    Assert-NM -Condition ($vbs -match 'ProbeWpfHost') -Message 'VBS shim does not probe WPF host.'
    Assert-NM -Condition ($vbs -notmatch 'Scripts\\Network_Monitor\\') -Message 'VBS shim references WinForms folder.'
    Assert-NM -Condition ($cmd -notmatch 'Run_Network_Monitor\.vbs') -Message 'CMD shim references WinForms VBS shim.'
}

Invoke-NMCheck -Name 'Event Capture Audit' -Check {
    $scripts = Get-ChildItem -LiteralPath (Join-Path $script:AppRoot 'Scripts') -Filter '*.ps1' -Recurse
    $content = ($scripts | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
    Assert-NM -Condition ($content -notmatch 'Register-ObjectEvent') -Message 'Register-ObjectEvent should not be used.'
    Assert-NM -Condition ($content -notmatch 'ContinueWith') -Message 'Task continuations should not update PowerShell UI/state directly.'
    Assert-NM -Condition ($content -match 'GetNewClosure') -Message 'No explicit closure capture was found for delayed handlers.'
}

if ($script:Failures.Count -gt 0) {
    Write-Host ("{0} Network Monitor WPF checks failed." -f $script:Failures.Count)
    exit 1
}

Write-Host 'All Network Monitor WPF checks passed.'
exit 0
