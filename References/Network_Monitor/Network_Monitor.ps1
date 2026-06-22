<#
.SYNOPSIS
    Network Monitor Dashboard - Network node monitoring tool

.DESCRIPTION
    Monitors targeted network nodes with continuous async ping testing
    and displays statistics in a format controlled user facing dashboard.

.PARAMETER RefreshSeconds
    Sets the refresh interval in seconds. (default: 2)
    ./NetworkMonitor.ps1 -RefreshSeconds 2

.PARAMETER DebugLog
    Activates verbose debug logging during execution.
    ./NetworkMonitor.ps1 -Debug

.NOTES
    File Name  : NetworkMonitor.ps1
    Author     : 1130538 (Brandon Heath)
    Version    : 7.8.1
    Creation   : 08OCT2024
    Update     : 17NOV2025
    Requires   : Powershell 7.0+, Windows 10+
    Versioning : Major.Minor.Patch (Implement.Refactor.Remove/Repair)
    Target Nodes : Subsystem Management Server (SMS)
                   Message Processing Server (MPS)
                   Modem Processor Group (MPG)

.CHANGE LOG
    v7.8.1 - Comment Addition*
            *Versioning Exception - The author of this script is moving to a new project.
            Added plain language comments for all top/mid level code blocks for clarity and future maintainability.
            I plan to fix the cursor blinking issue before that happens. It drives me nuts.

    v7.8.0 - Implemented
            Unicode character bounding box and some padding handlin gto keep table aligned.
            Regex handling to strip escaped ASCII color codes from being detected by the ConsoleHost.

        Refactored
            Redraw handling to clear on execution in addition to repainting in-place via SetCursorPosition.
            Dashboard format to segmented formatting with ANSI-aware padding so columns stay aligned within frame.
            Parallelized ping loop to utilize async tasks from the primary runspace where ConsoleHost retains ICMP privileges.

        Removed
            FastPing function due to potential memory leakage involving the register accumulation and byte window drift.


    v7.7.0 - Implemented
            Resource cleanup for FastPing sessions on exit.

        Refactored
            Log path resolution

        Removed
            Unused $LogFile variable definitions.
            Redundant variable re-assignments.
            Obsolete references.


    v7.6.0 - Implemented
            Refresh rate clamping to prevent zero/negative input.

        Refactored
            Color handlin and host detection for compatibility with non-interactive host console environments.


    v7.5.0 - Refactored
            Ping timeout and bitmasking unification through configurable global constants.
            Loss percentage computation to increase precision and reduce per-cycle overhead.
            RTT parsing and EMA to use double-precision arithmetic.
            RTT rounding to address potential edge case rounding error in sub-millisecond RTTs.


    v7.4.0 - Implemented
            Ping object disposal to ensure the proper release of references and resources.
            Dynamic re-draw logic.
            Cursor position relative screen clearing to prevent percycle re-draw induced console flashing.

        Refactored
            Error handling and exception reporting throughout loop execution.


    v7.3.0 - Implemented
            Global variables for config constants.

        Refactored
            Inline literals and duplicate expressions using newly implemented global constants.


    v7.2.0 - Implemented
            Centralized log management with automated log size pruning.

        Refactored
            Logsize helper function to automatically trim earliest entries in log rather than latest to preserve logging.
            DebugLog write function with timestamping and file safety handling.

        Removed
            Hardcoded system math imports and calls.
            Vestigial CSV generation.
            Vestigial Pingwall switch and related code.


    v7.1.0 - Implemented
            New averaging window function to constrain the averaging calculation from drifting during subsequent executions.

        Refactored
            Script wide formatting.
            DebugLog path data to generalize the function path.


    v7.0.0 - Implemented
            Pre-computed bit mask for window size to avoid repeated per-row iteration.
            -Fastping switch and associated functions for faster ping execution.
            -ASCIISymbols switch and associated functions as a safety fallback for unsupported unicode glyphs.
            -DebugLog switch and associated functions to facilitate more verbose debugging/logging.

        Refactored
            Loss calculation bitwise shift counter to reduce per-cycle overhead.
            State function to use bitwise flags instead of characters to facilitate acquisition.
            Debug/logging functions
            Date/time logic to accurately detect local time (LST vs EDT)
#>


# Script Parameters
[CmdletBinding()]
param(
    [ValidateRange(1, 3600)]
    [int]$RefreshSeconds = 2, # Dashboard update frequency
    [switch]$DebugLog         # Enables verbose debug logging
)

# Enforce Strict Variable Declaration
Set-StrictMode -Version Latest

# Script Variables
$ScriptRoot = $PSScriptRoot
$UpSym   = [char]0x2191    # Unicode "Up Arrow"
$DownSym = [char]0x2193    # Unicode "Down Arrow"
$Targets = @(
    @{ Title = 'SMS'; IP = '192.168.51.20' }
    @{ Title = 'MPS'; IP = '192.168.101.20' }
    @{ Title = 'MPG'; IP = '192.168.200.100' }
)
$PingTimeoutMS = 1000      # Ping timeout extension
$HistoryWindowSize = 10    # Size of recent HistoryBitMask
$EmaWeightNewSample = 0.3  # Exponential Moving Average (EMA) sample weight
$EmaWeightOldAverage = 0.7 # Exponential Moving Average (EMA) existing average weight
$HistoryBitMask = [int](([math]::Pow(2, $HistoryWindowSize)) - 1) # BitMask used to ensure RecentBits only retains the last N samples

# Error Log Management
# Trims aging log entries to prevent unmanaged log growth
function Limit-LogSize {
    param([string]$Path, [long]$MaxBytes, [long]$TrimToBytes)
    if (-not (Test-Path $Path)) { return }
    $fi = Get-Item $Path
    if ($fi.Length -gt $MaxBytes) {
        $tail = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::ASCII)
        $start = [math]::Max(0, $tail.Length - $TrimToBytes)
        [System.IO.File]::WriteAllText($Path, $tail.Substring($start), [System.Text.Encoding]::ASCII)
    }
}

# Log Timestamping and Size Limit
# Ensures proper Timestamping and establishes log size limitation
function Write-ErrorLog {
    param([string]$Message)

    ## - Log Timestamping
    $logPath = Join-Path $ScriptRoot 'NetworkMonitor.errors.log'
    $stamp = Get-Date -Format 'ddMMMyyyy HH:mm:ss'

    ## - Log Size Limit
    Limit-LogSize -Path $logPath -MaxBytes 1MB -TrimToBytes 512KB
    Add-Content -Path $logPath -Value ("$stamp | $Message") -Encoding ASCII
}

# DebugLog Flag Detection
# Ensures verbose debugging only occurs when DebugLog flag is set
function Write-DebugLog {
    param([string]$Message)
    if (-not $DebugLog) { return }
    $logPath = Join-Path $ScriptRoot 'Debug.log'
    $stamp = Get-Date -Format 'ddMMMyyyy HH:mm:ss'
    Limit-LogSize -Path $logPath -MaxBytes 1MB -TrimToBytes 512KB
    Add-Content -Path $logPath -Value ("$stamp | $Message") -Encoding ASCII
}

# Target Color
# Ensures consistent color assignment on a per-target basis
function Get-TargetColor {
    param([string]$Title)
    switch ($Title) {
        "SMS" { "Magenta" }
        "MPS" { "Magenta" }
        "MPG" { "Cyan" }
        default { "White" }
    }
}

# Dashboard
# Handles runtime loop, ping execution, dashboard rendering, state tracking, and console redraw
function ShowDashboard {
    [CmdletBinding(SupportsShouldProcess = $false)]
    param(
        [Parameter(Position = 0)]
        [ValidateRange(1, 3600)]
        [int]$Refresh = 2
    )

    ## Host Interactivity Detection
    ## Verifies cursor control to avoid having to constantly catch title cursor control exceptions
    $isInteractive = $true
    try { $null = $Host.UI.RawUI } catch { $isInteractive = $false }

    ## Verifies Title control
    ## Verifies Title control to avoid having to constantly catch Title control exceptions
    $CanSetTitle = $false
    try {
        $null = $Host.UI.RawUI.WindowTitle
        $CanSetTitle = $true
    }
    catch
    {
        $CanSetTitle = $false
    }

    ## Statistic Storage Initialization
    $stats = @{}
    foreach ($t in $Targets) {
        $stats[$t.Title] = @{
            AvgMs = 0.0          # Running average of packet latency
            ValidSamples = 0     # Tracks the number of valid RTT samples ensuring the correct handling of no ping/first ping states
            RecentBits = 0       # Bitmask of recent successful pings
            RecentCount = 0      # Number of valid tracked samples in RecentBits window, does not decrement on bit roll off
            LossPct = 0.0        # Ratio of failed tracked samples.
            State = '--'         # Current state of a given ping target
            LastBytes = '--'     # Last reported packet size in bytes
            LastTTL = '--'       # Last reported TTL
        }
    }

    ## Exit Handler
    $stopRequested = $false
    try {
        Unregister-Event -SourceIdentifier ConsoleCancel -ErrorAction SilentlyContinue
    }
    catch {}

    ## Event Handler for CTRL-C Quit
    $null = Register-EngineEvent -SourceIdentifier ConsoleCancel -Action {
        try {
            $global:stopRequested = $true
            try { [Console]::CursorVisible = $true } catch {}
            Write-Host "`nStopping dashboard..." -ForegroundColor Yellow
        }
        catch {
        }
    } | Out-Null

    ## Dashboard Monitor Dashboard Main Loop
    Clear-Host
    try { [Console]::CursorVisible = $false }
    catch {}

    try {
        while (-not $stopRequested) {
            #### - Parallelized Ping Loop
            #### - Asynchronous execution in main runspace
            #### - Avoids issue with raw socket privilege inheritance in parallelized runspaces
            $pingTasks = foreach ($t in $Targets) {
                $ping = [System.Net.NetworkInformation.Ping]::new()
                [pscustomobject]@{
                    Title = $t.Title
                    Task = $ping.SendPingAsync($t.IP, $PingTimeoutMs)
                    Ping = $ping
                }
            }

            #### - Holds task thread until all ping tasks complete
            try {
                [System.Threading.Tasks.Task]::WaitAll($pingTasks.Task)
            }
            catch {
            }

            #### - Builds data container for each node
            $results = foreach ($job in $pingTasks) {
                $data = [ordered]@{
                    Title = $job.Title
                    IP = ($Targets | Where-Object Title -eq $job.Title).IP
                    Success = $false
                    Ms = $null
                    Bytes = '--'
                    TTL = '--'
                }

                #### - Extracts data emitted from ping operation tasks
                try {
                    $reply = $job.Task.Result
                    if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                        $data.Success = $true
                        $data.Ms = [int]$reply.RoundtripTime
                        $data.Bytes = $reply.Buffer.Length
                        if ($reply.Options) { $data.TTL = $reply.Options.Ttl }
                    }
                }
                catch {
                    Write-DebugLog "Ping failure for $($job.Title): $($_.Exception.Message)"
                }

                #### - Ping task cleanup
                #### - This is necessary to prevent a memory leak due to unreleased handle/resource buildup over time
                finally {
                    $job.Ping.Dispose()
                }

                $data
            }

            #### Merge Ping Results Into Statistics
            if ($results) {
                foreach ($r in $results) {
                    if (-not $r) { continue }

                    $s = $stats[$r.Title]
                    $ok = $r.Success
                    $ms = $r.Ms

                    ##### - Shift left and append latest success bit
                    $s.RecentBits = (($s.RecentBits -shl 1) -bor [int]$ok) -band $HistoryBitMask
                    $s.RecentCount = [math]::Min($HistoryWindowSize, $s.RecentCount + 1)

                    ##### - Count successful bit
                    $upCount = 0
                    $bits = [uint32]$s.RecentBits
                    while ($bits -ne 0) {
                        $bits = $bits -band ($bits - 1)
                        $upCount++
                    }

                    ##### - Loss% calculation
                    $s.LossPct = if ($s.RecentCount -gt 0) {
                        (($s.RecentCount - $upCount) * 100.0) / $s.RecentCount
                    }
                    else {
                        0.0
                    }

                    ##### - Exponential Moving Average (EMA) for RTT
                    ##### - This is per-packet latency, not average latency over time
                    ##### - This does not decay on "no result" returns by design
                    ##### - This allows the EMA to only track the true latency of valid packet route results
                    ##### - This prevents erroneous decay due to dropped packets
                    if ($null -ne $ms -and $ms -ge 0) {
                        if ($s.ValidSamples -eq 0) {
                            $s.AvgMs = [double]$ms
                        }
                        else {
                            $s.AvgMs = ($EmaWeightOldAverage * $s.AvgMs) + ($EmaWeightNewSample * $ms)
                        }

                        $s.ValidSamples++
                    }

                    ##### - Update last byte and TTL
                    $s.LastBytes = $r.Bytes
                    $s.LastTTL = $r.TTL

                    ##### - Resolve state from HistoryWindow
                    if ($s.RecentCount -lt $HistoryWindowSize) {
                        $s.State = if ($ok) { 'UP' } else { 'DOWN' }
                    }
                    else {
                        $s.State = if ($upCount -eq 0) { 'DOWN' } else { 'UP' }
                    }
                }
            }

            ### Date/Time in EST/ESD/ZULU
            $nowUtc = [datetime]::UtcNow
            try {
                $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById('Eastern Standard Time')
                $nowEst = [System.TimeZoneInfo]::ConvertTimeFromUtc($nowUtc, $tz)
            }
            catch {
                $nowEst = $nowUtc.AddHours(-5)
            }

            $header = '{0:ddMMMyyyy HHmm\e} | {1:HHmm\z}' -f $nowEst, $nowUtc

            ### ConsoleHost Redraw
            if ($isInteractive) {
                try {
                    [Console]::CursorVisible = $false
                    [Console]::SetCursorPosition(0,0)
                }
                catch {
                    Clear-Host
                    [Console]::CursorVisible = $false
                    [Console]::SetCursorPosition(0,0)
                }
            } else {
                [Console]::CursorVisible = $false
                Clear-Host
            }


            #### Frame Config
            [int]$boxWidth = 70
            $innerWidth = $boxWidth - 2
            $topLine = "┌" + ("─" * $innerWidth) + "┐"
            $midLine = "├" + ("─" * $innerWidth) + "┤"
            $bottomLine = "└" + ("─" * $innerWidth) + "┘"

            #### Header Layout
            Write-Host $topLine -ForegroundColor DarkGray
            $headerText = " Network Monitor Dashboard ({0}s) {1} " -f $Refresh, $header
            $headerPadded = $headerText.PadRight($innerWidth).Substring(0, $innerWidth)
            Write-Host "│" -NoNewline -ForegroundColor DarkGray
            Write-Host $headerPadded -NoNewline -ForegroundColor Yellow
            Write-Host "│" -ForegroundColor DarkGray
            Write-Host $midLine -ForegroundColor DarkGray

            #### Column Rendering
            $colHeader = (" {0,-4}{1,-17}{2,8}{3,7}{4,7}{5,9}{6,12}" -f 'LRU', 'Address', 'Bytes', 'TTL', 'RTT', 'Loss%', 'State')
            $colPadded = $colHeader.PadRight($innerWidth).Substring(0, $innerWidth)
            Write-Host "│" -NoNewline -ForegroundColor DarkGray
            Write-Host $colPadded -NoNewline -ForegroundColor White
            Write-Host "│" -ForegroundColor DarkGray

            #### ANSI Definitions
            #### Defines Dashboard color variables
            $esc = [char]27
            $reset = "$esc[0m"
            $gray = "$esc[90m"
            $red = "$esc[31m"
            $green = "$esc[32m"
            $magenta = "$esc[35m"
            $cyan = "$esc[36m"

            #### Data Row Rendering
            foreach ($t in $Targets) {
                $s = $stats[$t.Title]
                $avg = if ($s.ValidSamples -eq 0) { 'NA' }
                elseif ($s.AvgMs -lt 1) { '<1ms' }
                else { [math]::Round($s.AvgMs,1) }
                $loss = [math]::Round($s.LossPct,1)

                ##### - State Config
                $nodeColor = if ($t.Title -eq 'MPG') { $cyan } else { $magenta }
                $stateColor = if ($s.State -eq 'UP') { $green } else { $red }
                $sym = if ($s.State -eq 'UP') { $UpSym } else { $DownSym }

                ##### - Line entry layout
                $nodeSegment = (" {0,-4}" -f $t.Title)
                $addrSegment = (" {0,-17}" -f $t.IP)
                $bytesSegment = ("{0,8}" -f $s.LastBytes)
                $ttlSegment = ("{0,7}" -f $s.LastTTL)
                $rttSegment = ("{0,7}" -f $avg)
                $lossSegment = ("{0,9}" -f $loss)
                $stateSegment = ("{0,0}" -f ($s.State + $sym))

                ##### - Build line with ANSI defined colors
                $coloredLine = "" +
                    "$nodeColor$nodeSegment$reset" +
                    $addrSegment +
                    $bytesSegment +
                    $ttlSegment +
                    $rttSegment +
                    $lossSegment +
                    "" +
                    "$stateColor$stateSegment$reset"

                ##### - Regex to strip ANSI from output
                ##### - Prevents ConsoleHost from registering escaped ANSI as blank characters
                $visibleWidth = ($coloredLine -replace "$esc\[[0-9;]*m", '').Length
                if ($visibleWidth -lt $innerWidth) {
                    $coloredLine += " " * ($innerWidth - $visibleWidth)
                }

                Write-Host "$gray│$reset$coloredLine$gray│$reset"
            }

            Write-Host $bottomLine -ForegroundColor DarkGray

            ##### Window Title Update
            ##### This reflects current status only
            ##### This checks for Title set access once on execution and then stops if it fails
            ##### This avoids the overhead of running the check every loop
            if ($CanSetTitle) {
                try {
                    $upCount = ($stats.Values | Where-Object { $_.State -eq 'UP' }).Count
                    $total = $Targets.Count
                    $percentUP = [math]::Round(($upCount / $total) * 100)
                    $titleText = "Network Monitor - $upCount/$total UP ($percentUp%) | Refresh: ${Refresh}s"
                    $Host.UI.RawUI.WindowTitle = $titleText
                }
                catch {
                    $CanSetTitle = $false
                    Write-DebugLog "WindowTitle update disabled: $($_.Exception.Message)"
                }
            }

            Start-Sleep -Seconds $Refresh
        }
    }
    ### Post Dashboard Loop Cleanup
    finally {
        [Console]::CursorVisible = $false
        Write-Host "`nSession terminated cleanly." -ForegroundColor Cyan
        Unregister-Event -SourceIdentifier ConsoleCancel -ErrorAction SilentlyContinue
    }
}

## Script Entry Point
ShowDashboard -Refresh $RefreshSeconds
