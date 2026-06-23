function Write-NMDebugLog {
    param([Parameter(Mandatory)][string]$Message)

    if (-not $script:NMConfig -or -not $script:NMConfig.DebugMode) {
        return
    }

    $logRoot = Join-Path $script:NMAppRoot 'logs'
    if (-not (Test-Path -LiteralPath $logRoot)) {
        $null = New-Item -ItemType Directory -Force -Path $logRoot
    }

    $logPath = Join-Path $logRoot ('NetworkMonitor-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    Add-Content -LiteralPath $logPath -Value ('{0} | {1}' -f $stamp, $Message) -Encoding UTF8
}

function Write-NMStartupErrorLog {
    param([Parameter(Mandatory)][string]$Message)

    try {
        $root = if ($script:NMAppRoot) { $script:NMAppRoot } else { $PSScriptRoot }
        $logRoot = Join-Path $root 'logs'
        if (-not (Test-Path -LiteralPath $logRoot)) {
            $null = New-Item -ItemType Directory -Force -Path $logRoot
        }

        $logPath = Join-Path $logRoot 'NetworkMonitor.startup-error.log'
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -LiteralPath $logPath -Value ('{0} | {1}' -f $stamp, $Message) -Encoding UTF8
    }
    catch {
    }
}
