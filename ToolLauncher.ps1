if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process -FilePath powershell.exe -WorkingDirectory $PSScriptRoot -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-STA'
        '-File'
        ('"{0}"' -f $PSCommandPath)
    )
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. (Join-Path $PSScriptRoot 'Scripts\ToolRuntime.ps1')

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:rootPath = $PSScriptRoot
$script:catalogPath = Join-Path $script:rootPath 'Tools\tools.json'
$script:logsPath = Join-Path $script:rootPath 'Logs'

if (-not (Test-Path -LiteralPath $script:logsPath)) {
    $null = New-Item -ItemType Directory -Path $script:logsPath -Force
}

$script:tools = @()
$script:toolRuns = @{}
$script:toolValues = @{}
$script:fieldControls = @{}
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

function New-Point {
    param([int]$X, [int]$Y)
    New-Object System.Drawing.Point($X, $Y)
}

function New-Size {
    param([int]$Width, [int]$Height)
    New-Object System.Drawing.Size($Width, $Height)
}

function Set-ControlTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.Control]$Control)

    $Control.BackColor = $script:colors.Control
    $Control.ForeColor = $script:colors.Text
}

function Set-ButtonTheme {
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

function Set-TextBoxTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.TextBox]$TextBox)

    $TextBox.BackColor = $script:colors.Control
    $TextBox.ForeColor = $script:colors.Text
    $TextBox.BorderStyle = 'FixedSingle'
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

function Save-CurrentFieldValues {
    if (-not $script:currentTool) {
        return
    }

    foreach ($fieldName in $script:fieldControls.Keys) {
        $entry = $script:fieldControls[$fieldName]
        $field = $entry.Field
        $control = $entry.Control
        $key = Get-FieldKey -Tool $script:currentTool -Field $field

        switch ([string]$field.type) {
            'number' {
                $script:toolValues[$key] = [int]$control.Value
            }
            'checkbox' {
                $script:toolValues[$key] = [bool]$control.Checked
            }
            'choice' {
                $script:toolValues[$key] = [string]$control.SelectedItem
            }
            'password' {
                $script:toolValues[$key] = [string]$control.Text
            }
            default {
                $script:toolValues[$key] = [string]$control.Text
            }
        }
    }
}

function Get-CurrentFieldValues {
    Save-CurrentFieldValues

    $values = @{}
    if (-not $script:currentTool) {
        return $values
    }

    foreach ($field in @($script:currentTool.fields)) {
        $key = Get-FieldKey -Tool $script:currentTool -Field $field
        $values[$field.name] = $script:toolValues[$key]
    }

    return $values
}

function Set-ToolEditorEnabled {
    param([bool]$Enabled)

    foreach ($entry in $script:fieldControls.Values) {
        $entry.Control.Enabled = $Enabled
    }

    $startButton.Enabled = $Enabled -and ($null -ne $script:currentTool)
    $stopButton.Enabled = -not $Enabled
}

function Refresh-ConsoleInputState {
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

function Get-RunStateText {
    param($Run)

    if (-not $Run) {
        return 'Idle'
    }

    if (Test-ToolRunActive -Run $Run) {
        return 'Running PID={0}' -f $Run.Process.Id
    }

    if ($null -ne $Run.ExitCode) {
        return 'Finished ExitCode={0}' -f $Run.ExitCode
    }

    return 'Stopped'
}

function Refresh-StatusForCurrentTool {
    if (-not $script:currentTool) {
        $toolTitleLabel.Text = 'No tool selected'
        $toolDescriptionLabel.Text = ''
        $runStateLabel.Text = 'Idle'
        Set-ToolEditorEnabled -Enabled $false
        return
    }

    $run = Get-CurrentToolRun
    $isRunning = Test-ToolRunActive -Run $run

    $runStateLabel.Text = Get-RunStateText -Run $run
    $runStateLabel.ForeColor = if ($isRunning) { $script:colors.Teal } else { $script:colors.Muted }
    Set-ToolEditorEnabled -Enabled (-not $isRunning)
    Refresh-ConsoleInputState
}

function Refresh-LogView {
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

    $text = Read-SharedTextFile -Path $run.LogPath
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

function Render-Field {
    param(
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)]$Field,
        [Parameter(Mandatory)][int]$Y
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = [string]$Field.label
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = $script:colors.Text
    $label.BackColor = $script:colors.Surface
    $label.Location = New-Point 18 $Y
    $label.Size = New-Size 220 22
    $fieldsPanel.Controls.Add($label)

    $fieldType = [string]$Field.type
    $savedValue = Get-SavedFieldValue -Tool $Tool -Field $Field
    $control = $null

    switch ($fieldType) {
        'number' {
            $control = New-Object System.Windows.Forms.NumericUpDown
            $control.Minimum = if ($null -ne $Field.minimum) { [decimal]$Field.minimum } else { 0 }
            $control.Maximum = if ($null -ne $Field.maximum) { [decimal]$Field.maximum } else { 999999 }
            $control.Value = [decimal]$savedValue
            $control.Location = New-Point 250 ($Y - 3)
            $control.Size = New-Size 120 26
            Set-ControlTheme -Control $control
        }

        'checkbox' {
            $control = New-Object System.Windows.Forms.CheckBox
            $control.Checked = [bool]$savedValue
            $control.Text = 'Enabled'
            $control.Location = New-Point 250 ($Y - 2)
            $control.Size = New-Size 130 26
            $control.BackColor = $script:colors.Surface
            $control.ForeColor = $script:colors.Text
        }

        'choice' {
            $control = New-Object System.Windows.Forms.ComboBox
            $control.DropDownStyle = 'DropDownList'
            foreach ($option in @($Field.options)) {
                $null = $control.Items.Add([string]$option)
            }
            if ($control.Items.Count -gt 0) {
                $selectedIndex = $control.Items.IndexOf([string]$savedValue)
                $control.SelectedIndex = if ($selectedIndex -ge 0) { $selectedIndex } else { 0 }
            }
            $control.Location = New-Point 250 ($Y - 3)
            $control.Size = New-Size 260 26
            Set-ControlTheme -Control $control
        }

        'password' {
            $control = New-Object System.Windows.Forms.TextBox
            $control.Text = [string]$savedValue
            $control.UseSystemPasswordChar = $true
            $control.Location = New-Point 250 ($Y - 3)
            $control.Size = New-Size 420 26
            $control.Anchor = 'Top, Left, Right'
            Set-TextBoxTheme -TextBox $control
        }

        default {
            $control = New-Object System.Windows.Forms.TextBox
            $control.Text = [string]$savedValue
            $control.Location = New-Point 250 ($Y - 3)
            $control.Size = New-Size 420 26
            $control.Anchor = 'Top, Left, Right'
            Set-TextBoxTheme -TextBox $control
        }
    }

    if ($Field.help) {
        $helpLabel = New-Object System.Windows.Forms.Label
        $helpLabel.Text = [string]$Field.help
        $helpLabel.ForeColor = $script:colors.Muted
        $helpLabel.BackColor = $script:colors.Surface
        $helpLabel.Location = New-Point 18 ($Y + 24)
        $helpLabel.Size = New-Size 650 18
        $helpLabel.Anchor = 'Top, Left, Right'
        $fieldsPanel.Controls.Add($helpLabel)
        $rowHeight = 58
    }
    else {
        $rowHeight = 42
    }

    $fieldsPanel.Controls.Add($control)
    $script:fieldControls[$Field.name] = @{
        Field = $Field
        Control = $control
    }

    return $Y + $rowHeight
}

function Render-Tool {
    param([Parameter(Mandatory)]$Tool)

    $script:currentTool = $Tool
    $script:fieldControls = @{}
    $fieldsPanel.Controls.Clear()

    $toolTitleLabel.Text = [string]$Tool.name
    $toolDescriptionLabel.Text = [string]$Tool.description

    $y = 18
    foreach ($field in @($Tool.fields)) {
        $y = Render-Field -Tool $Tool -Field $field -Y $y
    }

    if (@($Tool.fields).Count -eq 0) {
        $emptyLabel = New-Object System.Windows.Forms.Label
        $emptyLabel.Text = 'No configurable fields.'
        $emptyLabel.Location = New-Point 18 18
        $emptyLabel.Size = New-Size 300 22
        $emptyLabel.ForeColor = $script:colors.Muted
        $emptyLabel.BackColor = $script:colors.Surface
        $fieldsPanel.Controls.Add($emptyLabel)
    }

    Refresh-StatusForCurrentTool
    Refresh-LogView
}

function Load-ToolCatalog {
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
        Render-Tool -Tool $script:tools[0]
    }
    else {
        $script:currentTool = $null
        $fieldsPanel.Controls.Clear()
        Refresh-StatusForCurrentTool
    }
}

function Start-SelectedTool {
    if (-not $script:currentTool) {
        return
    }

    $run = Get-CurrentToolRun
    if (Test-ToolRunActive -Run $run) {
        return
    }

    $values = Get-CurrentFieldValues

    try {
        $run = Start-ConfiguredTool `
            -RootPath $script:rootPath `
            -LogsPath $script:logsPath `
            -Tool $script:currentTool `
            -FieldValues $values

        $script:toolRuns[$script:currentTool.id] = $run
        $script:lastRenderedLogPath = $null
        $script:lastRenderedLogText = ''
        $statusLabel.Text = 'Running {0}. Log: {1}' -f $script:currentTool.name, $run.LogPath
        Refresh-StatusForCurrentTool
        Refresh-LogView
    }
    catch {
        $statusLabel.Text = 'Run failed.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Run Failed', 'OK', 'Error') | Out-Null
    }
}

function Stop-SelectedTool {
    $run = Get-CurrentToolRun
    if (-not $run) {
        return
    }

    try {
        Stop-ToolRun -Run $run
        $statusLabel.Text = 'Stopped {0}.' -f $script:currentTool.name
    }
    catch {
        $statusLabel.Text = 'Stop failed.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Stop Failed', 'OK', 'Error') | Out-Null
    }
    finally {
        Refresh-StatusForCurrentTool
        Refresh-LogView
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
        $statusLabel.Text = 'Input send failed.'
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Input Send Failed', 'OK', 'Error') | Out-Null
    }
}

function Update-RunningTools {
    foreach ($toolId in @($script:toolRuns.Keys)) {
        $run = $script:toolRuns[$toolId]
        if ($run.Process -and $run.ExitCode -eq $null -and $run.Process.HasExited) {
            $run.ExitCode = $run.Process.ExitCode
            $run.EndedAt = Get-Date
        }
    }

    Refresh-StatusForCurrentTool
    Refresh-LogView
}

function Confirm-CloseRunningTools {
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
$form.MinimumSize = New-Size 980 640
$form.Size = New-Size 1120 740
$form.BackColor = $script:colors.Window
$form.ForeColor = $script:colors.Text

$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Location = New-Point 16 14
$topPanel.Size = New-Size 1070 80
$topPanel.Anchor = 'Top, Left, Right'
$topPanel.BackColor = $script:colors.Panel
$topPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($topPanel)

$appTitleLabel = New-Object System.Windows.Forms.Label
$appTitleLabel.Text = 'Troubleshooter Test Tools'
$appTitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$appTitleLabel.Location = New-Point 16 13
$appTitleLabel.Size = New-Size 360 30
$appTitleLabel.ForeColor = $script:colors.Text
$appTitleLabel.BackColor = $script:colors.Panel
$topPanel.Controls.Add($appTitleLabel)

$navPanel = New-Object System.Windows.Forms.Panel
$navPanel.Location = New-Point 16 108
$navPanel.Size = New-Size 260 552
$navPanel.Anchor = 'Top, Bottom, Left'
$navPanel.BackColor = $script:colors.Panel
$navPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($navPanel)

$navLabel = New-Object System.Windows.Forms.Label
$navLabel.Text = 'Tools'
$navLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$navLabel.Location = New-Point 14 14
$navLabel.Size = New-Size 200 24
$navLabel.BackColor = $script:colors.Panel
$navLabel.ForeColor = $script:colors.Text
$navPanel.Controls.Add($navLabel)

$toolList = New-Object System.Windows.Forms.ListBox
$toolList.Location = New-Point 14 48
$toolList.Size = New-Size 230 486
$toolList.Anchor = 'Top, Bottom, Left, Right'
$toolList.BackColor = $script:colors.Control
$toolList.ForeColor = $script:colors.Text
$toolList.BorderStyle = 'FixedSingle'
$toolList.Font = New-Object System.Drawing.Font('Segoe UI', 10)
$toolList.Add_SelectedIndexChanged({
    if ($toolList.SelectedIndex -lt 0 -or $toolList.SelectedIndex -ge $script:tools.Count) {
        return
    }

    Save-CurrentFieldValues
    Render-Tool -Tool $script:tools[$toolList.SelectedIndex]
})
$navPanel.Controls.Add($toolList)

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Point 292 108
$contentPanel.Size = New-Size 794 552
$contentPanel.Anchor = 'Top, Bottom, Left, Right'
$contentPanel.BackColor = $script:colors.Panel
$contentPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($contentPanel)

$toolTitleLabel = New-Object System.Windows.Forms.Label
$toolTitleLabel.Text = 'Tool'
$toolTitleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$toolTitleLabel.Location = New-Point 18 16
$toolTitleLabel.Size = New-Size 460 34
$toolTitleLabel.Anchor = 'Top, Left, Right'
$toolTitleLabel.ForeColor = $script:colors.Text
$toolTitleLabel.BackColor = $script:colors.Panel
$contentPanel.Controls.Add($toolTitleLabel)

$runStateLabel = New-Object System.Windows.Forms.Label
$runStateLabel.Text = 'Idle'
$runStateLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$runStateLabel.TextAlign = 'MiddleRight'
$runStateLabel.Location = New-Point 580 21
$runStateLabel.Size = New-Size 190 24
$runStateLabel.Anchor = 'Top, Right'
$runStateLabel.ForeColor = $script:colors.Muted
$runStateLabel.BackColor = $script:colors.Panel
$contentPanel.Controls.Add($runStateLabel)

$toolDescriptionLabel = New-Object System.Windows.Forms.Label
$toolDescriptionLabel.Text = ''
$toolDescriptionLabel.Location = New-Point 20 52
$toolDescriptionLabel.Size = New-Size 750 38
$toolDescriptionLabel.Anchor = 'Top, Left, Right'
$toolDescriptionLabel.ForeColor = $script:colors.Muted
$toolDescriptionLabel.BackColor = $script:colors.Panel
$contentPanel.Controls.Add($toolDescriptionLabel)

$fieldsPanel = New-Object System.Windows.Forms.Panel
$fieldsPanel.Location = New-Point 18 104
$fieldsPanel.Size = New-Size 754 176
$fieldsPanel.Anchor = 'Top, Left, Right'
$fieldsPanel.BackColor = $script:colors.Surface
$fieldsPanel.BorderStyle = 'FixedSingle'
$fieldsPanel.AutoScroll = $true
$contentPanel.Controls.Add($fieldsPanel)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = 'Run'
$startButton.Location = New-Point 18 296
$startButton.Size = New-Size 96 34
$startButton.Add_Click({ Start-SelectedTool })
Set-ButtonTheme -Button $startButton -Primary
$contentPanel.Controls.Add($startButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = 'Stop'
$stopButton.Location = New-Point 126 296
$stopButton.Size = New-Size 96 34
$stopButton.Add_Click({ Stop-SelectedTool })
Set-ButtonTheme -Button $stopButton
$contentPanel.Controls.Add($stopButton)

$openLogsButton = New-Object System.Windows.Forms.Button
$openLogsButton.Text = 'Open Logs'
$openLogsButton.Location = New-Point 234 296
$openLogsButton.Size = New-Size 106 34
$openLogsButton.Add_Click({
    if (-not (Test-Path -LiteralPath $script:logsPath)) {
        $null = New-Item -ItemType Directory -Path $script:logsPath -Force
    }
    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $script:logsPath)
})
Set-ButtonTheme -Button $openLogsButton
$contentPanel.Controls.Add($openLogsButton)

$clearLogButton = New-Object System.Windows.Forms.Button
$clearLogButton.Text = 'Clear View'
$clearLogButton.Location = New-Point 352 296
$clearLogButton.Size = New-Size 100 34
$clearLogButton.Add_Click({
    $run = Get-CurrentToolRun
    if ($run -and -not [string]::IsNullOrWhiteSpace($run.LogPath)) {
        $currentText = Read-SharedTextFile -Path $run.LogPath
        $script:logClearOffsets[$run.LogPath] = $currentText.Length
    }

    $script:lastRenderedLogText = ''
    $logBox.Clear()
})
Set-ButtonTheme -Button $clearLogButton
$contentPanel.Controls.Add($clearLogButton)

$logLabel = New-Object System.Windows.Forms.Label
$logLabel.Text = 'Console Output'
$logLabel.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$logLabel.Location = New-Point 18 348
$logLabel.Size = New-Size 120 24
$logLabel.ForeColor = $script:colors.Text
$logLabel.BackColor = $script:colors.Panel
$contentPanel.Controls.Add($logLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Point 18 376
$logBox.Size = New-Size 754 112
$logBox.Anchor = 'Top, Bottom, Left, Right'
$logBox.Multiline = $true
$logBox.ScrollBars = 'Both'
$logBox.WordWrap = $false
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
Set-TextBoxTheme -TextBox $logBox
$contentPanel.Controls.Add($logBox)

$consoleInputLabel = New-Object System.Windows.Forms.Label
$consoleInputLabel.Text = 'Input'
$consoleInputLabel.Location = New-Point 18 511
$consoleInputLabel.Size = New-Size 48 22
$consoleInputLabel.Anchor = 'Bottom, Left'
$consoleInputLabel.ForeColor = $script:colors.Text
$consoleInputLabel.BackColor = $script:colors.Panel
$consoleInputLabel.Visible = $false
$contentPanel.Controls.Add($consoleInputLabel)

$consoleInputBox = New-Object System.Windows.Forms.TextBox
$consoleInputBox.Location = New-Point 76 506
$consoleInputBox.Size = New-Size 578 26
$consoleInputBox.Anchor = 'Bottom, Left, Right'
$consoleInputBox.Enabled = $false
$consoleInputBox.Visible = $false
$consoleInputBox.Add_KeyDown({
    param($sender, $eventArgs)

    if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
        $eventArgs.SuppressKeyPress = $true
        Send-ConsoleInput
    }
})
Set-TextBoxTheme -TextBox $consoleInputBox
$contentPanel.Controls.Add($consoleInputBox)

$sendInputButton = New-Object System.Windows.Forms.Button
$sendInputButton.Text = 'Send'
$sendInputButton.Location = New-Point 666 503
$sendInputButton.Size = New-Size 106 32
$sendInputButton.Anchor = 'Bottom, Right'
$sendInputButton.Enabled = $false
$sendInputButton.Visible = $false
$sendInputButton.Add_Click({ Send-ConsoleInput })
Set-ButtonTheme -Button $sendInputButton -Primary
$contentPanel.Controls.Add($sendInputButton)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = 'Ready.'
$statusLabel.Location = New-Point 18 674
$statusLabel.Size = New-Size 1068 24
$statusLabel.Anchor = 'Bottom, Left, Right'
$statusLabel.ForeColor = $script:colors.Muted
$statusLabel.BackColor = $script:colors.Window
$form.Controls.Add($statusLabel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-RunningTools })
$timer.Start()

$form.Add_FormClosing({
    param($sender, $eventArgs)

    if (-not (Confirm-CloseRunningTools)) {
        $eventArgs.Cancel = $true
    }
})

Load-ToolCatalog

[void][System.Windows.Forms.Application]::Run($form)
