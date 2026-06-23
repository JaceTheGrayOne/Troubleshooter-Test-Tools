$script:NMWindowTitle = 'Network Monitor - Troubleshooter Test Tools'
$script:NMTitleBarHeight = 46
$script:NMGridHeaderHeight = 38
$script:NMGridRowHeight = 52

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

function Get-NMCalculatedDefaultWindowSize {
    $visibleWidth = 0
    foreach ($column in @($script:NMConfig.Columns)) {
        if ($column.Visible) {
            $visibleWidth += [int]$column.Width
        }
    }

    $enabledCount = [math]::Max(1, @(Get-NMEnabledTargets).Count)
    $width = [math]::Max($script:NMForm.MinimumSize.Width, $visibleWidth + 28)
    $height = [math]::Max(
        $script:NMForm.MinimumSize.Height,
        $script:NMTitleBarHeight + $script:NMGridHeaderHeight + ($enabledCount * $script:NMGridRowHeight) + 18
    )

    return Get-NMSize $width $height
}

function Apply-NMInitialWindowPlacement {
    $defaultSize = Get-NMCalculatedDefaultWindowSize
    $width = [math]::Max([int]$script:NMConfig.Window.Width, $defaultSize.Width)
    $height = [math]::Max([int]$script:NMConfig.Window.Height, $defaultSize.Height)
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

function Show-NMConfigError {
    param([Parameter(Mandatory)][string]$Message)

    if ($script:NMForm) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:NMForm,
            $Message,
            'Settings Rejected',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }

    Set-NMSettingsFeedback -Message $Message -Error
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
    if ($script:NMForm) {
        Invoke-NMFormMaximizeToggle -Form $script:NMForm
    }
}

function Invoke-NMTogglePin {
    if (Invoke-NMConfigEditAndApply -Edit {
        param($config)
        $config.AlwaysOnTop = -not [bool]$config.AlwaysOnTop
    } -Reason 'Always-on-top changed') {
        Apply-NMAlwaysOnTopState
    }
}

function Invoke-NMResetAndRefresh {
    $script:NMGeneration++
    Reset-NMMonitorState
    Update-NMGridFromState
    Start-NMMonitoring
    Invoke-NMPingCycle
}

function Get-NMCellText {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ColumnId
    )

    return (Get-NMColumnPresentation -State $State -Target $Target -ColumnId $ColumnId).Text
}

function Rebuild-NMGridColumns {
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
            $column.DefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
            $column.DefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new(14, 0, 6, 0)
            [void]$script:NMGrid.Columns.Add($column)
        }
    }
    finally {
        $script:NMSuppressColumnEvents = $false
    }
}

function Get-NMColumnsFromGrid {
    $columns = @()
    foreach ($gridColumn in @($script:NMGrid.Columns | Sort-Object DisplayIndex)) {
        $definition = $script:NMColumnDefinitions[[string]$gridColumn.Name]
        if (-not $definition) {
            continue
        }

        $width = [math]::Max([int]$gridColumn.Width, [int]$definition.MinWidth)
        $columns += [ordered]@{
            Id = [string]$gridColumn.Name
            Visible = [bool]$gridColumn.Visible
            Width = [int]$width
        }
    }

    return @($columns)
}

function Update-NMConfigFromGridColumns {
    if ($script:NMSuppressColumnEvents -or -not $script:NMGrid -or $script:NMGrid.Columns.Count -lt 1) {
        return
    }

    $columns = @(Get-NMColumnsFromGrid)
    try {
        [void](Invoke-NMConfigEdit -Edit {
            param($config)
            $config.Columns = @($columns)
        })
    }
    catch {
        Write-NMDebugLog -Message ("Column persistence failed: {0}" -f $_.Exception.Message)
    }
}

function Save-NMGridColumnLayoutIfDirty {
    if (-not $script:NMColumnLayoutDirty) {
        return
    }

    $script:NMColumnLayoutDirty = $false
    Update-NMConfigFromGridColumns
}

function Schedule-NMGridColumnPersistence {
    if ($script:NMSuppressColumnEvents -or -not $script:NMColumnPersistTimer) {
        return
    }

    $script:NMColumnLayoutDirty = $true
    $script:NMColumnPersistTimer.Stop()
    $script:NMColumnPersistTimer.Start()
}

function Apply-NMColumnsToGrid {
    Rebuild-NMGridColumns
    Rebuild-NMGridRows
}

function Test-NMGridRowsCurrent {
    if (-not $script:NMGrid -or -not $script:NMRowsByTarget) {
        return $false
    }

    $targets = @(Get-NMEnabledTargets)
    if ($script:NMGrid.Rows.Count -ne $targets.Count) {
        return $false
    }

    for ($i = 0; $i -lt $targets.Count; $i++) {
        if ([string]$script:NMGrid.Rows[$i].Tag -ne [string]$targets[$i].Name) {
            return $false
        }
    }

    return $true
}

function Set-NMGridCellPresentation {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.DataGridViewRow]$Row,
        [Parameter(Mandatory)][string]$ColumnId,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][hashtable]$State
    )

    if (-not $script:NMGrid -or -not $script:NMGrid.Columns.Contains($ColumnId)) {
        return $null
    }

    $presentation = Get-NMColumnPresentation -State $State -Target $Target -ColumnId $ColumnId
    $cell = $Row.Cells[$ColumnId]
    $cell.Value = $presentation.Text
    $cell.Style.ForeColor = $presentation.ForeColor
    $cell.Style.SelectionForeColor = $presentation.ForeColor
    $cell.Style.Font = $presentation.Font
    $cell.Style.Alignment = $presentation.Align
    return $presentation
}

function Rebuild-NMGridRows {
    if (-not $script:NMGrid) {
        return
    }

    $script:NMRowsByTarget = @{}
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
        $row = $script:NMGrid.Rows[$rowIndex]
        $row.Tag = $name
        $row.Height = $script:NMGridRowHeight
        $row.DefaultCellStyle.BackColor = if ($rowIndex % 2 -eq 0) { $script:NMColors.Grid } else { $script:NMColors.GridAlt }
        $row.DefaultCellStyle.SelectionBackColor = $row.DefaultCellStyle.BackColor
        $row.DefaultCellStyle.SelectionForeColor = $script:NMColors.Text
        foreach ($column in @($script:NMGrid.Columns)) {
            [void](Set-NMGridCellPresentation -Row $row -ColumnId ([string]$column.Name) -Target $target -State $state)
        }
        $script:NMRowsByTarget[$name] = $row
    }

    $script:NMGrid.ClearSelection()
    $script:NMGrid.CurrentCell = $null
}

function Update-NMGridRow {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][hashtable]$State
    )

    if (-not $script:NMGrid -or -not $script:NMRowsByTarget) {
        return
    }

    $name = [string]$Target.Name
    if (-not $script:NMRowsByTarget.ContainsKey($name)) {
        return
    }

    $row = $script:NMRowsByTarget[$name]
    if ($row.Index -lt 0) {
        return
    }

    foreach ($column in @($script:NMGrid.Columns)) {
        $columnId = [string]$column.Name
        $presentation = Set-NMGridCellPresentation -Row $row -ColumnId $columnId -Target $Target -State $State
        if ($presentation.PaintKind -ne 'Text') {
            $script:NMGrid.InvalidateCell($row.Cells[$columnId])
        }
    }
}

function Update-NMGridFromState {
    if (-not $script:NMGrid) {
        return
    }

    if (-not (Test-NMGridRowsCurrent)) {
        Rebuild-NMGridRows
    }

    foreach ($target in Get-NMEnabledTargets) {
        $name = [string]$target.Name
        if (-not $script:NMTargetStates.ContainsKey($name)) {
            $script:NMTargetStates[$name] = New-NMTargetState
        }

        Update-NMGridRow -Target $target -State $script:NMTargetStates[$name]
    }

    $script:NMGrid.Invalidate()
}

function Render-NMGrid {
    Update-NMGridFromState
}

function Draw-NMGridCellBorder {
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

function Fill-NMGridCellBackground {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)][int]$RowIndex
    )

    $background = if ($RowIndex % 2 -eq 0) { $script:NMColors.Grid } else { $script:NMColors.GridAlt }
    $brush = [System.Drawing.SolidBrush]::new($background)
    try {
        $Graphics.FillRectangle($brush, $Bounds)
    }
    finally {
        $brush.Dispose()
    }
}

function Draw-NMStatusCell {
    param(
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)]$Presentation
    )

    $brush = [System.Drawing.SolidBrush]::new($Presentation.ForeColor)
    try {
        $dotSize = 16
        $dotX = $Bounds.X + 18
        $dotY = $Bounds.Y + [int](($Bounds.Height - $dotSize) / 2)
        $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $Graphics.FillEllipse($brush, $dotX, $dotY, $dotSize, $dotSize)

        $textBounds = Get-NMRectangle ($dotX + $dotSize + 12) $Bounds.Y ([math]::Max(1, $Bounds.Right - ($dotX + $dotSize + 16))) $Bounds.Height
        [System.Windows.Forms.TextRenderer]::DrawText(
            $Graphics,
            ([string]$Presentation.Text),
            $Presentation.Font,
            $textBounds,
            $Presentation.ForeColor,
            ([System.Windows.Forms.TextFormatFlags]::Left -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix)
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

    $left = $Bounds.X + 12
    $available = [math]::Max(1, $Bounds.Width - 24)
    $slot = $available / [math]::Max(1, $length)
    $barWidth = [math]::Max(3, [math]::Min(6, [int]($slot * 0.42)))
    $barHeight = [math]::Min(24, [math]::Max(16, $Bounds.Height - 24))
    $top = $Bounds.Y + [int](($Bounds.Height - $barHeight) / 2)

    for ($i = 0; $i -lt $length; $i++) {
        $sample = $display[$i]
        $color = Get-NMHistorySampleColor -Sample $sample

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
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::CellSelect
    $grid.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.ColumnHeadersHeight = $script:NMGridHeaderHeight
    $grid.RowTemplate.Height = $script:NMGridRowHeight
    $grid.DefaultCellStyle.BackColor = $script:NMColors.Grid
    $grid.DefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.DefaultCellStyle.SelectionBackColor = $script:NMColors.Grid
    $grid.DefaultCellStyle.SelectionForeColor = $script:NMColors.Text
    $grid.DefaultCellStyle.Font = $script:NMFonts.Grid
    $grid.DefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new(14, 0, 6, 0)
    $grid.AlternatingRowsDefaultCellStyle.BackColor = $script:NMColors.GridAlt
    $grid.AlternatingRowsDefaultCellStyle.SelectionBackColor = $script:NMColors.GridAlt
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:NMColors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $script:NMColors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = $script:NMColors.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = $script:NMFonts.GridHeader
    $grid.ColumnHeadersDefaultCellStyle.Alignment = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
    $grid.ColumnHeadersDefaultCellStyle.Padding = [System.Windows.Forms.Padding]::new(14, 0, 6, 0)

    $grid.Add_CellFormatting({
        param($sender, $eventArgs)

        if ($eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -lt 0) {
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

        $presentation = Get-NMColumnPresentation -State $script:NMTargetStates[$name] -Target $target -ColumnId $columnId
        $eventArgs.Value = $presentation.Text
        $eventArgs.CellStyle.ForeColor = $presentation.ForeColor
        $eventArgs.CellStyle.SelectionForeColor = $presentation.ForeColor
        $eventArgs.CellStyle.Font = $presentation.Font
        $eventArgs.CellStyle.Alignment = $presentation.Align
    })

    $grid.Add_CellPainting({
        param($sender, $eventArgs)

        if ($eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -lt 0) {
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
        $presentation = Get-NMColumnPresentation -State $state -Target $target -ColumnId $columnId
        if ($presentation.PaintKind -eq 'Text') {
            return
        }

        try {
            $eventArgs.Handled = $true
            Fill-NMGridCellBackground -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -RowIndex $eventArgs.RowIndex

            if ($presentation.PaintKind -eq 'Status') {
                Draw-NMStatusCell -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -Presentation $presentation
            }
            elseif ($presentation.PaintKind -eq 'History') {
                Draw-NMHistoryCell -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds -State $state
            }

            Draw-NMGridCellBorder -Graphics $eventArgs.Graphics -Bounds $eventArgs.CellBounds
        }
        catch {
            $eventArgs.Handled = $false
            Write-NMDebugLog -Message ("Grid paint failed for row {0}, column {1}, target {2}: {3}" -f $eventArgs.RowIndex, $columnId, $name, $_.Exception.Message)
        }
    })

    $grid.Add_ColumnWidthChanged({ Schedule-NMGridColumnPersistence })
    $grid.Add_ColumnDisplayIndexChanged({ Schedule-NMGridColumnPersistence })

    $script:NMColumnPersistTimer = [System.Windows.Forms.Timer]::new()
    $script:NMColumnPersistTimer.Interval = 700
    $script:NMColumnPersistTimer.Add_Tick({
        $script:NMColumnPersistTimer.Stop()
        Save-NMGridColumnLayoutIfDirty
    })

    $script:NMGrid = $grid
    Apply-NMColumnsToGrid
    return $grid
}

function Initialize-NMTitleBar {
    $title = New-NMTitleBar -Form $script:NMForm -Title $script:NMWindowTitle -CanMaximize -Height $script:NMTitleBarHeight -Buttons @(
        [ordered]@{ Key = 'Settings'; Kind = 'Settings'; ToolTip = 'Settings'; OnClick = { Show-NMSettingsForm }; Active = ($script:NMSettingsForm -and -not $script:NMSettingsForm.IsDisposed) }
        [ordered]@{ Key = 'Refresh'; Kind = 'Refresh'; ToolTip = 'Reset monitor data'; OnClick = { Invoke-NMResetAndRefresh } }
        [ordered]@{ Key = 'Pin'; Kind = 'Pin'; ToolTip = 'Always on top'; OnClick = { Invoke-NMTogglePin }; Active = [bool]$script:NMConfig.AlwaysOnTop }
        [ordered]@{ Kind = 'Separator' }
        [ordered]@{ Key = 'Minimize'; Kind = 'Minimize'; ToolTip = 'Minimize'; OnClick = { Invoke-NMMinimize } }
        [ordered]@{ Key = 'Maximize'; Kind = 'Maximize'; ToolTip = 'Maximize or restore'; OnClick = { Invoke-NMToggleMaximize } }
        [ordered]@{ Key = 'Close'; Kind = 'Close'; ToolTip = 'Close'; OnClick = { $script:NMForm.Close() } }
    )

    $script:NMSettingsButton = $title.Buttons['Settings']
    $script:NMRefreshButton = $title.Buttons['Refresh']
    $script:NMPinButton = $title.Buttons['Pin']
    $script:NMMinimizeButton = $title.Buttons['Minimize']
    $script:NMMaximizeButton = $title.Buttons['Maximize']
    $script:NMCloseButton = $title.Buttons['Close']

    return $title.Panel
}

function Apply-NMRuntimeConfigEffects {
    param(
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

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
        Update-NMGridFromState
    }

    if ($ResetMonitor -and $script:NMPingTimer -and $script:NMPingTimer.Enabled) {
        Invoke-NMPingCycle
    }
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
        Show-NMConfigError -Message $_.Exception.Message
        return $false
    }

    Apply-NMRuntimeConfigEffects -ResetMonitor:$ResetMonitor -RebuildGrid:$RebuildGrid -Reason $Reason
    return $true
}

function Invoke-NMConfigEditAndApply {
    param(
        [Parameter(Mandatory)][scriptblock]$Edit,
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

    try {
        [void](Invoke-NMConfigEdit -Edit $Edit)
    }
    catch {
        Show-NMConfigError -Message $_.Exception.Message
        return $false
    }

    Apply-NMRuntimeConfigEffects -ResetMonitor:$ResetMonitor -RebuildGrid:$RebuildGrid -Reason $Reason
    return $true
}

function Invoke-NMOnPingResults {
    param([AllowNull()]$Results)

    Update-NMStateFromPingResults -Results $Results
    Update-NMGridFromState
}

function Register-NMRuntimeExceptionHandlers {
    if ($script:NMRuntimeExceptionHandlersRegistered) {
        return
    }

    $script:NMRuntimeExceptionHandlersRegistered = $true

    [System.Windows.Forms.Application]::add_ThreadException({
        param($sender, $eventArgs)
        [void]$sender
        $details = $eventArgs.Exception.ToString()
        if ($eventArgs.Exception.PSObject.Properties['ScriptStackTrace'] -and $eventArgs.Exception.ScriptStackTrace) {
            $details = "{0}`n{1}" -f $details, $eventArgs.Exception.ScriptStackTrace
        }
        $message = "WinForms thread exception: $($eventArgs.Exception.Message)"
        Write-NMDebugLog -Message $message
        Write-NMStartupErrorLog -Message ("{0}`n{1}" -f $message, $details)
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            'Network Monitor Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    })

    [System.AppDomain]::CurrentDomain.add_UnhandledException({
        param($sender, $eventArgs)
        [void]$sender
        $exception = $eventArgs.ExceptionObject
        $message = if ($exception -is [System.Exception]) { $exception.Message } else { [string]$exception }
        Write-NMStartupErrorLog -Message ("Unhandled exception: {0}" -f $message)
    })
}

function Build-NMMainForm {
    $form = New-NMAppWindow `
        -Name 'NetworkMonitorMainForm' `
        -Title $script:NMWindowTitle `
        -Size (Get-NMSize ([int]$script:NMConfig.Window.Width) ([int]$script:NMConfig.Window.Height)) `
        -MinimumSize (Get-NMSize 820 260) `
        -ShowInTaskbar $true `
        -TopMost ([bool]$script:NMConfig.AlwaysOnTop) `
        -Resizable $true

    $form.Font = $script:NMFonts.Grid
    $script:NMForm = $form

    Apply-NMInitialWindowPlacement

    $titleBar = Initialize-NMTitleBar
    $grid = Initialize-NMGrid
    $form.Controls.Add($grid)
    $form.Controls.Add($titleBar)

    $form.Add_Shown({
        if ($script:NMConfig.AutoStart) {
            Start-NMMonitoring
            Invoke-NMPingCycle
        }
    })

    $form.Add_SizeChanged({
        if (-not $script:NMForm -or $script:NMForm.IsDisposed) {
            return
        }

        if ($script:NMMaximizeButton) {
            $kind = if ($script:NMForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) { 'Restore' } else { 'Maximize' }
            Set-NMIconButtonKind -Button $script:NMMaximizeButton -Kind $kind
        }

        $script:NMForm.Invalidate()
    })

    $form.Add_FormClosing({
        Stop-NMMonitoring
        Save-NMGridColumnLayoutIfDirty
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
    Register-NMRuntimeExceptionHandlers

    Initialize-NMTheme
    $script:NMAppRoot = $AppRoot
    $script:NMConfig = Initialize-NMConfig -AppRoot $AppRoot
    $script:NMGeneration = 1
    Initialize-NMMonitorState
    Initialize-NMPingEngine

    $form = Build-NMMainForm
    [void][System.Windows.Forms.Application]::Run($form)
}
