function Initialize-NMPingEngine {
    $script:NMPingWorker = [System.ComponentModel.BackgroundWorker]::new()
    $script:NMPingWorker.WorkerSupportsCancellation = $false

    $script:NMPingWorker.Add_DoWork({
        param($sender, $eventArgs)
        [void]$sender

        $argument = $eventArgs.Argument
        $errors = [System.Collections.ArrayList]::new()
        $jobs = [System.Collections.ArrayList]::new()

        foreach ($target in @($argument.Targets)) {
            $ping = [System.Net.NetworkInformation.Ping]::new()
            try {
                $task = $ping.SendPingAsync([string]$target.Address, [int]$argument.TimeoutMs)
                [void]$jobs.Add([pscustomobject]@{
                    Name = [string]$target.Name
                    Address = [string]$target.Address
                    Ping = $ping
                    Task = $task
                })
            }
            catch {
                $ping.Dispose()
                [void]$errors.Add("Unable to start ping for $($target.Name): $($_.Exception.Message)")
                [void]$jobs.Add([pscustomobject]@{
                    Name = [string]$target.Name
                    Address = [string]$target.Address
                    Ping = $null
                    Task = $null
                })
            }
        }

        $tasks = @($jobs | Where-Object { $null -ne $_.Task } | ForEach-Object { $_.Task })
        if ($tasks.Count -gt 0) {
            try {
                [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]$tasks)
            }
            catch {
                [void]$errors.Add("Ping cycle wait error: $($_.Exception.Message)")
            }
        }

        $results = [System.Collections.ArrayList]::new()
        foreach ($job in @($jobs)) {
            $entry = [ordered]@{
                Name = [string]$job.Name
                Address = [string]$job.Address
                Success = $false
                RttMs = $null
                Bytes = $null
                Ttl = $null
            }

            try {
                if ($job.Task) {
                    $reply = $job.Task.Result
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
                [void]$errors.Add("Ping result error for $($job.Name): $($_.Exception.Message)")
            }
            finally {
                if ($job.Ping) {
                    $job.Ping.Dispose()
                }
            }

            [void]$results.Add([pscustomobject]$entry)
        }

        $eventArgs.Result = [pscustomobject]@{
            Generation = [int]$argument.Generation
            Results = @($results)
            Errors = @($errors)
        }
    })

    $script:NMPingWorker.Add_RunWorkerCompleted({
        param($sender, $eventArgs)
        [void]$sender

        if ($eventArgs.Error) {
            Write-NMDebugLog -Message ("Ping worker failed: {0}" -f $eventArgs.Error.Message)
            return
        }

        $payload = $eventArgs.Result
        foreach ($message in @($payload.Errors)) {
            Write-NMDebugLog -Message $message
        }

        if ([int]$payload.Generation -ne [int]$script:NMGeneration) {
            if ($script:NMPingTimer -and $script:NMPingTimer.Enabled) {
                Invoke-NMPingCycle
            }
            return
        }

        Invoke-NMOnPingResults -Results $payload.Results
    })

    $script:NMPingTimer = [System.Windows.Forms.Timer]::new()
    $script:NMPingTimer.Interval = [int]$script:NMConfig.RefreshMilliseconds
    $script:NMPingTimer.Add_Tick({
        Invoke-NMPingCycle
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
}

function Invoke-NMPingCycle {
    if (-not $script:NMPingWorker -or $script:NMPingWorker.IsBusy) {
        return
    }

    $targets = @(Get-NMEnabledTargets | ForEach-Object {
        [pscustomobject]@{
            Name = [string]$_.Name
            Address = [string]$_.Address
        }
    })

    if ($targets.Count -lt 1) {
        return
    }

    $script:NMPingWorker.RunWorkerAsync([pscustomobject]@{
        Generation = [int]$script:NMGeneration
        Targets = $targets
        TimeoutMs = [int]$script:NMConfig.PingTimeoutMilliseconds
    })
}
