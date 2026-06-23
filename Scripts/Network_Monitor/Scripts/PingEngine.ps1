function Initialize-NMPingEngine {
    $script:NMPingCycleBusy = $false
    $script:NMPingCycleJobs = @()
    $script:NMPingCycleGeneration = 0

    $script:NMPingTimer = [System.Windows.Forms.Timer]::new()
    $script:NMPingTimer.Interval = [int]$script:NMConfig.RefreshMilliseconds
    $script:NMPingTimer.Add_Tick({
        Invoke-NMPingCycle
    })

    $script:NMPingCompletionTimer = [System.Windows.Forms.Timer]::new()
    $script:NMPingCompletionTimer.Interval = 50
    $script:NMPingCompletionTimer.Add_Tick({
        Complete-NMPingCycleIfReady
    })
}

function Update-NMPingTimerInterval {
    if ($script:NMPingTimer) {
        $script:NMPingTimer.Interval = [int]$script:NMConfig.RefreshMilliseconds
    }
}

function Start-NMMonitoring {
    if (-not $script:NMPingTimer) {
        return
    }

    Update-NMPingTimerInterval
    if (-not $script:NMPingTimer.Enabled) {
        $script:NMPingTimer.Start()
    }
}

function Stop-NMMonitoring {
    if ($script:NMPingTimer) {
        $script:NMPingTimer.Stop()
    }
    if ($script:NMPingCompletionTimer) {
        $script:NMPingCompletionTimer.Stop()
    }

    Clear-NMPingCycleJobs
    $script:NMPingCycleBusy = $false
}

function Clear-NMPingCycleJobs {
    foreach ($job in @($script:NMPingCycleJobs)) {
        if ($job.Ping) {
            try { $job.Ping.Dispose() }
            catch { }
        }
    }

    $script:NMPingCycleJobs = @()
}

function New-NMFailedPingJob {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Address,
        [AllowEmptyString()][string]$ErrorMessage = ''
    )

    return [pscustomobject]@{
        Name = $Name
        Address = $Address
        Ping = $null
        Task = $null
        StartError = $ErrorMessage
    }
}

function Invoke-NMPingCycle {
    if (-not $script:NMPingTimer -or $script:NMPingCycleBusy) {
        return
    }

    $targets = @(Get-NMEnabledTargets)
    if ($targets.Count -lt 1) {
        return
    }

    Clear-NMPingCycleJobs
    $script:NMPingCycleGeneration = [int]$script:NMGeneration
    $jobs = @()

    foreach ($target in $targets) {
        $name = [string]$target.Name
        $address = [string]$target.Address
        $ping = [System.Net.NetworkInformation.Ping]::new()

        try {
            $task = $ping.SendPingAsync($address, [int]$script:NMConfig.PingTimeoutMilliseconds)
            $jobs += [pscustomobject]@{
                Name = $name
                Address = $address
                Ping = $ping
                Task = $task
                StartError = ''
            }
        }
        catch {
            $ping.Dispose()
            $jobs += New-NMFailedPingJob -Name $name -Address $address -ErrorMessage $_.Exception.Message
        }
    }

    $script:NMPingCycleJobs = @($jobs)
    $script:NMPingCycleBusy = $true
    Complete-NMPingCycleIfReady
    if ($script:NMPingCycleBusy -and $script:NMPingCompletionTimer) {
        $script:NMPingCompletionTimer.Start()
    }
}

function Complete-NMPingCycleIfReady {
    if (-not $script:NMPingCycleBusy) {
        if ($script:NMPingCompletionTimer) {
            $script:NMPingCompletionTimer.Stop()
        }
        return
    }

    foreach ($job in @($script:NMPingCycleJobs)) {
        if ($job.Task -and -not $job.Task.IsCompleted) {
            return
        }
    }

    if ($script:NMPingCompletionTimer) {
        $script:NMPingCompletionTimer.Stop()
    }

    $results = [System.Collections.ArrayList]::new()
    foreach ($job in @($script:NMPingCycleJobs)) {
        $entry = [ordered]@{
            Name = [string]$job.Name
            Address = [string]$job.Address
            Success = $false
            RttMs = $null
            Bytes = $null
            Ttl = $null
        }

        try {
            if ($job.StartError) {
                Write-NMDebugLog -Message ("Unable to start ping for {0}: {1}" -f $job.Name, $job.StartError)
            }
            elseif ($job.Task) {
                $reply = $job.Task.GetAwaiter().GetResult()
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $entry.Success = $true
                    $entry.RttMs = [int]$reply.RoundtripTime
                    $entry.Bytes = [int]$reply.Buffer.Length
                    if ($reply.Options) {
                        $entry.Ttl = [int]$reply.Options.Ttl
                    }
                }
            }
        }
        catch {
            Write-NMDebugLog -Message ("Ping result error for {0}: {1}" -f $job.Name, $_.Exception.Message)
        }
        finally {
            if ($job.Ping) {
                $job.Ping.Dispose()
            }
        }

        [void]$results.Add([pscustomobject]$entry)
    }

    $generation = [int]$script:NMPingCycleGeneration
    $script:NMPingCycleJobs = @()
    $script:NMPingCycleBusy = $false

    if ($generation -ne [int]$script:NMGeneration) {
        if ($script:NMPingTimer -and $script:NMPingTimer.Enabled) {
            Invoke-NMPingCycle
        }
        return
    }

    Invoke-NMOnPingResults -Results @($results)
}
