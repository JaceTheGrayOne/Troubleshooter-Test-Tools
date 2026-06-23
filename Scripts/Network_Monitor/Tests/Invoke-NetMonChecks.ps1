$ErrorActionPreference = 'Stop'

$script:Failures = 0
$script:AppRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$script:ModuleOrder = @(
    'Logging.ps1'
    'Validation.ps1'
    'Config.ps1'
    'MonitorState.ps1'
    'PingEngine.ps1'
    'UiHelpers.ps1'
    'Presentation.ps1'
    'SettingsForm.ps1'
    'MainForm.ps1'
)

function Write-NMCheckPass {
    param([Parameter(Mandatory)][string]$Name)
    Write-Host ("PASS {0}" -f $Name)
}

function Write-NMCheckFail {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Message
    )

    $script:Failures++
    Write-Host ("FAIL {0}: {1}" -f $Name, $Message) -ForegroundColor Red
}

function Assert-NMCheck {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-NMCheck {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Body
    )

    try {
        & $Body
        Write-NMCheckPass -Name $Name
    }
    catch {
        Write-NMCheckFail -Name $Name -Message $_.Exception.Message
    }
}

function Import-NMAppModules {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    foreach ($moduleName in $script:ModuleOrder) {
        $path = Join-Path $script:AppRoot (Join-Path 'Scripts' $moduleName)
        . $path
    }
}

function New-NMTempRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('NetMonChecks-{0}' -f ([guid]::NewGuid().ToString('N')))
    $null = New-Item -ItemType Directory -Force -Path $root
    return $root
}

function Remove-NMTempRoot {
    param([AllowNull()][string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return
    }

    $prefix = Join-Path ([System.IO.Path]::GetTempPath()) 'NetMonChecks-'
    $resolved = Resolve-Path -LiteralPath $Root -ErrorAction SilentlyContinue
    if ($resolved -and $resolved.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $Root -Recurse -Force
    }
}

function Initialize-NMTestRuntime {
    param([Parameter(Mandatory)][string]$Root)

    $script:NMAppRoot = $Root
    Initialize-NMTheme
    $script:NMConfig = Initialize-NMConfig -AppRoot $Root
    $script:NMGeneration = 1
    Initialize-NMMonitorState
    Initialize-NMPingEngine
}

function Find-NMControlByName {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Root,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Root.Name -eq $Name) {
        return $Root
    }

    foreach ($child in @($Root.Controls)) {
        $match = Find-NMControlByName -Root $child -Name $Name
        if ($match) {
            return $match
        }
    }

    return $null
}

function Test-NMColorEquals {
    param(
        [Parameter(Mandatory)][System.Drawing.Color]$Actual,
        [Parameter(Mandatory)][System.Drawing.Color]$Expected
    )

    return ($Actual.ToArgb() -eq $Expected.ToArgb())
}

Invoke-NMCheck -Name 'Parser' -Body {
    foreach ($file in Get-ChildItem -LiteralPath $script:AppRoot -Recurse -Filter '*.ps1') {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        Assert-NMCheck -Condition (-not $errors -or $errors.Count -eq 0) -Message ("Parser errors in {0}: {1}" -f $file.FullName, (($errors | ForEach-Object { $_.Message }) -join '; '))
    }
}

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    foreach ($moduleName in $script:ModuleOrder) {
        $path = Join-Path $script:AppRoot (Join-Path 'Scripts' $moduleName)
        . $path
    }

    Assert-NMCheck -Condition ($null -ne (Get-Command Get-NMColumnPresentation -ErrorAction SilentlyContinue)) -Message 'Presentation module did not load.'
    Write-NMCheckPass -Name 'Module Load'
}
catch {
    Write-NMCheckFail -Name 'Module Load' -Message $_.Exception.Message
    exit 1
}

Invoke-NMCheck -Name 'Config' -Body {
    $tempRoot = New-NMTempRoot
    try {
        $script:NMAppRoot = $tempRoot
        $default = Get-NMDefaultConfig
        $errors = @()
        Assert-NMCheck -Condition (Test-NMConfig -Config $default -Errors ([ref]$errors)) -Message ('Default config failed validation: {0}' -f ($errors -join '; '))

        $script:NMConfig = Initialize-NMConfig -AppRoot $tempRoot
        $configPath = $script:NMConfigPath
        Set-Content -LiteralPath $configPath -Value '{ "Targets": [] }' -Encoding UTF8
        $script:NMConfig = Initialize-NMConfig -AppRoot $tempRoot
        $backups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $configPath) -Filter 'NetworkMonitor.config.invalid-*.json')
        Assert-NMCheck -Condition ($backups.Count -eq 1) -Message 'Invalid config was not backed up.'
        Assert-NMCheck -Condition (@($script:NMConfig.Targets).Count -eq 3) -Message 'Defaults were not regenerated after invalid config.'

        $beforeNames = @($script:NMConfig.Targets | ForEach-Object { $_.Name }) -join ','
        $failed = $false
        try {
            [void](Invoke-NMConfigEdit -Edit {
                param($config)
                $config.Targets = @()
            })
        }
        catch {
            $failed = $true
        }

        Assert-NMCheck -Condition $failed -Message 'Invalid transactional edit did not fail.'
        $afterNames = @($script:NMConfig.Targets | ForEach-Object { $_.Name }) -join ','
        Assert-NMCheck -Condition ($afterNames -eq $beforeNames) -Message 'Failed transactional edit replaced live config.'
    }
    finally {
        Remove-NMTempRoot -Root $tempRoot
    }
}

$script:CheckFormRoot = $null
$script:CheckMainForm = $null
$script:CheckSettingsForm = $null

Invoke-NMCheck -Name 'Form Construction' -Body {
    $script:CheckFormRoot = New-NMTempRoot
    Initialize-NMTestRuntime -Root $script:CheckFormRoot
    $script:CheckMainForm = Build-NMMainForm
    $null = $script:CheckMainForm.Handle
    Assert-NMCheck -Condition ($script:CheckMainForm -ne $null) -Message 'Main form was not built.'
    Assert-NMCheck -Condition ($script:NMGrid -ne $null) -Message 'Grid was not created.'
    Assert-NMCheck -Condition ($script:NMGrid.Rows.Count -eq 3) -Message ('Expected 3 default rows, found {0}.' -f $script:NMGrid.Rows.Count)
    foreach ($column in @('Node', 'Address', 'Status', 'RTT', 'Loss', 'History')) {
        Assert-NMCheck -Condition ($script:NMGrid.Columns.Contains($column)) -Message ("Missing grid column {0}." -f $column)
    }
    Assert-NMCheck -Condition ((Find-NMControlByName -Root $script:CheckMainForm -Name 'NMTitleBar') -ne $null) -Message 'Main title bar was not created.'

    $script:CheckSettingsForm = Build-NMSettingsForm
    $null = $script:CheckSettingsForm.Handle
    Assert-NMCheck -Condition ($script:CheckSettingsForm.Handle -ne $script:CheckMainForm.Handle) -Message 'Main and settings handles are not distinct.'
    $tabs = Find-NMControlByName -Root $script:CheckSettingsForm -Name 'NMSettingsTabs'
    Assert-NMCheck -Condition ($tabs -ne $null) -Message 'Settings tabs were not created.'
    Assert-NMCheck -Condition ($tabs.TabPages.Count -eq 5) -Message ('Expected 5 settings tabs, found {0}.' -f $tabs.TabPages.Count)
    Assert-NMCheck -Condition (@($tabs.TabPages | Where-Object { $_.Text -eq 'Health' }).Count -eq 1) -Message 'Health tab was not created.'
    Assert-NMCheck -Condition ((Find-NMControlByName -Root $script:CheckSettingsForm -Name 'NMTitleButtonClose') -ne $null) -Message 'Settings close button was not created.'
}

Invoke-NMCheck -Name 'Presentation' -Body {
    $target = $script:NMConfig.Targets[0]
    Reset-NMMonitorState
    $state = $script:NMTargetStates[[string]$target.Name]
    foreach ($column in Get-NMSupportedColumnIds) {
        $presentation = Get-NMColumnPresentation -State $state -Target $target -ColumnId $column
        foreach ($property in @('Text', 'ForeColor', 'Font', 'PaintKind')) {
            Assert-NMCheck -Condition ($presentation.PSObject.Properties[$property] -ne $null) -Message ("Presentation for {0} lacks {1}." -f $column, $property)
        }
    }

    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').Text -eq 'UP') -Message 'No-sample status should be UP.'
    Assert-NMCheck -Condition (Test-NMColorEquals (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').ForeColor $script:NMColors.Green) -Message 'No-sample status should be green.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -eq 'NA') -Message 'No-sample RTT should be NA.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Loss').Text -eq '0.0%') -Message 'No-sample loss should be 0.0%.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'TTL').Text -eq '--') -Message 'No-sample TTL should be --.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Bytes').Text -eq '--') -Message 'No-sample bytes should be --.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'History').PaintKind -eq 'History') -Message 'History should be custom-painted.'

    Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null })
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').Text -eq 'UP') -Message 'One failed sample should not be DOWN.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -eq 'timeout') -Message 'Failed RTT should be timeout.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Loss').Text -eq '100.0%') -Message 'One failed sample should show 100.0% loss.'

    Update-NMStateFromPingResults -Results @(
        [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null }
        [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null }
    )
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').Text -eq 'DOWN') -Message 'Three failed samples should be DOWN.'
    Assert-NMCheck -Condition (Test-NMColorEquals (Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Status').ForeColor $script:NMColors.Red) -Message 'DOWN status should be red.'

    Reset-NMMonitorState
    Update-NMStateFromPingResults -Results @([pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $true; RttMs = 3; Bytes = 32; Ttl = 64 })
    $state = $script:NMTargetStates[[string]$target.Name]
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'RTT').Text -eq '3 ms') -Message 'Successful RTT text is wrong.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Loss').Text -eq '0.0%') -Message 'Successful loss text is wrong.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'TTL').Text -eq '64') -Message 'Successful TTL text is wrong.'
    Assert-NMCheck -Condition ((Get-NMColumnPresentation -State $state -Target $target -ColumnId 'Bytes').Text -eq '32') -Message 'Successful bytes text is wrong.'
}

Invoke-NMCheck -Name 'Grid Selection Colors' -Body {
    Reset-NMMonitorState
    Update-NMGridFromState
    $target = $script:NMConfig.Targets[0]
    $state = $script:NMTargetStates[[string]$target.Name]
    $script:NMGrid.CurrentCell = $script:NMGrid.Rows[0].Cells['RTT']
    $script:NMGrid.Rows[0].Cells['RTT'].Selected = $true
    foreach ($column in @('RTT', 'Loss')) {
        $presentation = Get-NMColumnPresentation -State $state -Target $target -ColumnId $column
        $cell = $script:NMGrid.Rows[0].Cells[$column]
        Assert-NMCheck -Condition (Test-NMColorEquals $cell.Style.SelectionForeColor $presentation.ForeColor) -Message ("Selected {0} color differs from presentation." -f $column)
    }
}

Invoke-NMCheck -Name 'Ping State' -Body {
    Reset-NMMonitorState
    $failedResults = foreach ($target in @($script:NMConfig.Targets)) {
        [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = $false; RttMs = $null; Bytes = $null; Ttl = $null }
    }

    Update-NMStateFromPingResults -Results $failedResults
    foreach ($target in @($script:NMConfig.Targets)) {
        $state = $script:NMTargetStates[[string]$target.Name]
        Assert-NMCheck -Condition ($state.History.Count -eq 1) -Message ("{0} did not record one failed sample." -f $target.Name)
        Assert-NMCheck -Condition ((Get-NMStatusText -State $state) -eq 'UP') -Message ("{0} should still be UP after one failure." -f $target.Name)
    }

    $beforeCounts = @{}
    foreach ($target in @($script:NMConfig.Targets)) {
        $beforeCounts[[string]$target.Name] = $script:NMTargetStates[[string]$target.Name].History.Count
    }
    Update-NMStateFromPingResults -Results @()
    foreach ($target in @($script:NMConfig.Targets)) {
        Assert-NMCheck -Condition ($script:NMTargetStates[[string]$target.Name].History.Count -eq $beforeCounts[[string]$target.Name]) -Message 'Empty result set mutated state.'
    }

    Update-NMStateFromPingResults -Results $failedResults
    Update-NMStateFromPingResults -Results $failedResults
    foreach ($target in @($script:NMConfig.Targets)) {
        $state = $script:NMTargetStates[[string]$target.Name]
        Assert-NMCheck -Condition ((Get-NMStatusText -State $state) -eq 'DOWN') -Message ("{0} did not reach DOWN after threshold." -f $target.Name)
        Assert-NMCheck -Condition ([double]$state.LossPercent -eq 100.0) -Message ("{0} rolling loss should be 100.0." -f $target.Name)
    }

    Reset-NMMonitorState
    $mixed = @()
    for ($i = 0; $i -lt @($script:NMConfig.Targets).Count; $i++) {
        $target = $script:NMConfig.Targets[$i]
        $mixed += [pscustomobject]@{ Name = $target.Name; Address = $target.Address; Success = ($i -eq 0); RttMs = 2; Bytes = 32; Ttl = 64 }
    }
    Update-NMStateFromPingResults -Results $mixed
    Assert-NMCheck -Condition ($script:NMTargetStates[[string]$script:NMConfig.Targets[0].Name].LatestSuccess) -Message 'Successful mixed target was not marked successful.'
}

Invoke-NMCheck -Name 'Ping Engine' -Body {
    Stop-NMMonitoring
    $script:NMConfig.Targets = @(
        [ordered]@{ Name = 'Loopback'; Address = '127.0.0.1'; Color = '#27d9e6'; Enabled = $true }
        [ordered]@{ Name = 'NoRoute'; Address = '203.0.113.1'; Color = '#ff40e6'; Enabled = $true }
    )
    $script:NMConfig.PingTimeoutMilliseconds = 100
    $script:NMConfig.HistoryLength = 4
    $script:NMGeneration++
    Reset-NMMonitorState
    Apply-NMColumnsToGrid
    Initialize-NMPingEngine

    Invoke-NMPingCycle
    $deadline = (Get-Date).AddSeconds(6)
    while ($script:NMPingCycleBusy -and (Get-Date) -lt $deadline) {
        Complete-NMPingCycleIfReady
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }

    Assert-NMCheck -Condition (-not $script:NMPingCycleBusy) -Message 'Ping cycle did not complete.'
    Assert-NMCheck -Condition ($script:NMTargetStates['Loopback'].History.Count -eq 1) -Message 'Loopback attempted ping did not produce one sample.'
    Assert-NMCheck -Condition ($script:NMTargetStates['NoRoute'].History.Count -eq 1) -Message 'Failed attempted ping did not produce one sample.'
    Assert-NMCheck -Condition (-not [bool]$script:NMTargetStates['NoRoute'].LatestSuccess) -Message 'NoRoute should be recorded as failed.'
}

Invoke-NMCheck -Name 'Event Capture Audit' -Body {
    $ui = Get-Content -LiteralPath (Join-Path $script:AppRoot 'Scripts\UiHelpers.ps1') -Raw
    $settings = Get-Content -LiteralPath (Join-Path $script:AppRoot 'Scripts\SettingsForm.ps1') -Raw
    $main = Get-Content -LiteralPath (Join-Path $script:AppRoot 'Scripts\MainForm.ps1') -Raw
    Assert-NMCheck -Condition ($settings -notmatch 'Enable-NMSettingsTitleDrag|New-NMSettingsTitleBar') -Message 'Settings-specific title-bar helpers remain.'
    Assert-NMCheck -Condition ($main -notmatch 'function\s+New-NMColumnPresentation|function\s+Get-NMColumnPresentation') -Message 'Column presentation functions remain in MainForm.ps1.'
    Assert-NMCheck -Condition ($ui -match 'function\s+Enable-NMWindowDrag' -and $ui -match '\$targetForm = \$Form' -and $ui -match 'SendMessage\(\$targetForm\.Handle') -Message 'Shared drag helper does not capture the target form.'
    Assert-NMCheck -Condition ($ui -match 'OnClick = \$OnClick' -and $ui -match '\$sender\.Tag\.OnClick') -Message 'Helper button callbacks do not use stable Tag callback state.'
    Assert-NMCheck -Condition ($settings -match 'OnCommit = \$OnCommit' -and $settings -match 'Invoke-NMNumericCommit') -Message 'Numeric commit handlers do not use stable Tag state.'
    Assert-NMCheck -Condition ((Get-Content -LiteralPath (Join-Path $script:AppRoot 'Network_Monitor.ps1') -Raw) -match 'Presentation\.ps1') -Message 'Presentation.ps1 is missing from entry load order.'
}

try {
    Stop-NMMonitoring
    if ($script:CheckSettingsForm -and -not $script:CheckSettingsForm.IsDisposed) { $script:CheckSettingsForm.Dispose() }
    if ($script:CheckMainForm -and -not $script:CheckMainForm.IsDisposed) { $script:CheckMainForm.Dispose() }
}
catch {
}
finally {
    Remove-NMTempRoot -Root $script:CheckFormRoot
}

if ($script:Failures -gt 0) {
    exit 1
}

Write-Host 'All Network Monitor checks passed.'
exit 0
