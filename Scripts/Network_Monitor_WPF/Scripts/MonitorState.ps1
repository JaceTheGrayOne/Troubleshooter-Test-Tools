function Get-NMEnabledTargets {
    if (-not $script:NMConfig) {
        return @()
    }

    return @($script:NMConfig.Targets | Where-Object { $_.Enabled })
}

function Get-NMTargetByName {
    param([Parameter(Mandatory)][string]$Name)

    foreach ($target in @($script:NMConfig.Targets)) {
        if ([string]$target.Name -eq $Name) {
            return $target
        }
    }

    return $null
}

function New-NMTargetState {
    return [ordered]@{
        HasSample = $false
        LatestSuccess = $false
        LatestRttMs = $null
        LatestBytes = $null
        LatestTtl = $null
        ConsecutiveFailures = 0
        LossPercent = 0.0
        History = [System.Collections.ArrayList]::new()
    }
}

function Initialize-NMMonitorState {
    $script:NMTargetStates = @{}
    foreach ($target in @($script:NMConfig.Targets)) {
        $script:NMTargetStates[[string]$target.Name] = New-NMTargetState
    }
}

function Reset-NMMonitorState {
    Initialize-NMMonitorState
}

function Update-NMStateFromPingResults {
    param([AllowNull()]$Results)

    foreach ($result in @($Results)) {
        $name = [string]$result.Name
        if (-not $script:NMTargetStates.ContainsKey($name)) {
            continue
        }

        $state = $script:NMTargetStates[$name]
        $success = [bool]$result.Success

        $state.HasSample = $true
        $state.LatestSuccess = $success
        $state.LatestRttMs = if ($success) { [int]$result.RttMs } else { $null }
        $state.LatestBytes = if ($success -and $null -ne $result.Bytes) { [int]$result.Bytes } else { $null }
        $state.LatestTtl = if ($success -and $null -ne $result.Ttl) { [int]$result.Ttl } else { $null }
        $state.ConsecutiveFailures = if ($success) { 0 } else { [int]$state.ConsecutiveFailures + 1 }

        [void]$state.History.Add($success)
        while ($state.History.Count -gt [int]$script:NMConfig.HistoryLength) {
            $state.History.RemoveAt(0)
        }

        if ($state.History.Count -gt 0) {
            $failed = 0
            foreach ($sample in @($state.History)) {
                if (-not [bool]$sample) {
                    $failed++
                }
            }
            $state.LossPercent = [math]::Round(($failed * 100.0) / $state.History.Count, 1)
        }
        else {
            $state.LossPercent = 0.0
        }
    }
}

function Get-NMStatusText {
    param([Parameter(Mandatory)][hashtable]$State)

    if ([int]$State.ConsecutiveFailures -ge [int]$script:NMConfig.Health.DownFailures) {
        return 'DOWN'
    }

    return 'UP'
}

function Get-NMHealthName {
    param([Parameter(Mandatory)][hashtable]$State)

    if ([int]$State.ConsecutiveFailures -ge [int]$script:NMConfig.Health.DownFailures) {
        return 'Red'
    }

    if ([double]$State.LossPercent -ge [double]$script:NMConfig.Health.OrangeLossPercent -or
        [int]$State.ConsecutiveFailures -ge [int]$script:NMConfig.Health.OrangeFailures) {
        return 'Orange'
    }

    if (($State.HasSample -and -not $State.LatestSuccess) -or [double]$State.LossPercent -gt 0) {
        return 'Yellow'
    }

    return 'Green'
}

function Get-NMRttHealthName {
    param([Parameter(Mandatory)][hashtable]$State)

    if (-not $State.HasSample -or -not $State.LatestSuccess -or $null -eq $State.LatestRttMs) {
        return 'Red'
    }

    $rtt = [int]$State.LatestRttMs
    if ($rtt -le [int]$script:NMConfig.RttThresholds.GreenMax) { return 'Green' }
    if ($rtt -le [int]$script:NMConfig.RttThresholds.YellowMax) { return 'Yellow' }
    if ($rtt -le [int]$script:NMConfig.RttThresholds.OrangeMax) { return 'Orange' }
    return 'Red'
}

function Get-NMLossHealthName {
    param([Parameter(Mandatory)][hashtable]$State)

    $loss = [double]$State.LossPercent
    if ($loss -le 0) { return 'Green' }
    if ($loss -le [double]$script:NMConfig.LossThresholds.YellowMax) { return 'Yellow' }
    if ($loss -le [double]$script:NMConfig.LossThresholds.OrangeMax) { return 'Orange' }
    return 'Red'
}

function Get-NMRttText {
    param([Parameter(Mandatory)][hashtable]$State)

    if (-not $State.HasSample) {
        return 'NA'
    }
    if (-not $State.LatestSuccess) {
        return 'timeout'
    }
    return ('{0} ms' -f [int]$State.LatestRttMs)
}

function Get-NMLossText {
    param([Parameter(Mandatory)][hashtable]$State)

    return ('{0:N1}%' -f [double]$State.LossPercent)
}

function Get-NMNeutralValue {
    return '--'
}
