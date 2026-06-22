$script:NMColumnDefinitions = [ordered]@{
    Node = @{
        Header = 'Node'
        DefaultVisible = $true
        DefaultWidth = 120
        MinWidth = 100
    }
    Address = @{
        Header = 'Address'
        DefaultVisible = $true
        DefaultWidth = 250
        MinWidth = 190
    }
    Status = @{
        Header = 'Status'
        DefaultVisible = $true
        DefaultWidth = 150
        MinWidth = 130
    }
    RTT = @{
        Header = 'RTT'
        DefaultVisible = $true
        DefaultWidth = 130
        MinWidth = 105
    }
    Loss = @{
        Header = 'Loss'
        DefaultVisible = $true
        DefaultWidth = 130
        MinWidth = 105
    }
    History = @{
        Header = 'History'
        DefaultVisible = $true
        DefaultWidth = 260
        MinWidth = 180
    }
    TTL = @{
        Header = 'TTL'
        DefaultVisible = $false
        DefaultWidth = 90
        MinWidth = 70
    }
    Bytes = @{
        Header = 'Bytes'
        DefaultVisible = $false
        DefaultWidth = 95
        MinWidth = 80
    }
}

function Get-NMSupportedColumnIds {
    return @($script:NMColumnDefinitions.Keys)
}

function Test-NMMapKey {
    param(
        [AllowNull()]$Map,
        [Parameter(Mandatory)][string]$Key
    )

    if (-not ($Map -is [System.Collections.IDictionary])) {
        return $false
    }

    return $Map.Contains($Key)
}

function Test-NMIntegerInRange {
    param(
        [AllowNull()]$Value,
        [int]$Minimum,
        [int]$Maximum
    )

    if ($null -eq $Value) {
        return $false
    }

    try {
        $number = [int]$Value
    }
    catch {
        return $false
    }

    return ($number -ge $Minimum -and $number -le $Maximum)
}

function Test-NMIPv4Address {
    param([AllowNull()][string]$Address)

    if ([string]::IsNullOrWhiteSpace($Address)) {
        return $false
    }

    $parsed = [System.Net.IPAddress]::None
    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$parsed)) {
        return $false
    }

    return ($parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork)
}

function Test-NMHostName {
    param([AllowNull()][string]$HostName)

    if ([string]::IsNullOrWhiteSpace($HostName)) {
        return $false
    }

    $value = $HostName.Trim()
    if ($value.Length -gt 253) {
        return $false
    }

    if ($value.EndsWith('.')) {
        $value = $value.Substring(0, $value.Length - 1)
    }

    foreach ($label in $value.Split('.')) {
        if ($label.Length -lt 1 -or $label.Length -gt 63) {
            return $false
        }

        if ($label -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$') {
            return $false
        }
    }

    return $true
}

function Test-NMAddress {
    param([AllowNull()][string]$Address)

    return ((Test-NMIPv4Address -Address $Address) -or (Test-NMHostName -HostName $Address))
}

function Test-NMHtmlColor {
    param([AllowNull()][string]$Color)

    return (-not [string]::IsNullOrWhiteSpace($Color) -and $Color -match '^#[0-9A-Fa-f]{6}$')
}

function Add-NMConfigError {
    param(
        [Parameter(Mandatory)][object]$Errors,
        [Parameter(Mandatory)][string]$Message
    )

    $Errors.Add($Message) | Out-Null
}

function Test-NMConfig {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Config,
        [ref]$Errors
    )

    $localErrors = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-NMMapKey -Map $Config -Key 'Targets') -or @($Config.Targets).Count -lt 1) {
        Add-NMConfigError -Errors $localErrors -Message 'At least one target is required.'
    }
    else {
        $names = @{}
        $enabledCount = 0
        foreach ($target in @($Config.Targets)) {
            if (-not ($target -is [System.Collections.IDictionary])) {
                Add-NMConfigError -Errors $localErrors -Message 'Every target must be an object.'
                continue
            }

            $name = [string]$target.Name
            if ([string]::IsNullOrWhiteSpace($name)) {
                Add-NMConfigError -Errors $localErrors -Message 'Target names cannot be blank.'
            }
            else {
                $key = $name.ToUpperInvariant()
                if ($names.ContainsKey($key)) {
                    Add-NMConfigError -Errors $localErrors -Message ("Duplicate target name '{0}'." -f $name)
                }
                $names[$key] = $true
            }

            if (-not (Test-NMAddress -Address ([string]$target.Address))) {
                Add-NMConfigError -Errors $localErrors -Message ("Invalid address for target '{0}'." -f $name)
            }

            if (-not (Test-NMHtmlColor -Color ([string]$target.Color))) {
                Add-NMConfigError -Errors $localErrors -Message ("Invalid color for target '{0}'." -f $name)
            }

            if (-not ($target.Enabled -is [bool])) {
                Add-NMConfigError -Errors $localErrors -Message ("Enabled must be true or false for target '{0}'." -f $name)
            }
            elseif ($target.Enabled) {
                $enabledCount++
            }
        }

        if ($enabledCount -lt 1) {
            Add-NMConfigError -Errors $localErrors -Message 'At least one target must be enabled.'
        }
    }

    foreach ($entry in @(
        @{ Name = 'RefreshMilliseconds'; Min = 250; Max = 60000 }
        @{ Name = 'PingTimeoutMilliseconds'; Min = 100; Max = 60000 }
        @{ Name = 'HistoryLength'; Min = 4; Max = 60 }
    )) {
        if (-not (Test-NMIntegerInRange -Value $Config[$entry.Name] -Minimum $entry.Min -Maximum $entry.Max)) {
            Add-NMConfigError -Errors $localErrors -Message ("{0} must be between {1} and {2}." -f $entry.Name, $entry.Min, $entry.Max)
        }
    }

    foreach ($boolName in @('AlwaysOnTop', 'AutoStart', 'DebugMode')) {
        if (-not ($Config[$boolName] -is [bool])) {
            Add-NMConfigError -Errors $localErrors -Message ("{0} must be true or false." -f $boolName)
        }
    }

    if (-not ($Config.Window -is [System.Collections.IDictionary])) {
        Add-NMConfigError -Errors $localErrors -Message 'Window settings are invalid.'
    }
    else {
        if (-not (Test-NMIntegerInRange -Value $Config.Window.Width -Minimum 760 -Maximum 10000)) {
            Add-NMConfigError -Errors $localErrors -Message 'Window width is invalid.'
        }
        if (-not (Test-NMIntegerInRange -Value $Config.Window.Height -Minimum 220 -Maximum 6000)) {
            Add-NMConfigError -Errors $localErrors -Message 'Window height is invalid.'
        }
        foreach ($pointName in @('X', 'Y')) {
            if ($null -ne $Config.Window[$pointName]) {
                try { [void][int]$Config.Window[$pointName] }
                catch { Add-NMConfigError -Errors $localErrors -Message ("Window {0} is invalid." -f $pointName) }
            }
        }
        if (-not ($Config.Window.Maximized -is [bool])) {
            Add-NMConfigError -Errors $localErrors -Message 'Window maximized state is invalid.'
        }
    }

    if (-not ($Config.Columns -is [array]) -or @($Config.Columns).Count -lt 1) {
        Add-NMConfigError -Errors $localErrors -Message 'Column settings are required.'
    }
    else {
        $supported = Get-NMSupportedColumnIds
        $columnIds = @{}
        $visibleCount = 0
        foreach ($column in @($Config.Columns)) {
            if (-not ($column -is [System.Collections.IDictionary])) {
                Add-NMConfigError -Errors $localErrors -Message 'Every column setting must be an object.'
                continue
            }

            $id = [string]$column.Id
            if ($id -notin $supported) {
                Add-NMConfigError -Errors $localErrors -Message ("Unsupported column '{0}'." -f $id)
                continue
            }
            if ($columnIds.ContainsKey($id)) {
                Add-NMConfigError -Errors $localErrors -Message ("Duplicate column '{0}'." -f $id)
            }
            $columnIds[$id] = $true

            if (-not ($column.Visible -is [bool])) {
                Add-NMConfigError -Errors $localErrors -Message ("Column '{0}' visibility is invalid." -f $id)
            }
            elseif ($column.Visible) {
                $visibleCount++
            }

            $minimumWidth = [int]$script:NMColumnDefinitions[$id].MinWidth
            if (-not (Test-NMIntegerInRange -Value $column.Width -Minimum $minimumWidth -Maximum 2000)) {
                Add-NMConfigError -Errors $localErrors -Message ("Column '{0}' width is invalid." -f $id)
            }
        }

        foreach ($id in $supported) {
            if (-not $columnIds.ContainsKey($id)) {
                Add-NMConfigError -Errors $localErrors -Message ("Column '{0}' is missing." -f $id)
            }
        }

        if ($visibleCount -lt 1) {
            Add-NMConfigError -Errors $localErrors -Message 'At least one column must be visible.'
        }
    }

    if (-not ($Config.Health -is [System.Collections.IDictionary])) {
        Add-NMConfigError -Errors $localErrors -Message 'Health thresholds are invalid.'
    }
    else {
        if (-not (Test-NMIntegerInRange -Value $Config.Health.DownFailures -Minimum 1 -Maximum 20)) {
            Add-NMConfigError -Errors $localErrors -Message 'Down failure threshold is invalid.'
        }
        if (-not (Test-NMIntegerInRange -Value $Config.Health.OrangeFailures -Minimum 1 -Maximum 20)) {
            Add-NMConfigError -Errors $localErrors -Message 'Orange failure threshold is invalid.'
        }
        if (-not (Test-NMIntegerInRange -Value $Config.Health.OrangeLossPercent -Minimum 0 -Maximum 100)) {
            Add-NMConfigError -Errors $localErrors -Message 'Orange loss threshold is invalid.'
        }
    }

    if (-not ($Config.RttThresholds -is [System.Collections.IDictionary])) {
        Add-NMConfigError -Errors $localErrors -Message 'RTT thresholds are invalid.'
    }
    else {
        $rttGreen = [int]$Config.RttThresholds.GreenMax
        $rttYellow = [int]$Config.RttThresholds.YellowMax
        $rttOrange = [int]$Config.RttThresholds.OrangeMax
        if (-not (Test-NMIntegerInRange -Value $rttGreen -Minimum 0 -Maximum 60000) -or
            -not (Test-NMIntegerInRange -Value $rttYellow -Minimum 1 -Maximum 60000) -or
            -not (Test-NMIntegerInRange -Value $rttOrange -Minimum 1 -Maximum 60000) -or
            -not ($rttGreen -lt $rttYellow -and $rttYellow -lt $rttOrange)) {
            Add-NMConfigError -Errors $localErrors -Message 'RTT thresholds must increase from green to orange.'
        }
    }

    if (-not ($Config.LossThresholds -is [System.Collections.IDictionary])) {
        Add-NMConfigError -Errors $localErrors -Message 'Loss thresholds are invalid.'
    }
    else {
        $lossYellow = [int]$Config.LossThresholds.YellowMax
        $lossOrange = [int]$Config.LossThresholds.OrangeMax
        if (-not (Test-NMIntegerInRange -Value $lossYellow -Minimum 0 -Maximum 100) -or
            -not (Test-NMIntegerInRange -Value $lossOrange -Minimum 0 -Maximum 100) -or
            -not ($lossYellow -le $lossOrange)) {
            Add-NMConfigError -Errors $localErrors -Message 'Loss thresholds must be between 0 and 100 and increase from yellow to orange.'
        }
    }

    if ($PSBoundParameters.ContainsKey('Errors')) {
        $Errors.Value = @($localErrors)
    }

    return ($localErrors.Count -eq 0)
}
