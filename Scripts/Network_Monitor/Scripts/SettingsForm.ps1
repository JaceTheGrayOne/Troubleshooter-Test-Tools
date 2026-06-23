function Set-NMSettingsFeedback {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$Error
    )

    if (-not $script:NMSettingsFeedbackLabel) {
        return
    }

    $script:NMSettingsFeedbackLabel.Visible = $true
    $script:NMSettingsFeedbackLabel.Text = $Message
    $script:NMSettingsFeedbackLabel.ForeColor = if ($Error) { $script:NMColors.Red } else { $script:NMColors.Muted }
}

function Set-NMNumericCommittedValue {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.NumericUpDown]$Box,
        [Parameter(Mandatory)][decimal]$Value
    )

    $script:NMSettingsSuppress = $true
    try {
        $Box.Value = $Value
        if ($Box.Tag -and $Box.Tag.PSObject.Properties['LastCommitted']) {
            $Box.Tag.LastCommitted = [decimal]$Value
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }
}

function Invoke-NMNumericCommit {
    param([Parameter(Mandatory)][System.Windows.Forms.NumericUpDown]$Box)

    if ($script:NMSettingsSuppress -or $Box.Tag.Committing) {
        return
    }

    if ([decimal]$Box.Value -eq [decimal]$Box.Tag.LastCommitted) {
        return
    }

    $Box.Tag.Committing = $true
    try {
        $ok = & $Box.Tag.OnCommit $Box
        if ($ok -ne $false) {
            $Box.Tag.LastCommitted = [decimal]$Box.Value
        }
        else {
            $Box.Value = [decimal]$Box.Tag.LastCommitted
        }
    }
    finally {
        $Box.Tag.Committing = $false
    }
}

function Register-NMNumericCommit {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.NumericUpDown]$Box,
        [Parameter(Mandatory)][scriptblock]$OnCommit
    )

    $Box.Tag = [pscustomobject]@{
        LastCommitted = [decimal]$Box.Value
        Committing = $false
        OnCommit = $OnCommit
    }

    $Box.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            Invoke-NMNumericCommit -Box $sender
            $eventArgs.SuppressKeyPress = $true
        }
    })
    $Box.Add_Validated({
        param($sender, $eventArgs)
        [void]$eventArgs
        Invoke-NMNumericCommit -Box $sender
    })
}

function Use-NMTabTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.TabControl]$TabControl)

    $TabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
    $TabControl.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed
    $TabControl.ItemSize = Get-NMSize 153 28
    $TabControl.Padding = Get-NMPoint 8 4
    $TabControl.Add_DrawItem({
        param($sender, $eventArgs)

        $active = ($eventArgs.Index -eq $sender.SelectedIndex)
        $bounds = $eventArgs.Bounds
        $backColor = if ($active) { $script:NMColors.Surface } else { $script:NMColors.TitleBar }
        $foreColor = if ($active) { $script:NMColors.Text } else { $script:NMColors.Muted }

        $brush = [System.Drawing.SolidBrush]::new($backColor)
        $pen = [System.Drawing.Pen]::new($script:NMColors.GridLine, 1)
        try {
            $eventArgs.Graphics.FillRectangle($brush, $bounds)
            $eventArgs.Graphics.DrawRectangle($pen, $bounds.X, $bounds.Y, $bounds.Width - 1, $bounds.Height - 1)
            [System.Windows.Forms.TextRenderer]::DrawText(
                $eventArgs.Graphics,
                $sender.TabPages[$eventArgs.Index].Text,
                $script:NMFonts.Settings,
                $bounds,
                $foreColor,
                ([System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix)
            )
        }
        finally {
            $brush.Dispose()
            $pen.Dispose()
        }
    })
}

function Sync-NMTargetsGrid {
    if (-not $script:NMSettingsTargetsGrid) {
        return
    }

    $script:NMSettingsSuppress = $true
    try {
        $grid = $script:NMSettingsTargetsGrid
        $grid.Rows.Clear()
        for ($i = 0; $i -lt @($script:NMConfig.Targets).Count; $i++) {
            $target = $script:NMConfig.Targets[$i]
            $rowIndex = $grid.Rows.Add([bool]$target.Enabled, [string]$target.Name, [string]$target.Address, [string]$target.Color)
            $grid.Rows[$rowIndex].Tag = $i
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }

    Update-NMTargetColorPreview
}

function Update-NMTargetColorPreview {
    if (-not $script:NMSettingsTargetColorPreview -or -not $script:NMSettingsTargetsGrid -or -not $script:NMSettingsTargetsGrid.CurrentRow) {
        return
    }

    $row = $script:NMSettingsTargetsGrid.CurrentRow
    if ($row.Index -lt 0 -or $row.Index -ge @($script:NMConfig.Targets).Count) {
        return
    }

    $color = [string]$script:NMConfig.Targets[$row.Index].Color
    if (Test-NMHtmlColor -Color $color) {
        $script:NMSettingsTargetColorPreview.BackColor = ConvertTo-NMDrawingColor -HtmlColor $color
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

    $target = $script:NMConfig.Targets[$RowIndex]
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
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target settings changed' -Edit {
        param($config)
        $config.Targets[$RowIndex][$ColumnName] = $newValue
    }) {
        Set-NMSettingsFeedback -Message 'Target settings saved.'
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
        if ($script:NMSettingsTargetsGrid.Rows.Count -gt 0) {
            $script:NMSettingsTargetsGrid.CurrentCell = $script:NMSettingsTargetsGrid.Rows[$script:NMSettingsTargetsGrid.Rows.Count - 1].Cells['Name']
        }
        Set-NMSettingsFeedback -Message 'Target added.'
    }
}

function Remove-NMSelectedTarget {
    $grid = $script:NMSettingsTargetsGrid
    if (-not $grid -or -not $grid.CurrentRow) {
        return
    }

    $index = $grid.CurrentRow.Index
    if ($index -lt 0 -or $index -ge @($script:NMConfig.Targets).Count) {
        return
    }

    $target = $script:NMConfig.Targets[$index]
    if ($target.Enabled) {
        $enabledCount = @($script:NMConfig.Targets | Where-Object { $_.Enabled }).Count
        if ($enabledCount -le 1) {
            Set-NMSettingsFeedback -Message 'Cannot delete the last enabled target.' -Error
            return
        }
    }

    if (Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid -Reason 'Target deleted' -Edit {
        param($config)
        $list = [System.Collections.ArrayList]::new()
        foreach ($item in @($config.Targets)) { [void]$list.Add($item) }
        $list.RemoveAt($index)
        $config.Targets = @($list)
    }) {
        Sync-NMTargetsGrid
        Set-NMSettingsFeedback -Message 'Target deleted.'
    }
}

function Move-NMSelectedTarget {
    param([Parameter(Mandatory)][int]$Delta)

    $grid = $script:NMSettingsTargetsGrid
    if (-not $grid -or -not $grid.CurrentRow) {
        return
    }

    $index = $grid.CurrentRow.Index
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
        $script:NMSettingsTargetsGrid.CurrentCell = $script:NMSettingsTargetsGrid.Rows[$newIndex].Cells['Name']
        Set-NMSettingsFeedback -Message 'Target order saved.'
    }
}

function New-NMTargetsTab {
    param([Parameter(Mandatory)][System.Windows.Forms.TabPage]$Tab)

    $grid = [System.Windows.Forms.DataGridView]::new()
    $grid.Location = Get-NMPoint 14 14
    $grid.Size = Get-NMSize 570 272
    $grid.Anchor = 'Top, Left, Bottom'
    $grid.BackgroundColor = $script:NMColors.Surface
    $grid.GridColor = $script:NMColors.GridLine
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $grid.RowHeadersVisible = $false
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.MultiSelect = $false
    $grid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
    $grid.DefaultCellStyle.BackColor = $script:NMColors.Surface
    $grid.DefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.DefaultCellStyle.SelectionBackColor = $script:NMColors.TitleBarHover
    $grid.DefaultCellStyle.SelectionForeColor = $script:NMColors.Text
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:NMColors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:NMColors.Text
    $grid.EnableHeadersVisualStyles = $false

    $enabledColumn = [System.Windows.Forms.DataGridViewCheckBoxColumn]::new()
    $enabledColumn.Name = 'Enabled'
    $enabledColumn.HeaderText = 'Enabled'
    $enabledColumn.Width = 70
    [void]$grid.Columns.Add($enabledColumn)

    foreach ($columnInfo in @(
        @{ Name = 'Name'; Header = 'Node'; Width = 120 }
        @{ Name = 'Address'; Header = 'Address'; Width = 180 }
        @{ Name = 'Color'; Header = 'Color'; Width = 110 }
    )) {
        $column = [System.Windows.Forms.DataGridViewTextBoxColumn]::new()
        $column.Name = $columnInfo.Name
        $column.HeaderText = $columnInfo.Header
        $column.Width = $columnInfo.Width
        [void]$grid.Columns.Add($column)
    }

    $grid.Add_CurrentCellDirtyStateChanged({
        if ($script:NMSettingsSuppress) { return }
        if ($script:NMSettingsTargetsGrid.IsCurrentCellDirty) {
            $script:NMSettingsTargetsGrid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) | Out-Null
        }
    })

    $grid.Add_CellValueChanged({
        param($sender, $eventArgs)
        if ($script:NMSettingsSuppress -or $eventArgs.RowIndex -lt 0) { return }
        $columnName = [string]$sender.Columns[$eventArgs.ColumnIndex].Name
        if ($columnName -ne 'Enabled') { return }
        $value = $sender.Rows[$eventArgs.RowIndex].Cells[$columnName].Value
        if (-not (Commit-NMTargetCell -RowIndex $eventArgs.RowIndex -ColumnName $columnName -Value $value)) {
            Sync-NMTargetsGrid
        }
    })

    $grid.Add_CellEndEdit({
        param($sender, $eventArgs)
        if ($script:NMSettingsSuppress -or $eventArgs.RowIndex -lt 0) { return }
        $columnName = [string]$sender.Columns[$eventArgs.ColumnIndex].Name
        if ($columnName -eq 'Enabled') { return }
        $value = $sender.Rows[$eventArgs.RowIndex].Cells[$columnName].Value
        if (-not (Commit-NMTargetCell -RowIndex $eventArgs.RowIndex -ColumnName $columnName -Value $value)) {
            Sync-NMTargetsGrid
        }
        else {
            Update-NMTargetColorPreview
        }
    })

    $grid.Add_SelectionChanged({ Update-NMTargetColorPreview })
    $Tab.Controls.Add($grid)
    $script:NMSettingsTargetsGrid = $grid

    $buttonX = 598
    $null = New-NMButton -Parent $Tab -Text 'Add' -Bounds @($buttonX, 14, 118, 30) -OnClick { Add-NMTargetFromSettings } -Primary
    $null = New-NMButton -Parent $Tab -Text 'Delete' -Bounds @($buttonX, 52, 118, 30) -OnClick { Remove-NMSelectedTarget }
    $null = New-NMButton -Parent $Tab -Text 'Move Up' -Bounds @($buttonX, 100, 118, 30) -OnClick { Move-NMSelectedTarget -Delta -1 }
    $null = New-NMButton -Parent $Tab -Text 'Move Down' -Bounds @($buttonX, 138, 118, 30) -OnClick { Move-NMSelectedTarget -Delta 1 }

    $null = New-NMLabel -Parent $Tab -Text 'Color Preview' -Bounds @($buttonX, 196, 118, 20) -ForeColor $script:NMColors.Muted
    $preview = [System.Windows.Forms.Panel]::new()
    $preview.Location = Get-NMPoint $buttonX 222
    $preview.Size = Get-NMSize 118 36
    $preview.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $preview.BackColor = $script:NMColors.Accent
    $Tab.Controls.Add($preview)
    $script:NMSettingsTargetColorPreview = $preview

    Sync-NMTargetsGrid
}

function Sync-NMColumnsControls {
    if (-not $script:NMSettingsColumnsList -or -not $script:NMSettingsColumnOrderList) {
        return
    }

    $script:NMSettingsSuppress = $true
    try {
        $script:NMSettingsColumnsList.Items.Clear()
        $script:NMSettingsColumnOrderList.Items.Clear()
        foreach ($column in @($script:NMConfig.Columns)) {
            $id = [string]$column.Id
            [void]$script:NMSettingsColumnsList.Items.Add($id, [bool]$column.Visible)
            [void]$script:NMSettingsColumnOrderList.Items.Add($id)
        }
        if ($script:NMSettingsColumnOrderList.Items.Count -gt 0) {
            $script:NMSettingsColumnOrderList.SelectedIndex = 0
        }
    }
    finally {
        $script:NMSettingsSuppress = $false
    }

    Update-NMColumnWidthEditor
}

function Update-NMColumnWidthEditor {
    if (-not $script:NMSettingsColumnWidthBox -or -not $script:NMSettingsColumnOrderList -or $script:NMSettingsColumnOrderList.SelectedIndex -lt 0) {
        return
    }

    $id = [string]$script:NMSettingsColumnOrderList.SelectedItem
    $column = Get-NMConfigColumn -Id $id
    if ($column) {
        $script:NMSettingsSuppress = $true
        try {
            $script:NMSettingsColumnWidthBox.Minimum = [decimal]$script:NMColumnDefinitions[$id].MinWidth
            $script:NMSettingsColumnWidthBox.Value = [decimal][int]$column.Width
            if ($script:NMSettingsColumnWidthBox.Tag -and $script:NMSettingsColumnWidthBox.Tag.PSObject.Properties['LastCommitted']) {
                $script:NMSettingsColumnWidthBox.Tag.LastCommitted = [decimal][int]$column.Width
            }
        }
        finally {
            $script:NMSettingsSuppress = $false
        }
    }
}

function Move-NMSelectedColumn {
    param([Parameter(Mandatory)][int]$Delta)

    $list = $script:NMSettingsColumnOrderList
    if (-not $list -or $list.SelectedIndex -lt 0) {
        return
    }

    $index = $list.SelectedIndex
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

function New-NMColumnsTab {
    param([Parameter(Mandatory)][System.Windows.Forms.TabPage]$Tab)

    $null = New-NMLabel -Parent $Tab -Text 'Visible Columns' -Bounds @(16, 16, 180, 22) -Font $script:NMFonts.SettingsBold
    $checked = [System.Windows.Forms.CheckedListBox]::new()
    $checked.Location = Get-NMPoint 16 44
    $checked.Size = Get-NMSize 220 240
    $checked.CheckOnClick = $true
    $checked.BackColor = $script:NMColors.Surface
    $checked.ForeColor = $script:NMColors.Text
    $checked.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Tab.Controls.Add($checked)
    $script:NMSettingsColumnsList = $checked

    $checked.Add_ItemCheck({
        param($sender, $eventArgs)
        if ($script:NMSettingsSuppress) { return }
        $id = [string]$sender.Items[$eventArgs.Index]
        $newVisible = ($eventArgs.NewValue -eq [System.Windows.Forms.CheckState]::Checked)
        if (-not $newVisible -and @($script:NMConfig.Columns | Where-Object { $_.Visible }).Count -le 1) {
            $eventArgs.NewValue = [System.Windows.Forms.CheckState]::Checked
            Set-NMSettingsFeedback -Message 'At least one column must stay visible.' -Error
            return
        }

        if (Get-NMConfigColumn -Id $id) {
            if (Invoke-NMConfigEditAndApply -RebuildGrid -Reason 'Column visibility changed' -Edit {
                param($config)
                foreach ($column in @($config.Columns)) {
                    if ([string]$column.Id -eq $id) {
                        $column.Visible = $newVisible
                        break
                    }
                }
            }) {
                Set-NMSettingsFeedback -Message 'Column visibility saved.'
            }
        }
    })

    $null = New-NMLabel -Parent $Tab -Text 'Column Order' -Bounds @(276, 16, 180, 22) -Font $script:NMFonts.SettingsBold
    $orderList = [System.Windows.Forms.ListBox]::new()
    $orderList.Location = Get-NMPoint 276 44
    $orderList.Size = Get-NMSize 220 190
    $orderList.BackColor = $script:NMColors.Surface
    $orderList.ForeColor = $script:NMColors.Text
    $orderList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $Tab.Controls.Add($orderList)
    $script:NMSettingsColumnOrderList = $orderList
    $orderList.Add_SelectedIndexChanged({ Update-NMColumnWidthEditor })

    $null = New-NMButton -Parent $Tab -Text 'Move Up' -Bounds @(512, 44, 118, 30) -OnClick { Move-NMSelectedColumn -Delta -1 }
    $null = New-NMButton -Parent $Tab -Text 'Move Down' -Bounds @(512, 82, 118, 30) -OnClick { Move-NMSelectedColumn -Delta 1 }

    $null = New-NMLabel -Parent $Tab -Text 'Selected Width' -Bounds @(276, 250, 120, 22) -ForeColor $script:NMColors.Muted
    $widthBox = [System.Windows.Forms.NumericUpDown]::new()
    $widthBox.Location = Get-NMPoint 398 247
    $widthBox.Size = Get-NMSize 98 24
    $widthBox.Minimum = 60
    $widthBox.Maximum = 2000
    $widthBox.BackColor = $script:NMColors.Surface
    $widthBox.ForeColor = $script:NMColors.Text
    $Tab.Controls.Add($widthBox)
    $script:NMSettingsColumnWidthBox = $widthBox
    Register-NMNumericCommit -Box $widthBox -OnCommit {
        param($box)
        if ($script:NMSettingsSuppress -or -not $script:NMSettingsColumnOrderList -or $script:NMSettingsColumnOrderList.SelectedIndex -lt 0) { return $false }
        $id = [string]$script:NMSettingsColumnOrderList.SelectedItem
        if (Get-NMConfigColumn -Id $id) {
            if (Invoke-NMConfigEditAndApply -RebuildGrid -Reason 'Column width changed' -Edit {
                param($config)
                foreach ($column in @($config.Columns)) {
                    if ([string]$column.Id -eq $id) {
                        $column.Width = [int]$box.Value
                        break
                    }
                }
            }) {
                Set-NMSettingsFeedback -Message 'Column width saved.'
                return $true
            }
        }
        return $false
    }

    Sync-NMColumnsControls
}

function New-NMNumericSetting {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int[]]$Bounds,
        [Parameter(Mandatory)][int]$Minimum,
        [Parameter(Mandatory)][int]$Maximum,
        [Parameter(Mandatory)][int]$Value,
        [Parameter(Mandatory)][scriptblock]$OnCommit
    )

    $null = New-NMLabel -Parent $Parent -Text $Label -Bounds @($Bounds[0], $Bounds[1] + 3, 250, 22)
    $box = [System.Windows.Forms.NumericUpDown]::new()
    $box.Location = Get-NMPoint ($Bounds[0] + 270) $Bounds[1]
    $box.Size = Get-NMSize $Bounds[2] $Bounds[3]
    $box.Minimum = $Minimum
    $box.Maximum = $Maximum
    $box.Value = $Value
    $box.BackColor = $script:NMColors.Surface
    $box.ForeColor = $script:NMColors.Text
    $box.Font = $script:NMFonts.Settings
    Register-NMNumericCommit -Box $box -OnCommit $OnCommit
    $Parent.Controls.Add($box)
    return $box
}

function New-NMCheckboxSetting {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][int[]]$Bounds,
        [bool]$Checked,
        [scriptblock]$OnChanged
    )

    $box = [System.Windows.Forms.CheckBox]::new()
    $box.Text = $Text
    $box.Location = Get-NMPoint $Bounds[0] $Bounds[1]
    $box.Size = Get-NMSize $Bounds[2] $Bounds[3]
    $box.Checked = $Checked
    $box.BackColor = $Parent.BackColor
    $box.ForeColor = $script:NMColors.Text
    $box.Font = $script:NMFonts.Settings
    if ($OnChanged) { $box.Add_Click($OnChanged) }
    $Parent.Controls.Add($box)
    return $box
}

function New-NMSettingsNumericRow {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][int]$X,
        [Parameter(Mandatory)][int]$Y,
        [Parameter(Mandatory)][int]$LabelWidth,
        [Parameter(Mandatory)][int]$Minimum,
        [Parameter(Mandatory)][int]$Maximum,
        [Parameter(Mandatory)][int]$Value,
        [Parameter(Mandatory)][scriptblock]$OnCommit
    )

    $null = New-NMLabel -Parent $Parent -Text $Label -Bounds @($X, ($Y + 3), $LabelWidth, 22) -ForeColor $script:NMColors.Text

    $box = [System.Windows.Forms.NumericUpDown]::new()
    $box.Location = Get-NMPoint ($X + $LabelWidth + 12) $Y
    $box.Size = Get-NMSize 96 24
    $box.Minimum = $Minimum
    $box.Maximum = $Maximum
    $box.Value = $Value
    $box.BackColor = $script:NMColors.Surface
    $box.ForeColor = $script:NMColors.Text
    $box.Font = $script:NMFonts.Settings
    Register-NMNumericCommit -Box $box -OnCommit $OnCommit
    $Parent.Controls.Add($box)
    return $box
}

function New-NMTimingTab {
    param([Parameter(Mandatory)][System.Windows.Forms.TabPage]$Tab)

    $null = New-NMNumericSetting -Parent $Tab -Label 'Refresh interval (ms)' -Bounds @(22, 24, 110, 24) -Minimum 250 -Maximum 60000 -Value ([int]$script:NMConfig.RefreshMilliseconds) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Refresh interval changed' -Edit {
            param($config)
            $config.RefreshMilliseconds = [int]$box.Value
        }) {
            Set-NMSettingsFeedback -Message 'Refresh interval saved.'
            return $true
        }
        return $false
    }

    $null = New-NMNumericSetting -Parent $Tab -Label 'Ping timeout (ms)' -Bounds @(22, 64, 110, 24) -Minimum 100 -Maximum 60000 -Value ([int]$script:NMConfig.PingTimeoutMilliseconds) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Ping timeout changed' -Edit {
            param($config)
            $config.PingTimeoutMilliseconds = [int]$box.Value
        }) {
            Set-NMSettingsFeedback -Message 'Ping timeout saved.'
            return $true
        }
        return $false
    }

    $null = New-NMNumericSetting -Parent $Tab -Label 'History length' -Bounds @(22, 104, 110, 24) -Minimum 4 -Maximum 60 -Value ([int]$script:NMConfig.HistoryLength) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'History length changed' -Edit {
            param($config)
            $config.HistoryLength = [int]$box.Value
        }) {
            Set-NMSettingsFeedback -Message 'History length saved.'
            return $true
        }
        return $false
    }

    $null = New-NMCheckboxSetting -Parent $Tab -Text 'Auto-start monitoring on launch' -Bounds @(22, 152, 260, 28) -Checked ([bool]$script:NMConfig.AutoStart) -OnChanged {
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.AutoStart
        $checked = [bool]$this.Checked
        if (Invoke-NMConfigEditAndApply -Reason 'Auto-start changed' -Edit {
            param($config)
            $config.AutoStart = $checked
        }) {
            if ($script:NMConfig.AutoStart -and -not $script:NMPingTimer.Enabled) {
                Start-NMMonitoring
                Invoke-NMPingCycle
            }
            Set-NMSettingsFeedback -Message 'Auto-start setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $this.Checked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    }
}

function New-NMHealthTab {
    param([Parameter(Mandatory)][System.Windows.Forms.TabPage]$Tab)

    $leftX = 24
    $rightX = 392
    $labelWidth = 210

    $null = New-NMLabel -Parent $Tab -Text 'Health' -Bounds @($leftX, 24, 220, 24) -Font $script:NMFonts.SettingsBold
    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'DOWN after failed pings' -X $leftX -Y 62 -LabelWidth $labelWidth -Minimum 1 -Maximum 20 -Value ([int]$script:NMConfig.Health.DownFailures) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Health threshold changed' -Edit {
            param($config)
            $config.Health.DownFailures = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Orange after failed pings' -X $leftX -Y 102 -LabelWidth $labelWidth -Minimum 1 -Maximum 20 -Value ([int]$script:NMConfig.Health.OrangeFailures) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Health threshold changed' -Edit {
            param($config)
            $config.Health.OrangeFailures = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Orange rolling loss (%)' -X $leftX -Y 142 -LabelWidth $labelWidth -Minimum 0 -Maximum 100 -Value ([int]$script:NMConfig.Health.OrangeLossPercent) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Health threshold changed' -Edit {
            param($config)
            $config.Health.OrangeLossPercent = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMLabel -Parent $Tab -Text 'RTT' -Bounds @($rightX, 24, 220, 24) -Font $script:NMFonts.SettingsBold
    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Green max (ms)' -X $rightX -Y 62 -LabelWidth 180 -Minimum 0 -Maximum 60000 -Value ([int]$script:NMConfig.RttThresholds.GreenMax) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'RTT threshold changed' -Edit {
            param($config)
            $config.RttThresholds.GreenMax = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Yellow max (ms)' -X $rightX -Y 102 -LabelWidth 180 -Minimum 1 -Maximum 60000 -Value ([int]$script:NMConfig.RttThresholds.YellowMax) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'RTT threshold changed' -Edit {
            param($config)
            $config.RttThresholds.YellowMax = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Orange max (ms)' -X $rightX -Y 142 -LabelWidth 180 -Minimum 1 -Maximum 60000 -Value ([int]$script:NMConfig.RttThresholds.OrangeMax) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'RTT threshold changed' -Edit {
            param($config)
            $config.RttThresholds.OrangeMax = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMLabel -Parent $Tab -Text 'Loss' -Bounds @($rightX, 202, 220, 24) -Font $script:NMFonts.SettingsBold
    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Yellow max (%)' -X $rightX -Y 240 -LabelWidth 180 -Minimum 0 -Maximum 100 -Value ([int]$script:NMConfig.LossThresholds.YellowMax) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Loss threshold changed' -Edit {
            param($config)
            $config.LossThresholds.YellowMax = [int]$box.Value
        }) { return $true }
        return $false
    }

    $null = New-NMSettingsNumericRow -Parent $Tab -Label 'Orange max (%)' -X $rightX -Y 280 -LabelWidth 180 -Minimum 0 -Maximum 100 -Value ([int]$script:NMConfig.LossThresholds.OrangeMax) -OnCommit {
        param($box)
        if (Invoke-NMConfigEditAndApply -ResetMonitor -Reason 'Loss threshold changed' -Edit {
            param($config)
            $config.LossThresholds.OrangeMax = [int]$box.Value
        }) { return $true }
        return $false
    }
}

function New-NMGeneralTab {
    param([Parameter(Mandatory)][System.Windows.Forms.TabPage]$Tab)

    $null = New-NMCheckboxSetting -Parent $Tab -Text 'Always on top' -Bounds @(22, 26, 220, 28) -Checked ([bool]$script:NMConfig.AlwaysOnTop) -OnChanged {
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.AlwaysOnTop
        $checked = [bool]$this.Checked
        if (Invoke-NMConfigEditAndApply -Reason 'Always on top changed' -Edit {
            param($config)
            $config.AlwaysOnTop = $checked
        }) {
            Apply-NMAlwaysOnTopState
            Set-NMSettingsFeedback -Message 'Always-on-top setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $this.Checked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    }

    $null = New-NMCheckboxSetting -Parent $Tab -Text 'Debug logging' -Bounds @(22, 64, 220, 28) -Checked ([bool]$script:NMConfig.DebugMode) -OnChanged {
        if ($script:NMSettingsSuppress) { return }
        $previous = [bool]$script:NMConfig.DebugMode
        $checked = [bool]$this.Checked
        if (Invoke-NMConfigEditAndApply -Reason 'Debug mode changed' -Edit {
            param($config)
            $config.DebugMode = $checked
        }) {
            Set-NMSettingsFeedback -Message 'Debug mode setting saved.'
        }
        else {
            $script:NMSettingsSuppress = $true
            try { $this.Checked = $previous }
            finally { $script:NMSettingsSuppress = $false }
        }
    }

    $null = New-NMButton -Parent $Tab -Text 'Reset Window Position' -Bounds @(22, 118, 172, 32) -OnClick {
        Set-NMDefaultWindowLocation
        $bounds = $script:NMForm.Bounds
        if (Invoke-NMConfigEditAndApply -Reason 'Window position reset' -Edit {
            param($config)
            $config.Window.Maximized = $false
            $config.Window.Width = [int]$bounds.Width
            $config.Window.Height = [int]$bounds.Height
            $config.Window.X = [int]$bounds.X
            $config.Window.Y = [int]$bounds.Y
        }) {
            Set-NMSettingsFeedback -Message 'Window position reset.'
        }
    }

    $null = New-NMButton -Parent $Tab -Text 'Reset to Defaults' -Bounds @(22, 168, 172, 32) -OnClick {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $script:NMSettingsForm,
            'Reset Network Monitor settings to defaults?',
            'Reset to Defaults',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        $defaultConfig = Get-NMDefaultConfig
        try {
            Save-NMConfig -Config $defaultConfig
        }
        catch {
            Show-NMConfigError -Message $_.Exception.Message
            return
        }

        $script:NMConfig = $defaultConfig
        $script:NMGeneration++
        Reset-NMMonitorState
        Apply-NMAlwaysOnTopState
        Apply-NMColumnsToGrid
        Update-NMGridFromState
        Set-NMDefaultWindowLocation
        if ($script:NMConfig.AutoStart) {
            Start-NMMonitoring
            Invoke-NMPingCycle
        }
        Set-NMSettingsFeedback -Message 'Defaults restored.'
        $script:NMSettingsForm.Close()
    } -Primary
}

function Build-NMSettingsForm {
    $form = New-NMAppWindow `
        -Name 'NetworkMonitorSettingsForm' `
        -Title 'Network Monitor Settings' `
        -Size (Get-NMSize 800 470) `
        -MinimumSize (Get-NMSize 760 430) `
        -ShowInTaskbar $false `
        -TopMost ([bool]$script:NMConfig.AlwaysOnTop) `
        -Resizable $false

    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.Font = $script:NMFonts.Settings

    if ($script:NMForm) {
        $ownerBounds = $script:NMForm.Bounds
        $form.Location = Get-NMPoint ([math]::Max(0, $ownerBounds.Left + 36)) ([math]::Max(0, $ownerBounds.Top - 30))
    }
    else {
        $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $form.Location = Get-NMPoint ([int]($workingArea.Left + 80)) ([int]($workingArea.Top + 80))
    }

    $targetForm = $form
    $title = New-NMTitleBar -Form $form -Title 'Network Monitor Settings' -Height 46 -Buttons @(
        [ordered]@{ Key = 'Close'; Kind = 'Close'; ToolTip = 'Close'; OnClick = { $targetForm.Close() }.GetNewClosure() }
    )
    $script:NMSettingsCloseButton = $title.Buttons['Close']
    $form.Controls.Add($title.Panel)

    $tabs = [System.Windows.Forms.TabControl]::new()
    $tabs.Name = 'NMSettingsTabs'
    $tabs.Location = Get-NMPoint 12 58
    $tabs.Size = Get-NMSize 772 342
    $tabs.Anchor = 'Top, Bottom, Left, Right'
    $tabs.BackColor = $script:NMColors.Window
    $tabs.ForeColor = $script:NMColors.Text
    $tabs.Font = $script:NMFonts.Settings
    Use-NMTabTheme -TabControl $tabs
    $form.Controls.Add($tabs)

    foreach ($tabName in @('Targets', 'Columns', 'Timing', 'Health', 'General')) {
        $tab = [System.Windows.Forms.TabPage]::new()
        $tab.Text = $tabName
        $tab.BackColor = $script:NMColors.Window
        $tab.ForeColor = $script:NMColors.Text
        [void]$tabs.TabPages.Add($tab)

        switch ($tabName) {
            'Targets' { New-NMTargetsTab -Tab $tab }
            'Columns' { New-NMColumnsTab -Tab $tab }
            'Timing' { New-NMTimingTab -Tab $tab }
            'Health' { New-NMHealthTab -Tab $tab }
            'General' { New-NMGeneralTab -Tab $tab }
        }
    }

    $script:NMSettingsFeedbackLabel = New-NMLabel -Parent $form -Text '' -Bounds @(14, 412, 740, 24) -ForeColor $script:NMColors.Muted
    $script:NMSettingsFeedbackLabel.BackColor = $script:NMColors.Window
    $script:NMSettingsFeedbackLabel.Visible = $false

    $form.Add_FormClosed({
        param($sender, $eventArgs)
        [void]$eventArgs

        if ($script:NMSettingsForm -eq $sender) {
            $script:NMSettingsForm = $null
        }

        $script:NMSettingsTargetsGrid = $null
        $script:NMSettingsColumnsList = $null
        $script:NMSettingsColumnOrderList = $null
        $script:NMSettingsColumnWidthBox = $null
        $script:NMSettingsFeedbackLabel = $null
        $script:NMSettingsCloseButton = $null
        if ($script:NMSettingsButton -and (-not $script:NMSettingsForm -or $script:NMSettingsForm.IsDisposed)) {
            Set-NMIconButtonActive -Button $script:NMSettingsButton -Active $false
        }
    })

    return $form
}

function Show-NMSettingsForm {
    if ($script:NMSettingsForm -and -not $script:NMSettingsForm.IsDisposed) {
        $script:NMSettingsForm.Activate()
        $script:NMSettingsForm.Focus()
        return
    }

    $form = Build-NMSettingsForm
    $script:NMSettingsForm = $form
    if ($script:NMSettingsButton) {
        Set-NMIconButtonActive -Button $script:NMSettingsButton -Active $true
    }

    [void]$form.Show($script:NMForm)
}
