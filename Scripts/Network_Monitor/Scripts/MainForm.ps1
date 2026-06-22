$script:NMWindowTitle = 'Network Monitor - Troubleshooter Test Tools'

function Test-NMRectangleVisible {
    param([Parameter(Mandatory)][System.Drawing.Rectangle]$Rectangle)

    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        if ($screen.WorkingArea.IntersectsWith($Rectangle)) {
            return $true
        }
    }

    return $false
}

function Get-NMDefaultWindowLocation {
    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    return Get-NMPoint $workingArea.Left ($workingArea.Bottom - $script:NMForm.Height)
}

function Set-NMDefaultWindowLocation {
    if (-not $script:NMForm) {
        return
    }

    $script:NMForm.Location = Get-NMDefaultWindowLocation
}

function Apply-NMInitialWindowPlacement {
    $width = [math]::Max([int]$script:NMConfig.Window.Width, $script:NMForm.MinimumSize.Width)
    $height = [math]::Max([int]$script:NMConfig.Window.Height, $script:NMForm.MinimumSize.Height)
    $script:NMForm.Size = Get-NMSize $width $height

    $hasPosition = ($null -ne $script:NMConfig.Window.X -and $null -ne $script:NMConfig.Window.Y)
    if ($hasPosition) {
        $candidate = Get-NMRectangle ([int]$script:NMConfig.Window.X) ([int]$script:NMConfig.Window.Y) $width $height
        if (Test-NMRectangleVisible -Rectangle $candidate) {
            $script:NMForm.Location = Get-NMPoint $candidate.X $candidate.Y
        }
        else {
            Set-NMDefaultWindowLocation
        }
    }
    else {
        Set-NMDefaultWindowLocation
    }

    if ($script:NMConfig.Window.Maximized) {
        $script:NMForm.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    }
}

function Save-NMWindowPlacement {
    if (-not $script:NMForm) {
        return
    }

    $script:NMConfig.Window.Maximized = ($script:NMForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized)
    $bounds = if ($script:NMForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
        $script:NMForm.Bounds
    }
    else {
        $script:NMForm.RestoreBounds
    }

    if ($bounds.Width -ge $script:NMForm.MinimumSize.Width -and $bounds.Height -ge $script:NMForm.MinimumSize.Height) {
        $script:NMConfig.Window.Width = [int]$bounds.Width
        $script:NMConfig.Window.Height = [int]$bounds.Height
        $script:NMConfig.Window.X = [int]$bounds.X
        $script:NMConfig.Window.Y = [int]$bounds.Y
    }
}

function Apply-NMAlwaysOnTopState {
    if ($script:NMForm) {
        $script:NMForm.TopMost = [bool]$script:NMConfig.AlwaysOnTop
    }
    if ($script:NMSettingsForm -and -not $script:NMSettingsForm.IsDisposed) {
        $script:NMSettingsForm.TopMost = [bool]$script:NMConfig.AlwaysOnTop
    }
    if ($script:NMPinButton) {
        Set-NMIconButtonActive -Button $script:NMPinButton -Active ([bool]$script:NMConfig.AlwaysOnTop)
    }
}

function Invoke-NMMinimize {
    $script:NMForm.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
}

function Invoke-NMToggleMaximize {
    if ($script:NMForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
        $script:NMForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    }
    else {
        $script:NMForm.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    }
}

function Invoke-NMTogglePin {
    $script:NMConfig.AlwaysOnTop = -not [bool]$script:NMConfig.AlwaysOnTop
    Apply-NMAlwaysOnTopState
    Save-NMCurrentConfig
}

function Invoke-NMResetAndRefresh {
    $script:NMGeneration++
    Reset-NMMonitorState
    Render-NMGrid
    Start-NMMonitoring
    Invoke-NMPingCycle
}

function Get-NMCellText {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ColumnId
    )

    switch ($ColumnId) {
        'Node' { return [string]$Target.Name }
        'Address' { return [string]$Target.Address }
        'Status' { return (Get-NMStatusText -State $State) }
        'RTT' { return (Get-NMRttText -State $State) }
        'Loss' { return (Get-NMLossText -State $State) }
        'TTL' { if ($State.LatestSuccess -and $null -ne $State.LatestTtl) { return [string]$State.LatestTtl }; return (Get-NMNeutralValue) }
        'Bytes' { if ($State.LatestSuccess -and $null -ne $State.LatestBytes) { return [string]$State.LatestBytes }; return (Get-NMNeutralValue) }
        default { return '' }
    }
}

function Apply-NMColumnsToGrid {
    if (-not $script:NMGrid) {
        return
    }

    $script:NMSuppressColumnEvents = $true
    try {
        $script:NMGrid.Columns.Clear()
        foreach ($columnConfig in @($script:NMConfig.Columns)) {
            $id = [string]$columnConfig.Id
            $definition = $script:NMColumnDefinitions[$id]
            if (-not $definition) {
                continue
            }

            $column = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
            $column.Name = $id
            $column.HeaderText = [string]$definition.Header
            $column.Width = [int]$columnConfig.Width
            $column.MinimumWidth = [int]$definition.MinWidth
            $column.Visible = [bool]$columnConfig.Visible
            $column.SortMode = [System.Windows.Forms.DataGridViewColumnSortMode]::NotSortable
            [void]$script:NMGrid.Columns.Add($column)
        }
    }
    finally {
        $script:NMSuppressColumnEvents = $false
    }

    Render-NMGrid
}

function Update-NMConfigFromGridColumns {
    if ($script:NMSuppressColumnEvents -or -not $script:NMGrid -or $script:NMGrid.Columns.Count -lt 1) {
        return
    }

    $ordered = @($script:NMGrid.Columns | Sort-Object DisplayIndex)
    $newColumns = @()
    foreach ($gridColumn in $ordered) {
        $configColumn = Get-NMConfigColumn -Id ([string]$gridColumn.Name)
        if ($configColumn) {
            $configColumn.Width = [int]$gridColumn.Width
            $configColumn.Visible = [bool]$gridColumn.Visible
            $newColumns += $configColumn
        }
    }
    $script:NMConfig.Columns = @($newColumns)

    try {
        Save-NMCurrentConfig
    }
    catch {
        Write-NMDebugLog -Message ("Column persistence failed: {0}" -f $_.Exception.Message)
    }
}

function Render-NMGrid {
    if (-not $script:NMGrid) {
        return
    }

    $script:NMGrid.Rows.Clear()
    foreach ($target in Get-NMEnabledTargets) {
        $name = [string]$target.Name
        if (-not $script:NMTargetStates.ContainsKey($name)) {
            $script:NMTargetStates[$name] = New-NMTargetState
        }

        $state = $script:NMTargetStates[$name]
        $values = @()
        foreach ($column in @($script:NMGrid.Columns)) {
            $values += (Get-NMCellText -State $state -Target $target -ColumnId ([string]$column.Name))
        }
        $rowIndex = $script:NMGrid.Rows.Add($values)
        $script:NMGrid.Rows[$rowIndex].Tag = $name
        $script:NMGrid.Rows[$rowIndex].Height = 70
    }

    $script:NMGrid.ClearSelection()
    $script:NMGrid.CurrentCell = $null
}

function Draw-NMGridText {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][System.Drawing.Color]$Color,
        [System.Drawing.Font]$Font = $script:NMFonts.Grid
    )

    $rect = Get-NMRectangle ($Bounds.X + 16) $Bounds.Y ([math]::Max(1, $Bounds.Width - 22)) $Bounds.Height
    [System.Windows.Forms.TextRenderer]::DrawText(
        $Graphics,
        $Text,
        $Font,
        $rect,
        $Color,
        ([System.Windows.Forms.TextFormatFlags]::Left -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis)
    )
}

function Draw-NMGridBorder {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds
    )

    $pen = [System.Drawing.Pen]::new($script:NMColors.GridLine, 1)
    try {
        $Graphics.DrawRectangle($pen, $Bounds.X, $Bounds.Y, $Bounds.Width - 1, $Bounds.Height - 1)
    }
    finally {
        $pen.Dispose()
    }
}

function Draw-NMStatusCell {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)][hashtable]$State
    )

    $healthColor = Get-NMThemeColor -Name (Get-NMHealthName -State $State)
    $brush = [System.Drawing.SolidBrush]::new($healthColor)
    try {
        $dotSize = 22
        $dotX = $Bounds.X + 26
        $dotY = $Bounds.Y + [int](($Bounds.Height - $dotSize) / 2)
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $Graphics.FillEllipse($brush, $dotX, $dotY, $dotSize, $dotSize)
        $textBounds = Get-NMRectangle ($Bounds.X + 64) $Bounds.Y ([math]::Max(1, $Bounds.Width - 70)) $Bounds.Height
        [System.Windows.Forms.TextRenderer]::DrawText(
            $Graphics,
            (Get-NMStatusText -State $State),
            $script:NMFonts.GridBold,
            $textBounds,
            $healthColor,
            ([System.Windows.Forms.TextFormatFlags]::Left -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter)
        )
    }
    finally {
        $brush.Dispose()
    }
}

function Draw-NMHistoryCell {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)][hashtable]$State
    )

    $length = [int]$script:NMConfig.HistoryLength
    $samples = @($State.History)
    $display = @()
    for ($i = 0; $i -lt ($length - $samples.Count); $i++) {
        $display += $null
    }
    $display += $samples

    $left = $Bounds.X + 16
    $available = [math]::Max(1, $Bounds.Width - 32)
    $slot = $available / [math]::Max(1, $length)
    $barWidth = [math]::Max(3, [math]::Min(7, [int]($slot * 0.38)))
    $barHeight = 28
    $top = $Bounds.Y + [int](($Bounds.Height - $barHeight) / 2)

    for ($i = 0; $i -lt $length; $i++) {
        $sample = $display[$i]
        $color = if ($null -eq $sample) {
            $script:NMColors.Yellow
        }
        elseif ([bool]$sample) {
            $script:NMColors.Green
        }
        else {
            $script:NMColors.Red
        }

        $brush = [System.Drawing.SolidBrush]::new($color)
        try {
            $x = $left + [int]($i * $slot + (($slot - $barWidth) / 2))
            $Graphics.FillRectangle($brush, $x, $top, $barWidth, $barHeight)
        }
        finally {
            $brush.Dispose()
        }
    }
}

function Initialize-NMGrid {
    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grid.BackgroundColor = $script:NMColors.Grid
    $grid.BackColor = $script:NMColors.Grid
    $grid.ForeColor = $script:NMColors.Text
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $grid.GridColor = $script:NMColors.GridLine
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.AllowUserToOrderColumns = $true
    $grid.AllowUserToResizeColumns = $true
    $grid.ReadOnly = $true
    $grid.MultiSelect = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.ColumnHeadersHeight = 58
    $grid.DefaultCellStyle.BackColor = $script:NMColors.Grid
    $grid.DefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.DefaultCellStyle.SelectionBackColor = $script:NMColors.Grid
    $grid.DefaultCellStyle.SelectionForeColor = $script:NMColors.Text
    $grid.DefaultCellStyle.Font = $script:NMFonts.Grid
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:NMColors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = $script:NMFonts.GridHeader
    $grid.ColumnHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft

    $grid.Add_CellPainting({
        param($sender, $eventArgs)

        if ($eventArgs.RowIndex -lt 0) {
            return
        }

        $columnId = [string]$sender.Columns[$eventArgs.ColumnIndex].Name
        $name = [string]$sender.Rows[$eventArgs.RowIndex].Tag
        if ([string]::IsNullOrWhiteSpace($name) -or -not $script:NMTargetStates.ContainsKey($name)) {
            return
        }

        $target = Get-NMTargetByName -Name $name
        if (-not $target) {
            return
        }

        $state = $script:NMTargetStates[$name]
        $background = if ($eventArgs.RowIndex % 2 -eq 0) { $script:NMColors.Grid } else { $script:NMColors.GridAlt }
        $eventArgs.Graphics.Clear($background)

        switch ($columnId) {
            'Node' {
                Draw-NMGridText -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -Text ([string]$target.Name) -Color (ConvertTo-NMDrawingColor -HtmlColor ([string]$target.Color)) -Font $script:NMFonts.GridBold
                $eventArgs.Handled = $true
            }
            'Status' {
                Draw-NMStatusCell -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -State $state
                $eventArgs.Handled = $true
            }
            'RTT' {
                Draw-NMGridText -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -Text (Get-NMRttText -State $state) -Color (Get-NMThemeColor -Name (Get-NMRttHealthName -State $state))
                $eventArgs.Handled = $true
            }
            'Loss' {
                Draw-NMGridText -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -Text (Get-NMLossText -State $state) -Color (Get-NMThemeColor -Name (Get-NMLossHealthName -State $state))
                $eventArgs.Handled = $true
            }
            'History' {
                Draw-NMHistoryCell -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -State $state
                $eventArgs.Handled = $true
            }
            default {
                Draw-NMGridText -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -Text ([string]$eventArgs.FormattedValue) -Color $script:NMColors.Text
                $eventArgs.Handled = $true
            }
        }

        Draw-NMGridBorder -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds
    })

    $grid.Add_ColumnWidthChanged({
        Update-NMConfigFromGridColumns
    })
    $grid.Add_ColumnDisplayIndexChanged({
        Update-NMConfigFromGridColumns
    })

    $script:NMGrid = $grid
    Apply-NMColumnsToGrid
    return $grid
}

function Initialize-NMTitleBar {
    $titleBar = [System.Windows.Forms.Panel]::new()
    $titleBar.Dock = [System.Windows.Forms.DockStyle]::Top
    $titleBar.Height = 66
    $titleBar.BackColor = $script:NMColors.TitleBar
    Enable-NMTitleDrag -Control $titleBar -Form $script:NMForm

    $icon = [System.Windows.Forms.Panel]::new()
    $icon.Location = Get-NMPoint 18 13
    $icon.Size = Get-NMSize 44 40
    $icon.BackColor = $script:NMColors.TitleBar
    $icon.Add_Paint({
        param($sender, $eventArgs)
        Draw-NMIcon -Kind 'Monitor' -Graphics $eventArgs.Graphics -Bounds $sender.ClientRectangle -Color $script:NMColors.Text
    })
    Enable-NMTitleDrag -Control $icon -Form $script:NMForm
    $titleBar.Controls.Add($icon)

    $titleLabel = [System.Windows.Forms.Label]::new()
    $titleLabel.Text = $script:NMWindowTitle
    $titleLabel.AutoSize = $false
    $titleLabel.Location = Get-NMPoint 78 13
    $titleLabel.Size = Get-NMSize 560 40
    $titleLabel.Anchor = 'Top, Left, Right'
    $titleLabel.BackColor = $script:NMColors.TitleBar
    $titleLabel.ForeColor = $script:NMColors.Text
    $titleLabel.Font = $script:NMFonts.Title
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    Enable-NMTitleDrag -Control $titleLabel -Form $script:NMForm
    $titleBar.Controls.Add($titleLabel)

    $buttonPanel = [System.Windows.Forms.Panel]::new()
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Right
    $buttonPanel.Width = 342
    $buttonPanel.BackColor = $script:NMColors.TitleBar
    $titleBar.Controls.Add($buttonPanel)

    $script:NMSettingsButton = New-NMIconButton -Parent $buttonPanel -Kind 'Settings' -ToolTipText 'Settings' -Bounds @(0, 10, 46, 46) -OnClick { Show-NMSettingsForm }
    $script:NMRefreshButton = New-NMIconButton -Parent $buttonPanel -Kind 'Refresh' -ToolTipText 'Reset monitor data' -Bounds @(48, 10, 46, 46) -OnClick { Invoke-NMResetAndRefresh }
    $script:NMPinButton = New-NMIconButton -Parent $buttonPanel -Kind 'Pin' -ToolTipText 'Always on top' -Bounds @(96, 10, 46, 46) -OnClick { Invoke-NMTogglePin }

    $separator = [System.Windows.Forms.Panel]::new()
    $separator.Location = Get-NMPoint 154 10
    $separator.Size = Get-NMSize 1 46
    $separator.BackColor = $script:NMColors.GridLine
    $buttonPanel.Controls.Add($separator)

    $script:NMMinimizeButton = New-NMIconButton -Parent $buttonPanel -Kind 'Minimize' -ToolTipText 'Minimize' -Bounds @(176, 10, 46, 46) -OnClick { Invoke-NMMinimize }
    $script:NMMaximizeButton = New-NMIconButton -Parent $buttonPanel -Kind 'Maximize' -ToolTipText 'Maximize or restore' -Bounds @(224, 10, 46, 46) -OnClick { Invoke-NMToggleMaximize }
    $script:NMCloseButton = New-NMIconButton -Parent $buttonPanel -Kind 'Close' -ToolTipText 'Close' -Bounds @(276, 10, 46, 46) -OnClick { $script:NMForm.Close() }

    Set-NMIconButtonActive -Button $script:NMPinButton -Active ([bool]$script:NMConfig.AlwaysOnTop)
    return $titleBar
}

function Invoke-NMConfigChanged {
    param(
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

    try {
        Save-NMCurrentConfig
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $script:NMForm,
            $_.Exception.Message,
            'Settings Rejected',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Set-NMSettingsFeedback -Message $_.Exception.Message -Error
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        Write-NMDebugLog -Message $Reason
    }

    if ($ResetMonitor) {
        $script:NMGeneration++
        Reset-NMMonitorState
    }

    Update-NMPingTimerInterval
    Apply-NMAlwaysOnTopState

    if ($RebuildGrid) {
        Apply-NMColumnsToGrid
    }
    else {
        Render-NMGrid
    }

    if ($ResetMonitor -and $script:NMPingTimer -and $script:NMPingTimer.Enabled) {
        Invoke-NMPingCycle
    }

    return $true
}

function Invoke-NMOnPingResults {
    param([AllowNull()]$Results)

    Update-NMStateFromPingResults -Results $Results
    Render-NMGrid
}

function Build-NMMainForm {
    $form = [NetworkMonitorForm]::new()
    $form.Text = $script:NMWindowTitle
    $form.Name = 'NetworkMonitorMainForm'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $true
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.MinimumSize = Get-NMSize 820 260
    $form.BackColor = $script:NMColors.Window
    $form.ForeColor = $script:NMColors.Text
    $form.Font = $script:NMFonts.Grid
    $form.TopMost = [bool]$script:NMConfig.AlwaysOnTop
    $form.KeyPreview = $true
    $script:NMForm = $form

    Apply-NMInitialWindowPlacement

    $form.Add_Paint({
        param($sender, $eventArgs)
        [void]$sender
        $pen = [System.Drawing.Pen]::new($script:NMColors.Border, 1)
        try {
            $eventArgs.Graphics.DrawRectangle($pen, 0, 0, $script:NMForm.ClientSize.Width - 1, $script:NMForm.ClientSize.Height - 1)
        }
        finally {
            $pen.Dispose()
        }
    })

    $titleBar = Initialize-NMTitleBar
    $grid = Initialize-NMGrid
    $form.Controls.Add($grid)
    $form.Controls.Add($titleBar)

    $form.Add_SizeChanged({
        if ($script:NMMaximizeButton) {
            $kind = if ($script:NMForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) { 'Restore' } else { 'Maximize' }
            Set-NMIconButtonKind -Button $script:NMMaximizeButton -Kind $kind
        }
        $script:NMForm.Invalidate()
    })

    $form.Add_FormClosing({
        Stop-NMMonitoring
        Save-NMWindowPlacement
        try {
            Save-NMCurrentConfig
        }
        catch {
            Write-NMDebugLog -Message ("Unable to save config on close: {0}" -f $_.Exception.Message)
        }
    })

    return $form
}

function Start-NetworkMonitorApp {
    param([Parameter(Mandatory)][string]$AppRoot)

    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

    Initialize-NMTheme
    $script:NMAppRoot = $AppRoot
    $script:NMConfig = Initialize-NMConfig -AppRoot $AppRoot
    $script:NMGeneration = 1
    Initialize-NMMonitorState

    $form = Build-NMMainForm
    Initialize-NMPingEngine

    if ($script:NMConfig.AutoStart) {
        Start-NMMonitoring
        Invoke-NMPingCycle
    }

    [void][System.Windows.Forms.Application]::Run($form)
}
