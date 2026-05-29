param(
    [ValidateSet('PingMonitor', 'GpsKeepalive', 'QuickCheck')]
    [string]$Mode = 'PingMonitor',

    [string]$Target = '127.0.0.1',

    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 1,

    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 30,

    [string]$LogPath = (Join-Path $PSScriptRoot '..\Logs\ExampleWorker.log')
)

$ErrorActionPreference = 'Stop'

$logDirectory = Split-Path -Parent $LogPath
if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not (Test-Path -LiteralPath $logDirectory)) {
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
}

function Write-WorkerLog {
    param([Parameter(Mandatory)][string]$Message)

    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Mode, $Message
    $line | Tee-Object -FilePath $LogPath -Append
}

Write-WorkerLog "Started. PID=$PID Target=$Target IntervalSeconds=$IntervalSeconds DurationSeconds=$DurationSeconds"

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$iteration = 0

try {
    while ($timer.Elapsed.TotalSeconds -lt $DurationSeconds) {
        $iteration++

        switch ($Mode) {
            'PingMonitor' {
                $reachable = Test-Connection -ComputerName $Target -Count 1 -Quiet -ErrorAction SilentlyContinue
                if ($reachable) {
                    Write-WorkerLog "Ping OK for $Target. Sample=$iteration"
                }
                else {
                    Write-WorkerLog "Ping FAILED for $Target. Sample=$iteration"
                }
            }

            'GpsKeepalive' {
                Write-WorkerLog "Serial keepalive placeholder sent to $Target. Sample=$iteration"
            }

            'QuickCheck' {
                Write-WorkerLog "Quick status sample $iteration for $Target."
            }
        }

        Start-Sleep -Seconds $IntervalSeconds
    }

    Write-WorkerLog "Completed normally after $([math]::Round($timer.Elapsed.TotalSeconds, 1)) seconds."
    exit 0
}
catch {
    Write-WorkerLog "ERROR: $($_.Exception.Message)"
    exit 1
}
