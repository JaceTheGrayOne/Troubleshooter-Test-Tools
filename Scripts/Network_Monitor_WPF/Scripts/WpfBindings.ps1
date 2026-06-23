function New-NMHistoryDisplaySamples {
    param([Parameter(Mandatory)][hashtable]$State)

    $items = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    $historyLength = [int]$script:NMConfig.HistoryLength
    $history = @($State.History)
    $missing = [math]::Max(0, $historyLength - $history.Count)

    for ($i = 0; $i -lt $missing; $i++) {
        $items.Add([pscustomobject]@{
            Value = $null
            Brush = Get-NMHistorySampleBrush -Sample $null
        })
    }

    foreach ($sample in $history) {
        $items.Add([pscustomobject]@{
            Value = $sample
            Brush = Get-NMHistorySampleBrush -Sample $sample
        })
    }

    while ($items.Count -gt $historyLength) {
        $items.RemoveAt(0)
    }

    return $items
}

function New-NMMonitorRow {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][hashtable]$State
    )

    $row = [pscustomobject]@{
        Name = ''
        Address = ''
        NodeForeground = $null
        AddressForeground = $null
        StatusText = ''
        StatusForeground = $null
        RttText = ''
        RttForeground = $null
        LossText = ''
        LossForeground = $null
        TtlText = ''
        TtlForeground = $null
        BytesText = ''
        BytesForeground = $null
        HistorySamples = $null
    }

    Update-NMMonitorRow -Row $row -Target $Target -State $State
    return $row
}

function Update-NMMonitorRow {
    param(
        [Parameter(Mandatory)]$Row,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][hashtable]$State
    )

    $node = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'Node'
    $address = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'Address'
    $status = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'Status'
    $rtt = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'RTT'
    $loss = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'Loss'
    $ttl = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'TTL'
    $bytes = Get-NMColumnPresentation -State $State -Target $Target -ColumnId 'Bytes'

    $Row.Name = $node.Text
    $Row.Address = $address.Text
    $Row.NodeForeground = $node.Foreground
    $Row.AddressForeground = $address.Foreground
    $Row.StatusText = $status.Text
    $Row.StatusForeground = $status.Foreground
    $Row.RttText = $rtt.Text
    $Row.RttForeground = $rtt.Foreground
    $Row.LossText = $loss.Text
    $Row.LossForeground = $loss.Foreground
    $Row.TtlText = $ttl.Text
    $Row.TtlForeground = $ttl.Foreground
    $Row.BytesText = $bytes.Text
    $Row.BytesForeground = $bytes.Foreground
    $Row.HistorySamples = New-NMHistoryDisplaySamples -State $State
}

function Test-NMRowsMatchEnabledTargets {
    if (-not $script:NMRows) {
        return $false
    }

    $targets = @(Get-NMEnabledTargets)
    if ($script:NMRows.Count -ne $targets.Count) {
        return $false
    }

    for ($i = 0; $i -lt $targets.Count; $i++) {
        if ([string]$script:NMRows[$i].Name -ne [string]$targets[$i].Name) {
            return $false
        }
    }

    return $true
}

function Rebuild-NMMonitorRows {
    if (-not $script:NMRows) {
        $script:NMRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    }

    $script:NMRows.Clear()
    foreach ($target in Get-NMEnabledTargets) {
        $name = [string]$target.Name
        if (-not $script:NMTargetStates.ContainsKey($name)) {
            $script:NMTargetStates[$name] = New-NMTargetState
        }
        $script:NMRows.Add((New-NMMonitorRow -Target $target -State $script:NMTargetStates[$name]))
    }

    if ($script:NMMonitorGrid) {
        $script:NMMonitorGrid.ItemsSource = $script:NMRows
        $script:NMMonitorGrid.Items.Refresh()
    }
}

function Update-NMMonitorRowsFromState {
    if (-not $script:NMRows -or -not (Test-NMRowsMatchEnabledTargets)) {
        Rebuild-NMMonitorRows
        return
    }

    $targets = @(Get-NMEnabledTargets)
    for ($i = 0; $i -lt $targets.Count; $i++) {
        $target = $targets[$i]
        $name = [string]$target.Name
        if (-not $script:NMTargetStates.ContainsKey($name)) {
            $script:NMTargetStates[$name] = New-NMTargetState
        }
        Update-NMMonitorRow -Row $script:NMRows[$i] -Target $target -State $script:NMTargetStates[$name]
    }

    if ($script:NMMonitorGrid) {
        $script:NMMonitorGrid.Items.Refresh()
    }
}

function New-NMTextBlockStyle {
    param(
        [Parameter(Mandatory)][string]$ForegroundPath,
        [string]$FontWeight = 'Normal'
    )

    $style = [System.Windows.Style]::new([System.Windows.Controls.TextBlock])
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::ForegroundProperty, [System.Windows.Data.Binding]::new($ForegroundPath)))
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::FontFamilyProperty, [System.Windows.Media.FontFamily]::new('Consolas')))
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::FontSizeProperty, [double]14.666))
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::FontWeightProperty, [System.Windows.FontWeightConverter]::new().ConvertFromString($FontWeight)))
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::VerticalAlignmentProperty, [System.Windows.VerticalAlignment]::Center))
    $style.Setters.Add([System.Windows.Setter]::new([System.Windows.Controls.TextBlock]::MarginProperty, [System.Windows.Thickness]::new(14, 0, 6, 0)))
    return $style
}

function New-NMGridTextColumn {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][hashtable]$Definition,
        [Parameter(Mandatory)]$ColumnConfig,
        [Parameter(Mandatory)][string]$BindingPath,
        [Parameter(Mandatory)][string]$ForegroundPath,
        [string]$FontWeight = 'Normal'
    )

    $column = [System.Windows.Controls.DataGridTextColumn]::new()
    $column.Header = [string]$Definition.Header
    $column.SortMemberPath = $Id
    $column.Binding = [System.Windows.Data.Binding]::new($BindingPath)
    $column.ElementStyle = New-NMTextBlockStyle -ForegroundPath $ForegroundPath -FontWeight $FontWeight
    $column.Width = [System.Windows.Controls.DataGridLength]::new([double][int]$ColumnConfig.Width)
    $column.MinWidth = [double][int]$Definition.MinWidth
    $column.CanUserSort = $false
    $column.Visibility = if ([bool]$ColumnConfig.Visible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    return $column
}

function New-NMGridTemplateColumn {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][hashtable]$Definition,
        [Parameter(Mandatory)]$ColumnConfig,
        [Parameter(Mandatory)][System.Windows.DataTemplate]$Template
    )

    $column = [System.Windows.Controls.DataGridTemplateColumn]::new()
    $column.Header = [string]$Definition.Header
    $column.SortMemberPath = $Id
    $column.CellTemplate = $Template
    $column.Width = [System.Windows.Controls.DataGridLength]::new([double][int]$ColumnConfig.Width)
    $column.MinWidth = [double][int]$Definition.MinWidth
    $column.CanUserSort = $false
    $column.Visibility = if ([bool]$ColumnConfig.Visible) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    return $column
}

function Apply-NMColumnsToGrid {
    if (-not $script:NMMonitorGrid) {
        return
    }

    $script:NMSuppressColumnEvents = $true
    try {
        $script:NMMonitorGrid.Columns.Clear()

        foreach ($columnConfig in @($script:NMConfig.Columns)) {
            $id = [string]$columnConfig.Id
            $definition = $script:NMColumnDefinitions[$id]
            if (-not $definition) {
                continue
            }

            $column = switch ($id) {
                'Node' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'Name' -ForegroundPath 'NodeForeground' -FontWeight 'Bold' }
                'Address' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'Address' -ForegroundPath 'AddressForeground' }
                'RTT' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'RttText' -ForegroundPath 'RttForeground' }
                'Loss' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'LossText' -ForegroundPath 'LossForeground' }
                'TTL' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'TtlText' -ForegroundPath 'TtlForeground' }
                'Bytes' { New-NMGridTextColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -BindingPath 'BytesText' -ForegroundPath 'BytesForeground' }
                'Status' { New-NMGridTemplateColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -Template $script:NMMainWindow.Resources['StatusCellTemplate'] }
                'History' { New-NMGridTemplateColumn -Id $id -Definition $definition -ColumnConfig $columnConfig -Template $script:NMMainWindow.Resources['HistoryCellTemplate'] }
            }

            if ($column) {
                [void]$script:NMMonitorGrid.Columns.Add($column)
                $column.DisplayIndex = [int]($script:NMMonitorGrid.Columns.Count - 1)
            }
        }
    }
    finally {
        $script:NMSuppressColumnEvents = $false
    }

    Rebuild-NMMonitorRows
    Update-NMMonitorGridViewportWidth
}

function Get-NMVisibleMonitorColumnWidth {
    $width = 0.0

    if ($script:NMMonitorGrid -and $script:NMMonitorGrid.Columns.Count -gt 0) {
        foreach ($column in @($script:NMMonitorGrid.Columns)) {
            if ($column.Visibility -ne [System.Windows.Visibility]::Visible) {
                continue
            }

            if ($column.ActualWidth -gt 0) {
                $width += [double]$column.ActualWidth
            }
            elseif (-not [double]::IsNaN($column.Width.DisplayValue) -and $column.Width.DisplayValue -gt 0) {
                $width += [double]$column.Width.DisplayValue
            }
            else {
                $configColumn = Get-NMConfigColumn -Id ([string]$column.SortMemberPath)
                if ($configColumn) {
                    $width += [double][int]$configColumn.Width
                }
            }
        }
    }

    if ($width -le 0) {
        foreach ($columnConfig in @($script:NMConfig.Columns)) {
            if ($columnConfig.Visible) {
                $width += [double][int]$columnConfig.Width
            }
        }
    }

    return $width
}

function Update-NMMonitorGridViewportWidth {
    if (-not $script:NMMonitorGrid) {
        return
    }

    $items = @(Get-NMVisibleMonitorColumnSizing)
    if ($items.Count -lt 1) {
        return
    }

    $configuredWidth = 0.0
    $minimumWidth = 0.0
    foreach ($item in $items) {
        $configuredWidth += [double]$item.ConfigWidth
        $minimumWidth += [double]$item.MinWidth
    }

    $availableWidth = $configuredWidth
    if ($script:NMMainWindow -and $script:NMMainWindow.ActualWidth -gt 0) {
        $availableWidth = [math]::Max(1.0, ([double]$script:NMMainWindow.ActualWidth - 2.0))
    }
    elseif ($script:NMConfig -and $script:NMConfig.Window) {
        $availableWidth = [math]::Max(1.0, ([double][int]$script:NMConfig.Window.Width - 2.0))
    }

    if (($configuredWidth - $availableWidth) -gt 0 -and ($configuredWidth - $availableWidth) -le 4.0) {
        $availableWidth = $configuredWidth
    }

    $targetWidth = [math]::Max($minimumWidth, [math]::Min($configuredWidth, $availableWidth))
    $script:NMResponsiveColumnSizingActive = ($targetWidth -lt ($configuredWidth - 0.5))

    $configExtra = [math]::Max(0.0, ($configuredWidth - $minimumWidth))
    $targetExtra = [math]::Max(0.0, ($targetWidth - $minimumWidth))
    $ratio = if ($configExtra -gt 0) { $targetExtra / $configExtra } else { 0.0 }

    $previousSuppress = $script:NMSuppressColumnEvents
    $script:NMSuppressColumnEvents = $true
    try {
        $assigned = 0.0
        for ($i = 0; $i -lt $items.Count; $i++) {
            $item = $items[$i]
            $width = if ($script:NMResponsiveColumnSizingActive) {
                if ($i -eq ($items.Count - 1)) {
                    [math]::Max([double]$item.MinWidth, ($targetWidth - $assigned))
                }
                else {
                    [double]$item.MinWidth + (([double]$item.ConfigWidth - [double]$item.MinWidth) * $ratio)
                }
            }
            else {
                [double]$item.ConfigWidth
            }

            $assigned += $width
            $item.Column.Width = [System.Windows.Controls.DataGridLength]::new([double]$width)
        }
    }
    finally {
        $script:NMSuppressColumnEvents = $previousSuppress
    }

    $targetWidth = [math]::Max(1.0, [math]::Ceiling($targetWidth))
    if ([math]::Abs([double]$script:NMMonitorGrid.Width - $targetWidth) -gt 0.5 -or [double]::IsNaN([double]$script:NMMonitorGrid.Width)) {
        $script:NMMonitorGrid.Width = $targetWidth
    }
}

function Get-NMVisibleMonitorColumnSizing {
    $items = @()
    if (-not $script:NMMonitorGrid) {
        return @($items)
    }

    foreach ($columnConfig in @($script:NMConfig.Columns)) {
        if (-not $columnConfig.Visible) {
            continue
        }

        $id = [string]$columnConfig.Id
        $definition = $script:NMColumnDefinitions[$id]
        if (-not $definition) {
            continue
        }

        $gridColumn = $script:NMMonitorGrid.Columns | Where-Object { [string]$_.SortMemberPath -eq $id } | Select-Object -First 1
        if (-not $gridColumn) {
            continue
        }

        $items += [pscustomobject]@{
            Id = $id
            Column = $gridColumn
            ConfigWidth = [double][int]$columnConfig.Width
            MinWidth = [double][int]$definition.MinWidth
        }
    }

    return @($items)
}

function Get-NMVisibleMonitorColumnMinimumWidth {
    $width = 0.0
    foreach ($columnConfig in @($script:NMConfig.Columns)) {
        if (-not $columnConfig.Visible) {
            continue
        }
        $definition = $script:NMColumnDefinitions[[string]$columnConfig.Id]
        if ($definition) {
            $width += [double][int]$definition.MinWidth
        }
    }
    return $width
}

function Initialize-NMMonitorGridBinding {
    param([Parameter(Mandatory)][System.Windows.Controls.DataGrid]$Grid)

    $script:NMMonitorGrid = $Grid
    $script:NMRows = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
    $Grid.ItemsSource = $script:NMRows
    Apply-NMColumnsToGrid
}

function Get-NMColumnsFromGrid {
    if (-not $script:NMMonitorGrid) {
        return @()
    }

    $columns = @()
    foreach ($gridColumn in @($script:NMMonitorGrid.Columns | Sort-Object DisplayIndex)) {
        $id = [string]$gridColumn.SortMemberPath
        if ([string]::IsNullOrWhiteSpace($id)) {
            $id = [string]$gridColumn.Header
        }
        $definition = $script:NMColumnDefinitions[$id]
        if (-not $definition) {
            continue
        }

        if ($script:NMResponsiveColumnSizingActive) {
            $configColumn = Get-NMConfigColumn -Id $id
            $width = if ($configColumn) { [int]$configColumn.Width } else { [int]$definition.DefaultWidth }
        }
        else {
            $width = [int][math]::Round([math]::Max([double]$gridColumn.ActualWidth, [double]$gridColumn.Width.DisplayValue))
            if ($width -lt [int]$definition.MinWidth) {
                $width = [int]$definition.MinWidth
            }
        }

        $columns += [ordered]@{
            Id = $id
            Visible = ($gridColumn.Visibility -eq [System.Windows.Visibility]::Visible)
            Width = [int]$width
        }
    }

    return @($columns)
}

function Test-NMColumnConfigsEquivalent {
    param(
        [Parameter(Mandatory)]$Left,
        [Parameter(Mandatory)]$Right
    )

    $leftColumns = @($Left)
    $rightColumns = @($Right)
    if ($leftColumns.Count -ne $rightColumns.Count) {
        return $false
    }

    for ($i = 0; $i -lt $leftColumns.Count; $i++) {
        if ([string]$leftColumns[$i].Id -ne [string]$rightColumns[$i].Id) { return $false }
        if ([bool]$leftColumns[$i].Visible -ne [bool]$rightColumns[$i].Visible) { return $false }
        if ([int]$leftColumns[$i].Width -ne [int]$rightColumns[$i].Width) { return $false }
    }

    return $true
}

function Update-NMConfigFromGridColumns {
    if ($script:NMSuppressColumnEvents -or -not $script:NMMonitorGrid -or $script:NMMonitorGrid.Columns.Count -lt 1) {
        return
    }

    $columns = @(Get-NMColumnsFromGrid)
    if (Test-NMColumnConfigsEquivalent -Left $script:NMConfig.Columns -Right $columns) {
        return
    }

    try {
        [void](Invoke-NMConfigEdit -Edit {
            param($config)
            $config.Columns = @($columns)
        })
        Sync-NMColumnsControls
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

function Register-NMGridColumnPersistence {
    param([Parameter(Mandatory)][System.Windows.Controls.DataGrid]$Grid)

    $script:NMColumnLayoutDirty = $false
    $script:NMColumnPersistTimer = [System.Windows.Threading.DispatcherTimer]::new()
    $script:NMColumnPersistTimer.Interval = [TimeSpan]::FromMilliseconds(700)
    $script:NMColumnPersistTimer.Add_Tick({
        $script:NMColumnPersistTimer.Stop()
        Save-NMGridColumnLayoutIfDirty
    })

    $Grid.Add_ColumnReordered({ Schedule-NMGridColumnPersistence })
    $Grid.Add_LayoutUpdated({
        if ($script:NMSuppressColumnEvents) { return }
        $columns = @(Get-NMColumnsFromGrid)
        if ($columns.Count -gt 0 -and -not (Test-NMColumnConfigsEquivalent -Left $script:NMConfig.Columns -Right $columns)) {
            Schedule-NMGridColumnPersistence
        }
        Update-NMMonitorGridViewportWidth
    })
}
