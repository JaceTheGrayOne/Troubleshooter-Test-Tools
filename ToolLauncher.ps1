$script:rootPath = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    (Get-Location).Path
}
$script:launcherPath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $PSCommandPath
}
else {
    Join-Path $script:rootPath 'ToolLauncher.ps1'
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process -FilePath powershell.exe -WorkingDirectory $script:rootPath -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-STA'
        '-File'
        ('"{0}"' -f $script:launcherPath)
    )
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. (Join-Path $script:rootPath 'Scripts\ToolRuntime.ps1')

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:catalogPath = Join-Path $script:rootPath 'Tools\tools.json'
$script:logsPath = Join-Path $script:rootPath 'Logs'

Ensure-Directory -Path $script:logsPath

$script:tools = @()
$script:toolRuns = @{}
$script:toolValues = @{}
$script:fieldControls = @{}
$script:suppressFieldEvents = $false
$script:currentTool = $null
$script:lastRenderedLogPath = $null
$script:lastRenderedLogText = ''
$script:logClearOffsets = @{}

$script:colors = @{
    Window = [System.Drawing.ColorTranslator]::FromHtml('#101417')
    Panel = [System.Drawing.ColorTranslator]::FromHtml('#171c20')
    Surface = [System.Drawing.ColorTranslator]::FromHtml('#1d2328')
    Control = [System.Drawing.ColorTranslator]::FromHtml('#14191d')
    Border = [System.Drawing.ColorTranslator]::FromHtml('#343c44')
    Text = [System.Drawing.ColorTranslator]::FromHtml('#f4f7fa')
    Muted = [System.Drawing.ColorTranslator]::FromHtml('#aab4bf')
    Accent = [System.Drawing.ColorTranslator]::FromHtml('#0078d4')
    AccentDark = [System.Drawing.ColorTranslator]::FromHtml('#005a9e')
    Teal = [System.Drawing.ColorTranslator]::FromHtml('#37b9ad')
}

$script:fonts = @{
    AppTitle = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
    ToolTitle = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    Section = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    Field = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    List = New-Object System.Drawing.Font('Segoe UI', 10)
    Log = New-Object System.Drawing.Font('Consolas', 9)
}

function Get-Point { param([int]$X, [int]$Y) New-Object System.Drawing.Point($X, $Y) }
function Get-Size { param([int]$Width, [int]$Height) New-Object System.Drawing.Size($Width, $Height) }

function Use-ControlTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.Control]$Control)

    $Control.BackColor = $script:colors.Control
    $Control.ForeColor = $script:colors.Text
}

function Use-ButtonTheme {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Button]$Button,
        [switch]$Primary
    )

    $Button.FlatStyle = 'Flat'
    $Button.FlatAppearance.BorderColor = if ($Primary) { $script:colors.Accent } else { $script:colors.Border }
    $Button.FlatAppearance.MouseOverBackColor = if ($Primary) { $script:colors.AccentDark } else { $script:colors.Surface }
    $Button.BackColor = if ($Primary) { $script:colors.AccentDark } else { $script:colors.Control }
    $Button.ForeColor = $script:colors.Text
}

function Use-TextBoxTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.TextBox]$TextBox)

    $TextBox.BackColor = $script:colors.Control
    $TextBox.ForeColor = $script:colors.Text
    $TextBox.BorderStyle = 'FixedSingle'
}

function Add-UiControl {
    param($Parent, [string]$Type, [int[]]$Bounds, [hashtable]$Properties = @{}, [scriptblock]$Setup = $null)

    $control = New-Object "System.Windows.Forms.$Type"
    $control.Location = Get-Point $Bounds[0] $Bounds[1]
    $control.Size = Get-Size $Bounds[2] $Bounds[3]

    switch ($Type) {
        'Panel' { $control.BackColor = $script:colors.Panel }
        'Label' {
            $control.BackColor = $script:colors.Panel
            $control.ForeColor = $script:colors.Text
        }
        'Button' { Use-ButtonTheme -Button $control }
        'TextBox' { Use-TextBoxTheme -TextBox $control }
        'ListBox' {
            Use-ControlTheme -Control $control
            $control.BorderStyle = 'FixedSingle'
        }
        { $_ -in 'ComboBox', 'NumericUpDown' } { Use-ControlTheme -Control $control }
        'CheckBox' {
            $control.BackColor = $script:colors.Surface
            $control.ForeColor = $script:colors.Text
        }
    }

    if ($Type -eq 'NumericUpDown') {
        foreach ($name in 'Maximum', 'Minimum') {
            if ($Properties.ContainsKey($name)) {
                $control.$name = $Properties[$name]
            }
        }
    }
    foreach ($name in @($Properties.Keys | Where-Object { $_ -ne 'Value' -and ($Type -ne 'NumericUpDown' -or $_ -notin @('Minimum', 'Maximum')) })) {
        $control.$name = $Properties[$name]
    }
    if ($Properties.ContainsKey('Value')) {
        $control.Value = $Properties['Value']
    }
    if ($Setup) {
        & $Setup $control
    }

    $Parent.Controls.Add($control)
    return $control
}

function Get-FieldKey {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)]$Field
    )

    return '{0}.{1}' -f $Tool.id, $Field.name
}

function Get-CurrentToolRun {
    if (-not $script:currentTool) {
        return $null
    }

    return $script:toolRuns[$script:currentTool.id]
}

function Test-AnyToolRunning {
    foreach ($run in $script:toolRuns.Values) {
        if (Test-ToolRunActive -Run $run) {
            return $true
        }
    }

    return $false
}

function Test-ToolInteractiveInput {
    param([AllowNull()]$Tool)

    return ($Tool -and $Tool.interactiveInput -and [bool]$Tool.interactiveInput)
}

function Get-SavedFieldValue {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)]$Field
    )

    $key = Get-FieldKey -Tool $Tool -Field $Field
    if ($script:toolValues.ContainsKey($key)) {
        return $script:toolValues[$key]
    }

    return $Field.default
}

function Get-ToolFieldByName {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][string]$FieldName
    )

    foreach ($field in @($Tool.fields)) {
        if ([string]$field.name -eq $FieldName) {
            return $field
        }
    }

    return $null
}

function Set-SavedFieldValue {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][string]$FieldName,
        [AllowNull()]$Value
    )

    $field = Get-ToolFieldByName -Tool $Tool -FieldName $FieldName
    if (-not $field) {
        return
    }

    $key = Get-FieldKey -Tool $Tool -Field $field
    $script:toolValues[$key] = $Value
}

function Initialize-ToolFieldValues {
    param([Parameter(Mandatory)]$Tool)

    foreach ($field in @($Tool.fields)) {
        $key = Get-FieldKey -Tool $Tool -Field $field
        if (-not $script:toolValues.ContainsKey($key)) {
            $script:toolValues[$key] = $field.default
        }
    }
}

function Get-ControlFieldValue {
    param(
        [Parameter(Mandatory)]$Field,
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control
    )

    switch ([string]$Field.type) {
        'number' { return [int]$Control.Value }
        'checkbox' { return [bool]$Control.Checked }
        'choice' { return [string]$Control.SelectedItem }
        default { return [string]$Control.Text }
    }
}

function Get-CurrentFieldValueOrDefault {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][string]$FieldName
    )

    if ($script:fieldControls.ContainsKey($FieldName)) {
        $entry = $script:fieldControls[$FieldName]
        return Get-ControlFieldValue -Field $entry.Field -Control $entry.Control
    }

    $field = Get-ToolFieldByName -Tool $Tool -FieldName $FieldName
    if (-not $field) {
        return $null
    }

    return Get-SavedFieldValue -Tool $Tool -Field $field
}

function Test-FieldVisible {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)]$Field
    )

    if ([string]$Field.type -eq 'hidden') {
        return $false
    }

    if (-not $Field.visibleWhen) {
        return $true
    }

    foreach ($condition in @($Field.visibleWhen.PSObject.Properties)) {
        $actual = Get-CurrentFieldValueOrDefault -Tool $Tool -FieldName $condition.Name
        $expected = $condition.Value

        if ($expected -is [System.Array]) {
            if ([string]$actual -notin @($expected | ForEach-Object { [string]$_ })) {
                return $false
            }
        }
        elseif ([string]$actual -ne [string]$expected) {
            return $false
        }
    }

    return $true
}

function Save-CurrentFieldState {
    if (-not $script:currentTool) {
        return
    }

    foreach ($fieldName in $script:fieldControls.Keys) {
        $entry = $script:fieldControls[$fieldName]
        $field = $entry.Field
        $control = $entry.Control
        $key = Get-FieldKey -Tool $script:currentTool -Field $field

        $script:toolValues[$key] = Get-ControlFieldValue -Field $field -Control $control
    }
}

function Get-CurrentFieldState {
    Save-CurrentFieldState

    $values = @{}
    if (-not $script:currentTool) {
        return $values
    }

    foreach ($field in @($script:currentTool.fields)) {
        $values[$field.name] = Get-SavedFieldValue -Tool $script:currentTool -Field $field
    }

    return $values
}

function Use-ToolEditorState {
    param([bool]$Enabled)

    foreach ($entry in $script:fieldControls.Values) {
        $entry.Control.Enabled = $Enabled
    }

    if ($presetsPanel) {
        $presetsPanel.Enabled = $Enabled
    }

    $startButton.Enabled = $Enabled -and ($null -ne $script:currentTool)
    $stopButton.Enabled = -not $Enabled
}

function Show-ConsoleInputState {
    $isInteractive = Test-ToolInteractiveInput -Tool $script:currentTool
    $run = Get-CurrentToolRun
    $isRunning = Test-ToolRunActive -Run $run
    $canSendInput = $isInteractive -and $isRunning -and $run -and -not [string]::IsNullOrWhiteSpace($run.InputPath)

    $consoleInputLabel.Visible = $isInteractive
    $consoleInputBox.Visible = $isInteractive
    $sendInputButton.Visible = $isInteractive
    $consoleInputBox.Enabled = $canSendInput
    $sendInputButton.Enabled = $canSendInput

    if (-not $isInteractive) {
        $consoleInputBox.Clear()
    }
}

function Show-CurrentToolStatus {
    if (-not $script:currentTool) {
        $toolTitleLabel.Text = 'No tool selected'
        Use-ToolEditorState -Enabled $false
        Show-ConsoleInputState
        return
    }

    $run = Get-CurrentToolRun
    $isRunning = Test-ToolRunActive -Run $run

    Use-ToolEditorState -Enabled (-not $isRunning)
    Show-ConsoleInputState
}

function Show-LogView {
    $run = Get-CurrentToolRun
    if (-not $run -or [string]::IsNullOrWhiteSpace($run.LogPath)) {
        if ($script:lastRenderedLogPath) {
            $script:lastRenderedLogPath = $null
            $script:lastRenderedLogText = ''
            $logBox.Clear()
        }
        return
    }

    if ($script:lastRenderedLogPath -ne $run.LogPath) {
        $script:lastRenderedLogPath = $run.LogPath
        $script:lastRenderedLogText = ''
        $logBox.Clear()
    }

    $text = Read-SharedTextFile -Path $run.LogPath -ErrorPrefix 'Unable to read log file yet'
    if ($script:logClearOffsets.ContainsKey($run.LogPath)) {
        $clearOffset = [int]$script:logClearOffsets[$run.LogPath]
        if ($clearOffset -le $text.Length) {
            $text = $text.Substring($clearOffset)
        }
        else {
            $script:logClearOffsets.Remove($run.LogPath)
        }
    }

    if ($text -ne $script:lastRenderedLogText) {
        $script:lastRenderedLogText = $text
        $logBox.Text = $text
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.ScrollToCaret()
    }
}

function Invoke-ProtocolSelectionChanged {
    if ($script:suppressFieldEvents -or -not $script:currentTool) {
        return
    }

    Save-CurrentFieldState
    Set-SavedFieldValue -Tool $script:currentTool -FieldName 'PresetId' -Value ''
    Set-SavedFieldValue -Tool $script:currentTool -FieldName 'Action' -Value ''

    Show-Tool -Tool $script:currentTool
}

function Apply-ToolPreset {
    param([Parameter(Mandatory)]$Preset)

    if (-not $script:currentTool) {
        return
    }

    Save-CurrentFieldState

    foreach ($property in @($Preset.values.PSObject.Properties)) {
        Set-SavedFieldValue -Tool $script:currentTool -FieldName $property.Name -Value $property.Value
    }

    if ($Preset.PSObject.Properties.Name -contains 'id') {
        Set-SavedFieldValue -Tool $script:currentTool -FieldName 'PresetId' -Value ([string]$Preset.id)
    }

    if ($Preset.PSObject.Properties.Name -contains 'protocol') {
        Set-SavedFieldValue -Tool $script:currentTool -FieldName 'Protocol' -Value ([string]$Preset.protocol)
    }

    if ($Preset.PSObject.Properties.Name -contains 'action') {
        Set-SavedFieldValue -Tool $script:currentTool -FieldName 'Action' -Value ([string]$Preset.action)
    }

    Show-Tool -Tool $script:currentTool
}

function Show-PresetButtons {
    param([Parameter(Mandatory)]$Tool)

    $presetsPanel.Controls.Clear()
    $presetsPanel.Visible = $false

    if (-not ($Tool.PSObject.Properties.Name -contains 'presetsPath') -or [string]::IsNullOrWhiteSpace($Tool.presetsPath)) {
        return
    }

    $presetsPanel.Visible = $true

    $null = Add-UiControl -Parent $presetsPanel -Type Label -Bounds @(12, 12, 170, 22) -Properties @{
        Text = 'Presets'
        Font = $script:fonts.Section
        BackColor = $script:colors.Surface
    }

    try {
        $presets = @(Get-ToolPresets -RootPath $script:rootPath -Tool $Tool)
    }
    catch {
        $null = Add-UiControl -Parent $presetsPanel -Type Label -Bounds @(12, 42, 170, 74) -Properties @{
            Text = $_.Exception.Message
            ForeColor = $script:colors.Muted
            BackColor = $script:colors.Surface
        }
        return
    }

    $y = 44
    foreach ($preset in $presets) {
        $null = Add-UiControl -Parent $presetsPanel -Type Button -Bounds @(12, $y, 166, 32) -Properties @{
            Text = [string]$preset.label
            Tag = $preset
            Anchor = 'Top, Left, Right'
        } -Setup {
            param($control)
            $control.Add_Click({
                param($sender, $eventArgs)
                [void]$eventArgs
                Apply-ToolPreset -Preset $sender.Tag
            })
        }

        $y += 42
    }
}

function Show-FieldControl {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)]$Field,
        [Parameter(Mandatory)][int]$Y
    )

    $null = Add-UiControl -Parent $fieldsPanel -Type Label -Bounds @(18, $Y, 178, 22) -Properties @{
        Text = [string]$Field.label
        Font = $script:fonts.Field
        BackColor = $script:colors.Surface
    }

    $fieldType = [string]$Field.type
    $savedValue = Get-SavedFieldValue -Tool $Tool -Field $Field

    switch ($fieldType) {
        'number' {
            $minimum = if ($null -ne $Field.minimum) { [decimal]$Field.minimum } else { 0 }
            $maximum = if ($null -ne $Field.maximum) { [decimal]$Field.maximum } else { 999999 }
            $control = Add-UiControl -Parent $fieldsPanel -Type NumericUpDown -Bounds @(210, ($Y - 3), 120, 26) -Properties @{
                Minimum = $minimum
                Maximum = $maximum
                Value = [decimal]$savedValue
            }
        }

        'checkbox' {
            $control = Add-UiControl -Parent $fieldsPanel -Type CheckBox -Bounds @(210, ($Y - 2), 130, 26) -Properties @{
                Text = 'Enabled'
                Checked = [bool]$savedValue
            }
        }

        'choice' {
            $control = Add-UiControl -Parent $fieldsPanel -Type ComboBox -Bounds @(210, ($Y - 3), 260, 26) -Properties @{
                DropDownStyle = 'DropDownList'
            } -Setup {
                param($control)
                foreach ($option in @($Field.options)) {
                    $null = $control.Items.Add([string]$option)
                }
                if ($control.Items.Count -gt 0) {
                    $selectedIndex = $control.Items.IndexOf([string]$savedValue)
                    $control.SelectedIndex = if ($selectedIndex -ge 0) { $selectedIndex } else { 0 }
                }
            }
        }

        default {
            $control = Add-UiControl -Parent $fieldsPanel -Type TextBox -Bounds @(210, ($Y - 3), 298, 26) -Properties @{
                Text = [string]$savedValue
                Anchor = 'Top, Left, Right'
                UseSystemPasswordChar = ($fieldType -eq 'password')
            }
        }
    }

    if ([string]$Field.name -eq 'Protocol' -and $fieldType -eq 'choice') {
        $control.Add_SelectedIndexChanged({
            Invoke-ProtocolSelectionChanged
        })
    }

    if ($Field.help) {
        $null = Add-UiControl -Parent $fieldsPanel -Type Label -Bounds @(18, ($Y + 24), 490, 18) -Properties @{
            Text = [string]$Field.help
            Anchor = 'Top, Left, Right'
            ForeColor = $script:colors.Muted
            BackColor = $script:colors.Surface
        }
        $rowHeight = 58
    }
    else {
        $rowHeight = 42
    }

    $script:fieldControls[$Field.name] = @{
        Field = $Field
        Control = $control
    }

    return $Y + $rowHeight
}

function Show-Tool {
    param([Parameter(Mandatory)]$Tool)

    $script:suppressFieldEvents = $true

    try {
        $script:currentTool = $Tool
        $script:fieldControls = @{}
        Initialize-ToolFieldValues -Tool $Tool
        $fieldsPanel.Controls.Clear()

        $toolTitleLabel.Text = [string]$Tool.name

        $y = 18
        $visibleFieldCount = 0
        foreach ($field in @($Tool.fields)) {
            if (Test-FieldVisible -Tool $Tool -Field $field) {
                $visibleFieldCount++
                $y = Show-FieldControl -Tool $Tool -Field $field -Y $y
            }
        }

        if ($visibleFieldCount -eq 0) {
            $null = Add-UiControl -Parent $fieldsPanel -Type Label -Bounds @(18, 18, 300, 22) -Properties @{
                Text = 'No configurable fields.'
                ForeColor = $script:colors.Muted
                BackColor = $script:colors.Surface
            }
        }

        Show-PresetButtons -Tool $Tool
    }
    finally {
        $script:suppressFieldEvents = $false
    }

    Show-CurrentToolStatus
    Show-LogView
}

function Import-ToolCatalog {
    try {
        $script:tools = @(Get-ToolDefinitions -CatalogPath $script:catalogPath)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Catalog Load Failed', 'OK', 'Error') | Out-Null
        return
    }

    $toolList.BeginUpdate()
    $toolList.Items.Clear()
    foreach ($tool in $script:tools) {
        $null = $toolList.Items.Add([string]$tool.name)
    }
    $toolList.EndUpdate()

    if ($script:tools.Count -gt 0) {
        $toolList.SelectedIndex = 0
        Show-Tool -Tool $script:tools[0]
    }
    else {
        $script:currentTool = $null
        $fieldsPanel.Controls.Clear()
        $presetsPanel.Controls.Clear()
        $presetsPanel.Visible = $false
        Show-CurrentToolStatus
    }
}

function Invoke-SelectedTool {
    if (-not $script:currentTool) {
        return
    }

    $run = Get-CurrentToolRun
    if (Test-ToolRunActive -Run $run) {
        return
    }

    $values = Get-CurrentFieldState

    try {
        $run = Start-ConfiguredTool `
            -RootPath $script:rootPath `
            -LogsPath $script:logsPath `
            -Tool $script:currentTool `
            -FieldValues $values

        $script:toolRuns[$script:currentTool.id] = $run
        $script:lastRenderedLogPath = $null
        $script:lastRenderedLogText = ''
        Show-CurrentToolStatus
        Show-LogView
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Run Failed', 'OK', 'Error') | Out-Null
    }
}

function Invoke-SelectedToolStop {
    $run = Get-CurrentToolRun
    if (-not $run) {
        return
    }

    try {
        Stop-ToolRun -Run $run
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stop Failed', 'OK', 'Error') | Out-Null
    }
    finally {
        Show-CurrentToolStatus
        Show-LogView
    }
}

function Send-ConsoleInput {
    $run = Get-CurrentToolRun
    if (-not (Test-ToolRunActive -Run $run)) {
        return
    }

    try {
        Send-ToolRunInput -Run $run -Text ([string]$consoleInputBox.Text)
        $consoleInputBox.Clear()
        $consoleInputBox.Focus()
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Input Send Failed', 'OK', 'Error') | Out-Null
    }
}

function Sync-RunningTool {
    foreach ($toolId in @($script:toolRuns.Keys)) {
        $run = $script:toolRuns[$toolId]
        if ($run.Process -and $null -eq $run.ExitCode -and $run.Process.HasExited) {
            $run.ExitCode = $run.Process.ExitCode
            $run.EndedAt = Get-Date
        }
    }

    Show-CurrentToolStatus
    Show-LogView
}

function Confirm-RunningToolClose {
    if (-not (Test-AnyToolRunning)) {
        return $true
    }

    $answer = [System.Windows.Forms.MessageBox]::Show(
        'One or more tools are still running. Stop them and close?',
        'Tools Running',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return $false
    }

    foreach ($run in $script:toolRuns.Values) {
        if (Test-ToolRunActive -Run $run) {
            Stop-ToolRun -Run $run
        }
    }

    return $true
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Troubleshooter Test Tools'
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = Get-Size 980 640
$form.Size = Get-Size 1120 740
$form.BackColor = $script:colors.Window
$form.ForeColor = $script:colors.Text

$topPanel = Add-UiControl -Parent $form -Type Panel -Bounds @(16, 14, 1070, 80) -Properties @{ Anchor = 'Top, Left, Right'; BorderStyle = 'FixedSingle' }
$null = Add-UiControl -Parent $topPanel -Type Label -Bounds @(16, 13, 360, 30) -Properties @{ Text = 'Troubleshooter Test Tools'; Font = $script:fonts.AppTitle }

$navPanel = Add-UiControl -Parent $form -Type Panel -Bounds @(16, 108, 260, 552) -Properties @{ Anchor = 'Top, Bottom, Left'; BorderStyle = 'FixedSingle' }
$null = Add-UiControl -Parent $navPanel -Type Label -Bounds @(14, 14, 200, 24) -Properties @{ Text = 'Tools'; Font = $script:fonts.Section }
$toolList = Add-UiControl -Parent $navPanel -Type ListBox -Bounds @(14, 48, 230, 486) -Properties @{ Anchor = 'Top, Bottom, Left, Right'; Font = $script:fonts.List }
$toolList.Add_SelectedIndexChanged({
    if ($toolList.SelectedIndex -lt 0 -or $toolList.SelectedIndex -ge $script:tools.Count) {
        return
    }

    Save-CurrentFieldState
    Show-Tool -Tool $script:tools[$toolList.SelectedIndex]
})

$contentPanel = Add-UiControl -Parent $form -Type Panel -Bounds @(292, 108, 794, 552) -Properties @{ Anchor = 'Top, Bottom, Left, Right'; BorderStyle = 'FixedSingle' }
$toolTitleLabel = Add-UiControl -Parent $contentPanel -Type Label -Bounds @(18, 16, 460, 34) -Properties @{ Text = 'Tool'; Anchor = 'Top, Left, Right'; Font = $script:fonts.ToolTitle }
$fieldsPanel = Add-UiControl -Parent $contentPanel -Type Panel -Bounds @(18, 62, 536, 218) -Properties @{ Anchor = 'Top, Left, Right'; BackColor = $script:colors.Surface; BorderStyle = 'FixedSingle'; AutoScroll = $true }
$presetsPanel = Add-UiControl -Parent $contentPanel -Type Panel -Bounds @(570, 62, 202, 218) -Properties @{ Anchor = 'Top, Right'; BackColor = $script:colors.Surface; BorderStyle = 'FixedSingle'; Visible = $false }

$startButton = Add-UiControl -Parent $contentPanel -Type Button -Bounds @(18, 296, 96, 34) -Properties @{ Text = 'Run' } -Setup { param($control) $control.Add_Click({ Invoke-SelectedTool }); Use-ButtonTheme -Button $control -Primary }
$stopButton = Add-UiControl -Parent $contentPanel -Type Button -Bounds @(126, 296, 96, 34) -Properties @{ Text = 'Stop' } -Setup { param($control) $control.Add_Click({ Invoke-SelectedToolStop }) }
$null = Add-UiControl -Parent $contentPanel -Type Button -Bounds @(234, 296, 106, 34) -Properties @{ Text = 'Open Logs' } -Setup {
    param($control)
    $control.Add_Click({
    Ensure-Directory -Path $script:logsPath
    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:logsPath)
    })
}
$null = Add-UiControl -Parent $contentPanel -Type Button -Bounds @(352, 296, 100, 34) -Properties @{ Text = 'Clear View' } -Setup {
    param($control)
    $control.Add_Click({
    $run = Get-CurrentToolRun
    if ($run -and -not [string]::IsNullOrWhiteSpace($run.LogPath)) {
        $currentText = Read-SharedTextFile -Path $run.LogPath
        $script:logClearOffsets[$run.LogPath] = $currentText.Length
    }

    $script:lastRenderedLogText = ''
    $logBox.Clear()
    })
}

$null = Add-UiControl -Parent $contentPanel -Type Label -Bounds @(18, 348, 120, 24) -Properties @{ Text = 'Console Output'; Font = $script:fonts.Section }
$logBox = Add-UiControl -Parent $contentPanel -Type TextBox -Bounds @(18, 376, 754, 112) -Properties @{ Anchor = 'Top, Bottom, Left, Right'; Multiline = $true; ScrollBars = 'Both'; WordWrap = $false; ReadOnly = $true; Font = $script:fonts.Log }
$consoleInputLabel = Add-UiControl -Parent $contentPanel -Type Label -Bounds @(18, 511, 48, 22) -Properties @{ Text = 'Input'; Anchor = 'Bottom, Left'; Visible = $false }
$consoleInputBox = Add-UiControl -Parent $contentPanel -Type TextBox -Bounds @(76, 506, 578, 26) -Properties @{ Anchor = 'Bottom, Left, Right'; Enabled = $false; Visible = $false } -Setup {
    param($control)
    $control.Add_KeyDown({
    param($controlSender, $keyEventArgs)

    [void]$controlSender

    if ($keyEventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $keyEventArgs.SuppressKeyPress = $true
        Send-ConsoleInput
    }
    })
}
$sendInputButton = Add-UiControl -Parent $contentPanel -Type Button -Bounds @(666, 503, 106, 32) -Properties @{ Text = 'Send'; Anchor = 'Bottom, Right'; Enabled = $false; Visible = $false } -Setup { param($control) $control.Add_Click({ Send-ConsoleInput }); Use-ButtonTheme -Button $control -Primary }

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Sync-RunningTool })
$timer.Start()

$form.Add_FormClosing({
    param($formSender, $formClosingEventArgs)

    [void]$formSender

    if (-not (Confirm-RunningToolClose)) {
        $formClosingEventArgs.Cancel = $true
    }
})

Import-ToolCatalog

[void][System.Windows.Forms.Application]::Run($form)
