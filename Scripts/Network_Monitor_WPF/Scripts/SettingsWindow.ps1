function Set-NMTextCommittedValue {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.TextBox]$TextBox,
        [Parameter(Mandatory)][string]$Value
    )

    $script:NMSettingsSuppress = $true
    try {
        $TextBox.Text = $Value
        if ($TextBox.Tag -and $TextBox.Tag.PSObject.Properties['LastCommitted']) {
            $TextBox.Tag.LastCommitted = $Value
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }
}

function Invoke-NMTextCommit {
    param([Parameter(Mandatory)][System.Windows.Controls.TextBox]$TextBox)

    if ($script:NMSettingsSuppress -or -not $TextBox.Tag -or $TextBox.Tag.Committing) {
        return
    }

    $value = [string]$TextBox.Text
    if ($value -eq [string]$TextBox.Tag.LastCommitted) {
        return
    }

    $TextBox.Tag.Committing = $true
    try {
        $ok = & $TextBox.Tag.OnCommit $TextBox $value
        if ($ok -ne $false) {
            $TextBox.Tag.LastCommitted = [string]$TextBox.Text
        }
        else {
            $TextBox.Text = [string]$TextBox.Tag.LastCommitted
        }
    }
    finally {
        $TextBox.Tag.Committing = $false
    }
}

function Register-NMTextCommit {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.TextBox]$TextBox,
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

function ConvertTo-NMSettingsInteger {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][int]$Minimum,
        [Parameter(Mandatory)][int]$Maximum,
        [Parameter(Mandatory)][string]$Label,
        [ref]$Result
    )

    $number = 0
    if (-not [int]::TryParse($Value.Trim(), [ref]$number)) {
        Set-NMSettingsFeedback -Message ("{0} must be a whole number." -f $Label) -Error
        return $false
    }

    if ($number -lt $Minimum -or $number -gt $Maximum) {
        Set-NMSettingsFeedback -Message ("{0} must be between {1} and {2}." -f $Label, $Minimum, $Maximum) -Error
        return $false
    }

    $Result.Value = $number
    return $true
}

function Register-NMIntegerSettingCommit {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.TextBox]$TextBox,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$Minimum,
        [Parameter(Mandatory)][int]$Maximum,
        [Parameter(Mandatory)][scriptblock]$ApplyValue,
        [switch]$ResetMonitor,
        [AllowEmptyString()][string]$Reason = ''
    )

    Register-NMTextCommit -TextBox $TextBox -OnCommit {
        param($box, $text)
        $number = 0
        if (-not (ConvertTo-NMSettingsInteger -Value $text -Minimum $Minimum -Maximum $Maximum -Label $Label -Result ([ref]$number))) {
            return $false
        }

        if (Invoke-NMConfigEditAndApply -ResetMonitor:$ResetMonitor -Reason $Reason -Edit {
            param($config)
            & $ApplyValue $config $number
        }) {
            $box.Text = [string]$number
            Set-NMSettingsFeedback -Message ("{0} saved." -f $Label)
            return $true
        }
        return $false
    }.GetNewClosure()
}

function New-NMTargetRowObject {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][int]$Index
    )

    return [pscustomobject]@{
        Index = $Index
        Enabled = [bool]$Target.Enabled
        Name = [string]$Target.Name
        Address = [string]$Target.Address
        Color = [string]$Target.Color
    }
}

function Sync-NMTargetsGrid {
    if (-not $script:NMSettingsTargetsGrid) {
        return
    }

    $script:NMSettingsSuppress = $true
    try {
        $items = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
        for ($i = 0; $i -lt @($script:NMConfig.Targets).Count; $i++) {
            $items.Add((New-NMTargetRowObject -Target $script:NMConfig.Targets[$i] -Index $i))
        }
        $script:NMSettingsTargetsGrid.ItemsSource = $items
        if ($items.Count -gt 0 -and $script:NMSettingsTargetsGrid.SelectedIndex -lt 0) {
            $script:NMSettingsTargetsGrid.SelectedIndex = 0
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }

    Update-NMTargetColorPreview
}

function Update-NMTargetColorPreview {
    if (-not $script:NMSettingsTargetColorPreview -or -not $script:NMSettingsTargetsGrid) {
        return
    }

    $index = [int]$script:NMSettingsTargetsGrid.SelectedIndex
    if ($index -lt 0 -or $index -ge @($script:NMConfig.Targets).Count) {
        return
    }

    $color = [string]$script:NMConfig.Targets[$index].Color
    if (Test-NMHtmlColor -Color $color) {
        $script:NMSettingsTargetColorPreview.Background = ConvertTo-NMWpfBrush -HtmlColor $color
    }
}

function Commit-NMTargetCell {
    param(
        [int]$RowIndex,
        [string]$ColumnName,
        [AllowNull()]$Value
    )

    if ($RowIndex -lt 0 -or $RowIndex -ge @($script:NMConfig.Targets).Count) {
        return $false
    }

    $newValue = $null

    switch ($ColumnName) {
        'Enabled' {
            $enabled = [bool]$Value
            if (-not $enabled) {
                $otherEnabled = 0
                for ($i = 0; $i -lt @($script:NMConfig.Targets).Count; $i++) {
                    if ($i -ne $RowIndex -and $script:NMConfig.Targets[$i].Enabled) {
                        $otherEnabled++
                    }
                }

                if ($otherEnabled -lt 1) {
                    Set-NMSettingsFeedback -Message 'At least one target must remain enabled.' -Error
                    return $false
                }
            }
            $newValue = $enabled
        }
        'Name' {
            $name = ([string]$Value).Trim()
            if ([string]::IsNullOrWhiteSpace($name)) {
                Set-NMSettingsFeedback -Message 'Target name cannot be blank.' -Error
                return $false
            }

            for ($i = 0; $i -lt @($script:NMConfig.Targets).Count; $i++) {
                if ($i -ne $RowIndex -and [string]::Equals([string]$script:NMConfig.Targets[$i].Name, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Set-NMSettingsFeedback -Message ("Target name '{0}' is already used." -f $name) -Error
                    return $false
                }
            }
            $newValue = $name
        }
        'Address' {
            $address = ([string]$Value).Trim()
            if (-not (Test-NMAddress -Address $address)) {
                Set-NMSettingsFeedback -Message 'Address must be an IPv4 address or hostname.' -Error
                return $false
            }
            $newValue = $address
        }
        'Color' {
            $color = ([string]$Value).Trim()
            if (-not (Test-NMHtmlColor -Color $color)) {
                Set-NMSettingsFeedback -Message 'Color must use #RRGGBB format.' -Error
                return $false
            }
            $newValue = $color.ToLowerInvariant()
        }
        default {
            return $false
        }
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target settings changed' -Edit {
        param($config)
        $config.Targets[$RowIndex][$ColumnName] = $newValue
    }) {
        Set-NMSettingsFeedback -Message 'Target settings saved.'
        Sync-NMTargetsGrid
        return $true
    }

    return $false
}

function New-NMUniqueTargetName {
    $index = 1
    while ($true) {
        $name = 'Node{0}' -f $index
        $exists = $false
        foreach ($target in @($script:NMConfig.Targets)) {
            if ([string]::Equals([string]$target.Name, $name, [System.StringComparison]::OrdinalIgnoreCase)) {
                $exists = $true
                break
            }
        }
        if (-not $exists) {
            return $name
        }
        $index++
    }
}

function Add-NMTargetFromSettings {
    $newTarget = [ordered]@{
        Name = New-NMUniqueTargetName
        Address = 'localhost'
        Color = '#27d9e6'
        Enabled = $true
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target added' -Edit {
        param($config)
        $config.Targets = @($config.Targets + $newTarget)
    }) {
        Sync-NMTargetsGrid
        $script:NMSettingsTargetsGrid.SelectedIndex = @($script:NMConfig.Targets).Count - 1
        Set-NMSettingsFeedback -Message 'Target added.'
    }
}

function Remove-NMSelectedTarget {
    if (-not $script:NMSettingsTargetsGrid) {
        return
    }

    $index = [int]$script:NMSettingsTargetsGrid.SelectedIndex
    if ($index -lt 0 -or $index -ge @($script:NMConfig.Targets).Count) {
        return
    }

    $target = $script:NMConfig.Targets[$index]
    if ($target.Enabled -and @($script:NMConfig.Targets | Where-Object { $_.Enabled }).Count -le 1) {
        Set-NMSettingsFeedback -Message 'Cannot delete the last enabled target.' -Error
        return
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target deleted' -Edit {
        param($config)
        $list = [System.Collections.ArrayList]::new()
        foreach ($item in @($config.Targets)) { [void]$list.Add($item) }
        $list.RemoveAt($index)
        $config.Targets = @($list)
    }) {
        Sync-NMTargetsGrid
        $script:NMSettingsTargetsGrid.SelectedIndex = [math]::Min($index, @($script:NMConfig.Targets).Count - 1)
        Set-NMSettingsFeedback -Message 'Target deleted.'
    }
}

function Move-NMSelectedTarget {
    param([Parameter(Mandatory)][int]$Delta)

    if (-not $script:NMSettingsTargetsGrid) {
        return
    }

    $index = [int]$script:NMSettingsTargetsGrid.SelectedIndex
    $newIndex = $index + $Delta
    if ($newIndex -lt 0 -or $newIndex -ge @($script:NMConfig.Targets).Count) {
        return
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target order changed' -Edit {
        param($config)
        $targets = @($config.Targets)
        $temp = $targets[$index]
        $targets[$index] = $targets[$newIndex]
        $targets[$newIndex] = $temp
        $config.Targets = @($targets)
    }) {
        Sync-NMTargetsGrid
        $script:NMSettingsTargetsGrid.SelectedIndex = $newIndex
        Set-NMSettingsFeedback -Message 'Target order saved.'
    }
}

function Initialize-NMTargetsEditor {
    param([Parameter(Mandatory)][System.Windows.Controls.DataGrid]$Grid)

    $script:NMSettingsTargetsGrid = $Grid
    if ($Grid.Columns.Count -lt 1) {
        $enabled = [System.Windows.Controls.DataGridCheckBoxColumn]::new()
        $enabled.Header = 'Enabled'
        $enabled.Binding = [System.Windows.Data.Binding]::new('Enabled')
        $enabled.Width = [System.Windows.Controls.DataGridLength]::new(70)
        [void]$Grid.Columns.Add($enabled)

        foreach ($info in @(
            @{ Header = 'Node'; Path = 'Name'; Width = 120 }
            @{ Header = 'Address'; Path = 'Address'; Width = 180 }
            @{ Header = 'Color'; Path = 'Color'; Width = 110 }
        )) {
            $column = [System.Windows.Controls.DataGridTextColumn]::new()
            $column.Header = [string]$info.Header
            $column.Binding = [System.Windows.Data.Binding]::new([string]$info.Path)
            $column.Width = [System.Windows.Controls.DataGridLength]::new([double][int]$info.Width)
            [void]$Grid.Columns.Add($column)
        }
    }

    $Grid.Add_CellEditEnding({
        param($sender, $eventArgs)
        if ($script:NMSettingsSuppress -or $eventArgs.Row.GetIndex() -lt 0) { return }
        $rowIndex = $eventArgs.Row.GetIndex()
        $header = [string]$eventArgs.Column.Header
        $columnName = switch ($header) {
            'Enabled' { 'Enabled' }
            'Node' { 'Name' }
            'Address' { 'Address' }
            'Color' { 'Color' }
            default { '' }
        }
        if ([string]::IsNullOrWhiteSpace($columnName)) { return }

        $dispatcher = $sender.Dispatcher
        [void]$dispatcher.BeginInvoke([System.Action]{
            $item = $sender.Items[$rowIndex]
            if (-not $item) { return }
            $value = $item.PSObject.Properties[$columnName].Value
            if (-not (Commit-NMTargetCell -RowIndex $rowIndex -ColumnName $columnName -Value $value)) {
                Sync-NMTargetsGrid
            }
            else {
                Update-NMTargetColorPreview
            }
        }.GetNewClosure(), [System.Windows.Threading.DispatcherPriority]::Background)
    })

    $Grid.Add_SelectionChanged({ Update-NMTargetColorPreview })
    Sync-NMTargetsGrid
}

function Sync-NMColumnsControls {
    if (-not $script:NMSettingsColumnsVisibilityList -or -not $script:NMSettingsColumnOrderList) {
        return
    }

    $script:NMSettingsSuppress = $true
    try {
        $script:NMSettingsColumnsVisibilityList.Items.Clear()
        $script:NMSettingsColumnOrderList.Items.Clear()
        foreach ($column in @($script:NMConfig.Columns)) {
            $id = [string]$column.Id
            $check = [System.Windows.Controls.CheckBox]::new()
            $check.Content = $id
            $check.Tag = $id
            $check.IsChecked = [bool]$column.Visible
            $check.Margin = [System.Windows.Thickness]::new(6, 4, 0, 4)
            $check.Add_Click({
                param($sender, $eventArgs)
                [void]$eventArgs
                if ($script:NMSettingsSuppress) { return }
                $columnId = [string]$sender.Tag
                $newVisible = [bool]$sender.IsChecked
                if (-not $newVisible -and @($script:NMConfig.Columns | Where-Object { $_.Visible }).Count -le 1) {
                    $script:NMSettingsSuppress = $true
                    try { $sender.IsChecked = $true }
                    finally { $script:NMSettingsSuppress = $false }
                    Set-NMSettingsFeedback -Message 'At least one column must stay visible.' -Error
                    return
                }

                if (Invoke-NMConfigEditAndApply -RebuildGrid -Reason 'Column visibility changed' -Edit {
                    param($config)
                    foreach ($candidate in @($config.Columns)) {
                        if ([string]$candidate.Id -eq $columnId) {
                            $candidate.Visible = $newVisible
                            break
                        }
                    }
                }) {
                    Set-NMSettingsFeedback -Message 'Column visibility saved.'
                    Sync-NMColumnsControls
                }
                else {
                    Sync-NMColumnsControls
                }
            }.GetNewClosure())
            [void]$script:NMSettingsColumnsVisibilityList.Items.Add($check)
            [void]$script:NMSettingsColumnOrderList.Items.Add($id)
        }
        if ($script:NMSettingsColumnOrderList.Items.Count -gt 0 -and $script:NMSettingsColumnOrderList.SelectedIndex -lt 0) {
            $script:NMSettingsColumnOrderList.SelectedIndex = 0
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }

    Update-NMColumnWidthEditor
}

function Update-NMColumnWidthEditor {
    if (-not $script:NMSettingsColumnWidthTextBox -or -not $script:NMSettingsColumnOrderList -or $script:NMSettingsColumnOrderList.SelectedIndex -lt 0) {
        return
    }

    $id = [string]$script:NMSettingsColumnOrderList.SelectedItem
    $column = Get-NMConfigColumn -Id $id
    if ($column) {
        Set-NMTextCommittedValue -TextBox $script:NMSettingsColumnWidthTextBox -Value ([string][int]$column.Width)
    }
}

function Move-NMSelectedColumn {
    param([Parameter(Mandatory)][int]$Delta)

    if (-not $script:NMSettingsColumnOrderList) {
        return
    }

    $index = [int]$script:NMSettingsColumnOrderList.SelectedIndex
    $newIndex = $index + $Delta
    if ($newIndex -lt 0 -or $newIndex -ge @($script:NMConfig.Columns).Count) {
        return
    }

    if (Invoke-NMConfigEditAndApply -RebuildGrid -Reason 'Column order changed' -Edit {
        param($config)
        $columns = @($config.Columns)
        $temp = $columns[$index]
        $columns[$index] = $columns[$newIndex]
        $columns[$newIndex] = $temp
        $config.Columns = @($columns)
    }) {
        Sync-NMColumnsControls
        $script:NMSettingsColumnOrderList.SelectedIndex = $newIndex
        Set-NMSettingsFeedback -Message 'Column order saved.'
    }
}

function Register-NMSettingsHandlers {
    param([Parameter(Mandatory)]$Controls)

    $Controls.AddTargetButton.Add_Click({ Add-NMTargetFromSettings })
    $Controls.DeleteTargetButton.Add_Click({ Remove-NMSelectedTarget })
    $Controls.MoveTargetUpButton.Add_Click({ Move-NMSelectedTarget -Delta -1 })
    $Controls.MoveTargetDownButton.Add_Click({ Move-NMSelectedTarget -Delta 1 })

    $Controls.ColumnsOrderList.Add_SelectionChanged({ Update-NMColumnWidthEditor })
    $Controls.MoveColumnUpButton.Add_Click({ Move-NMSelectedColumn -Delta -1 })
    $Controls.MoveColumnDownButton.Add_Click({ Move-NMSelectedColumn -Delta 1 })

    Register-NMTextCommit -TextBox $Controls.ColumnWidthTextBox -OnCommit {
        param($box, $text)
        if (-not $script:NMSettingsColumnOrderList -or $script:NMSettingsColumnOrderList.SelectedIndex -lt 0) { return $false }
        $id = [string]$script:NMSettingsColumnOrderList.SelectedItem
        $definition = $script:NMColumnDefinitions[$id]
        $width = 0
        if (-not (ConvertTo-NMSettingsInteger -Value $text -Minimum ([int]$definition.MinWidth) -Maximum 2000 -Label 'Column width' -Result ([ref]$width))) {
            return $false
        }

        if (Invoke-NMConfigEditAndApply -RebuildGrid -Reason 'Column width changed' -Edit {
            param($config)
            foreach ($column in @($config.Columns)) {
                if ([string]$column.Id -eq $id) {
                    $column.Width = [int]$width
                    break
                }
            }
        }) {
            $box.Text = [string]$width
            Set-NMSettingsFeedback -Message 'Column width saved.'
            Sync-NMColumnsControls
            return $true
        }
        return $false
    }

    Register-NMIntegerSettingCommit -TextBox $Controls.RefreshIntervalTextBox -Label 'Refresh interval' -Minimum 250 -Maximum 60000 -ResetMonitor -Reason 'Refresh interval changed' -ApplyValue {
        param($config, $value)
        $config.RefreshMilliseconds = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.PingTimeoutTextBox -Label 'Ping timeout' -Minimum 100 -Maximum 60000 -ResetMonitor -Reason 'Ping timeout changed' -ApplyValue {
        param($config, $value)
        $config.PingTimeoutMilliseconds = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.HistoryLengthTextBox -Label 'History length' -Minimum 4 -Maximum 60 -ResetMonitor -Reason 'History length changed' -ApplyValue {
        param($config, $value)
        $config.HistoryLength = [int]$value
    }

    $Controls.AutoStartCheckBox.Add_Click({
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.AutoStart
        $checked = [bool]$script:NMAutoStartCheckBox.IsChecked
        if (Invoke-NMConfigEditAndApply -Reason 'Auto-start changed' -Edit {
            param($config)
            $config.AutoStart = $checked
        }) {
            if ($script:NMConfig.AutoStart -and -not (Test-NMMonitoringEnabled)) {
                Start-NMMonitoring
                Invoke-NMPingCycle
            }
            Set-NMSettingsFeedback -Message 'Auto-start setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $script:NMAutoStartCheckBox.IsChecked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    })

    Register-NMIntegerSettingCommit -TextBox $Controls.DownFailuresTextBox -Label 'Down failures' -Minimum 1 -Maximum 20 -ResetMonitor -Reason 'Health threshold changed' -ApplyValue {
        param($config, $value)
        $config.Health.DownFailures = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.OrangeFailuresTextBox -Label 'Orange failures' -Minimum 1 -Maximum 20 -ResetMonitor -Reason 'Health threshold changed' -ApplyValue {
        param($config, $value)
        $config.Health.OrangeFailures = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.OrangeLossTextBox -Label 'Orange rolling loss' -Minimum 0 -Maximum 100 -ResetMonitor -Reason 'Health threshold changed' -ApplyValue {
        param($config, $value)
        $config.Health.OrangeLossPercent = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.RttGreenTextBox -Label 'RTT green max' -Minimum 0 -Maximum 60000 -ResetMonitor -Reason 'RTT threshold changed' -ApplyValue {
        param($config, $value)
        $config.RttThresholds.GreenMax = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.RttYellowTextBox -Label 'RTT yellow max' -Minimum 1 -Maximum 60000 -ResetMonitor -Reason 'RTT threshold changed' -ApplyValue {
        param($config, $value)
        $config.RttThresholds.YellowMax = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.RttOrangeTextBox -Label 'RTT orange max' -Minimum 1 -Maximum 60000 -ResetMonitor -Reason 'RTT threshold changed' -ApplyValue {
        param($config, $value)
        $config.RttThresholds.OrangeMax = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.LossYellowTextBox -Label 'Loss yellow max' -Minimum 0 -Maximum 100 -ResetMonitor -Reason 'Loss threshold changed' -ApplyValue {
        param($config, $value)
        $config.LossThresholds.YellowMax = [int]$value
    }
    Register-NMIntegerSettingCommit -TextBox $Controls.LossOrangeTextBox -Label 'Loss orange max' -Minimum 0 -Maximum 100 -ResetMonitor -Reason 'Loss threshold changed' -ApplyValue {
        param($config, $value)
        $config.LossThresholds.OrangeMax = [int]$value
    }

    $Controls.AlwaysOnTopCheckBox.Add_Click({
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.AlwaysOnTop
        $checked = [bool]$script:NMAlwaysOnTopCheckBox.IsChecked
        if (Invoke-NMConfigEditAndApply -Reason 'Always on top changed' -Edit {
            param($config)
            $config.AlwaysOnTop = $checked
        }) {
            Apply-NMAlwaysOnTopState
            Set-NMSettingsFeedback -Message 'Always-on-top setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $script:NMAlwaysOnTopCheckBox.IsChecked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    })

    $Controls.DebugLoggingCheckBox.Add_Click({
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.DebugMode
        $checked = [bool]$script:NMDebugLoggingCheckBox.IsChecked
        if (Invoke-NMConfigEditAndApply -Reason 'Debug mode changed' -Edit {
            param($config)
            $config.DebugMode = $checked
        }) {
            Set-NMSettingsFeedback -Message 'Debug mode setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $script:NMDebugLoggingCheckBox.IsChecked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    })

    $Controls.ResetWindowPositionButton.Add_Click({ Invoke-NMResetWindowPosition })
    $Controls.ResetDefaultsButton.Add_Click({ Invoke-NMResetDefaults })
}

function Sync-NMSettingsScalarControls {
    if (-not $script:NMSettingsControls) {
        return
    }

    $c = $script:NMSettingsControls
    Set-NMTextCommittedValue -TextBox $c.RefreshIntervalTextBox -Value ([string][int]$script:NMConfig.RefreshMilliseconds)
    Set-NMTextCommittedValue -TextBox $c.PingTimeoutTextBox -Value ([string][int]$script:NMConfig.PingTimeoutMilliseconds)
    Set-NMTextCommittedValue -TextBox $c.HistoryLengthTextBox -Value ([string][int]$script:NMConfig.HistoryLength)
    Set-NMTextCommittedValue -TextBox $c.DownFailuresTextBox -Value ([string][int]$script:NMConfig.Health.DownFailures)
    Set-NMTextCommittedValue -TextBox $c.OrangeFailuresTextBox -Value ([string][int]$script:NMConfig.Health.OrangeFailures)
    Set-NMTextCommittedValue -TextBox $c.OrangeLossTextBox -Value ([string][int]$script:NMConfig.Health.OrangeLossPercent)
    Set-NMTextCommittedValue -TextBox $c.RttGreenTextBox -Value ([string][int]$script:NMConfig.RttThresholds.GreenMax)
    Set-NMTextCommittedValue -TextBox $c.RttYellowTextBox -Value ([string][int]$script:NMConfig.RttThresholds.YellowMax)
    Set-NMTextCommittedValue -TextBox $c.RttOrangeTextBox -Value ([string][int]$script:NMConfig.RttThresholds.OrangeMax)
    Set-NMTextCommittedValue -TextBox $c.LossYellowTextBox -Value ([string][int]$script:NMConfig.LossThresholds.YellowMax)
    Set-NMTextCommittedValue -TextBox $c.LossOrangeTextBox -Value ([string][int]$script:NMConfig.LossThresholds.OrangeMax)

    $script:NMSettingsSuppress = $true
    try {
        $c.AutoStartCheckBox.IsChecked = [bool]$script:NMConfig.AutoStart
        $c.AlwaysOnTopCheckBox.IsChecked = [bool]$script:NMConfig.AlwaysOnTop
        $c.DebugLoggingCheckBox.IsChecked = [bool]$script:NMConfig.DebugMode
    }
    finally {
        $script:NMSettingsSuppress = $false
    }
}

function Invoke-NMResetWindowPosition {
    if (-not $script:NMMainWindow) {
        return
    }

    Set-NMDefaultWindowLocation
    $bounds = [System.Windows.Rect]::new($script:NMMainWindow.Left, $script:NMMainWindow.Top, $script:NMMainWindow.Width, $script:NMMainWindow.Height)
    if (Invoke-NMConfigEditAndApply -Reason 'Window position reset' -Edit {
        param($config)
        $config.Window.Maximized = $false
        $config.Window.Width = [int][math]::Round($bounds.Width)
        $config.Window.Height = [int][math]::Round($bounds.Height)
        $config.Window.X = [int][math]::Round($bounds.X)
        $config.Window.Y = [int][math]::Round($bounds.Y)
    }) {
        Set-NMSettingsFeedback -Message 'Window position reset.'
    }
}

function Invoke-NMResetDefaults {
    param([switch]$Force)

    if (-not $Force) {
        $answer = [System.Windows.MessageBox]::Show(
            $script:NMSettingsWindow,
            'Reset Network Monitor settings to defaults?',
            'Reset to Defaults',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($answer -ne [System.Windows.MessageBoxResult]::Yes) {
            return $false
        }
    }

    $defaultConfig = Get-NMDefaultConfig
    try {
        Save-NMConfig -Config $defaultConfig
    }
    catch {
        Show-NMConfigError -Message $_.Exception.Message
        return $false
    }

    $script:NMConfig = $defaultConfig
    $script:NMGeneration++
    Reset-NMMonitorState
    Apply-NMAlwaysOnTopState
    Apply-NMColumnsToGrid
    Update-NMMonitorRowsFromState
    if ($script:NMMainWindow) {
        $script:NMMainWindow.Width = [double][int]$script:NMConfig.Window.Width
        $script:NMMainWindow.Height = [double][int]$script:NMConfig.Window.Height
        Set-NMDefaultWindowLocation
    }
    if ($script:NMConfig.AutoStart) {
        Start-NMMonitoring
        Invoke-NMPingCycle
    }

    Set-NMSettingsFeedback -Message 'Defaults restored.'
    if ($script:NMSettingsWindow) {
        $script:NMSettingsWindow.Close()
    }
    return $true
}

function Build-NMSettingsWindow {
    param([Parameter(Mandatory)][System.Windows.Window]$Owner)

    $xamlPath = Join-Path $script:NMAppRoot 'Views\SettingsWindow.xaml'
    $loaded = Import-NMWindowXaml -Path $xamlPath -RequiredNames @(
        'SettingsWindowRoot',
        'TitleBar',
        'TitleText',
        'SettingsCloseButton',
        'SettingsTabs',
        'FeedbackText',
        'TargetsGrid',
        'AddTargetButton',
        'DeleteTargetButton',
        'MoveTargetUpButton',
        'MoveTargetDownButton',
        'TargetColorPreview',
        'ColumnsVisibilityList',
        'ColumnsOrderList',
        'MoveColumnUpButton',
        'MoveColumnDownButton',
        'ColumnWidthTextBox',
        'RefreshIntervalTextBox',
        'PingTimeoutTextBox',
        'HistoryLengthTextBox',
        'AutoStartCheckBox',
        'DownFailuresTextBox',
        'OrangeFailuresTextBox',
        'OrangeLossTextBox',
        'RttGreenTextBox',
        'RttYellowTextBox',
        'RttOrangeTextBox',
        'LossYellowTextBox',
        'LossOrangeTextBox',
        'AlwaysOnTopCheckBox',
        'DebugLoggingCheckBox',
        'ResetWindowPositionButton',
        'ResetDefaultsButton'
    )

    $window = $loaded.Window
    $controls = $loaded.Controls
    if ($Owner -and $Owner.IsVisible) {
        $window.Owner = $Owner
    }
    $window.Topmost = [bool]$script:NMConfig.AlwaysOnTop
    $window.Left = [math]::Max(0, $Owner.Left + 36)
    $window.Top = [math]::Max(0, $Owner.Top - 30)

    $script:NMSettingsWindow = $window
    $script:NMSettingsControls = $controls
    $script:NMSettingsFeedbackText = $controls.FeedbackText
    $script:NMSettingsTargetsGrid = $controls.TargetsGrid
    $script:NMSettingsTargetColorPreview = $controls.TargetColorPreview
    $script:NMSettingsColumnsVisibilityList = $controls.ColumnsVisibilityList
    $script:NMSettingsColumnOrderList = $controls.ColumnsOrderList
    $script:NMSettingsColumnWidthTextBox = $controls.ColumnWidthTextBox
    $script:NMAutoStartCheckBox = $controls.AutoStartCheckBox
    $script:NMAlwaysOnTopCheckBox = $controls.AlwaysOnTopCheckBox
    $script:NMDebugLoggingCheckBox = $controls.DebugLoggingCheckBox

    Set-NMWpfWindowChrome -Window $window
    Register-NMWpfTitleDrag -TitleBar $controls.TitleBar -Window $window
    Register-NMWpfTitleDrag -TitleBar $controls.TitleText -Window $window
    $controls.SettingsCloseButton.Add_Click({ $script:NMSettingsWindow.Close() })

    Initialize-NMTargetsEditor -Grid $controls.TargetsGrid
    Register-NMSettingsHandlers -Controls $controls
    Sync-NMColumnsControls
    Sync-NMSettingsScalarControls

    $window.Add_Closed({
        if ($script:NMSettingsButton) {
            Set-NMTitleButtonActive -Button $script:NMSettingsButton -Active $false
        }

        $script:NMSettingsWindow = $null
        $script:NMSettingsControls = $null
        $script:NMSettingsFeedbackText = $null
        $script:NMSettingsTargetsGrid = $null
        $script:NMSettingsTargetColorPreview = $null
        $script:NMSettingsColumnsVisibilityList = $null
        $script:NMSettingsColumnOrderList = $null
        $script:NMSettingsColumnWidthTextBox = $null
        $script:NMAutoStartCheckBox = $null
        $script:NMAlwaysOnTopCheckBox = $null
        $script:NMDebugLoggingCheckBox = $null
    })

    return $window
}

function Show-NMSettingsWindow {
    if ($script:NMSettingsWindow) {
        $script:NMSettingsWindow.Activate()
        $script:NMSettingsWindow.Focus()
        return
    }

    $window = Build-NMSettingsWindow -Owner $script:NMMainWindow
    if ($script:NMSettingsButton) {
        Set-NMTitleButtonActive -Button $script:NMSettingsButton -Active $true
    }

    $window.Show()
}
