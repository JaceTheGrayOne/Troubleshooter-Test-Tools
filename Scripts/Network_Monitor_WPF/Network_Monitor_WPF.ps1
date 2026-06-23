$ErrorActionPreference = 'Stop'

function Get-NMEntryRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return (Split-Path -Parent $PSCommandPath)
    }

    return (Get-Location).Path
}

function Test-NMWpfAssembliesInProcess {
    try {
        Add-Type -AssemblyName PresentationFramework
        Add-Type -AssemblyName PresentationCore
        Add-Type -AssemblyName WindowsBase
        Add-Type -AssemblyName System.Xaml
        Add-Type -AssemblyName System.Windows.Forms
        return $true
    }
    catch {
        return $false
    }
}

function Test-NMWpfHost {
    param([Parameter(Mandatory)][string]$PowerShellPath)

    $probe = 'try { Add-Type -AssemblyName PresentationFramework; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName WindowsBase; Add-Type -AssemblyName System.Xaml; [System.Windows.Window]::new() | Out-Null; exit 0 } catch { exit 42 }'
    try {
        $process = Start-Process -FilePath $PowerShellPath -WindowStyle Hidden -Wait -PassThru -ArgumentList @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-STA'
            '-Command'
            $probe
        )
        return ($process.ExitCode -eq 0)
    }
    catch {
        return $false
    }
}

function Get-NMWpfCapablePowerShell {
    $candidates = @()
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) { $candidates += $pwsh.Source }

    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($powershell) { $candidates += $powershell.Source }

    if ($candidates.Count -lt 1) {
        $candidates += 'powershell.exe'
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-NMWpfHost -PowerShellPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-NMCurrentPowerShellPath {
    try {
        return [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }
    catch {
        return ''
    }
}

function Start-NMSelfInHost {
    param(
        [Parameter(Mandatory)][string]$PowerShellPath,
        [Parameter(Mandatory)][string]$EntryPath,
        [Parameter(Mandatory)][string]$AppRoot
    )

    Start-Process -FilePath $PowerShellPath -WorkingDirectory $AppRoot -WindowStyle Hidden -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-STA'
        '-File'
        ('"{0}"' -f $EntryPath)
    )
}

function Write-NMFallbackStartupErrorLog {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        $logRoot = Join-Path $Root 'logs'
        if (-not (Test-Path -LiteralPath $logRoot)) {
            $null = New-Item -ItemType Directory -Force -Path $logRoot
        }
        $logPath = Join-Path $logRoot 'NetworkMonitor.startup-error.log'
        Add-Content -LiteralPath $logPath -Value ('{0} | {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message) -Encoding UTF8
    }
    catch {
    }
}

function Show-NMFatalStartupError {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        if (Get-Command Write-NMStartupErrorLog -ErrorAction SilentlyContinue) {
            Write-NMStartupErrorLog -Message $Message
        }
        else {
            Write-NMFallbackStartupErrorLog -Root $Root -Message $Message
        }
    }
    catch {
    }

    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            $Message,
            'Network Monitor Startup Error',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    catch {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show($Message, 'Network Monitor Startup Error') | Out-Null
        }
        catch {
        }
    }
}

$script:NMAppRoot = Get-NMEntryRoot
$script:NMEntryPath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $PSCommandPath
}
else {
    Join-Path $script:NMAppRoot 'Network_Monitor_WPF.ps1'
}

try {
    $isSta = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA)
    $wpfLoadsHere = Test-NMWpfAssembliesInProcess
    if (-not $isSta -or -not $wpfLoadsHere) {
        $hostPath = Get-NMWpfCapablePowerShell
        if (-not $hostPath) {
            throw 'No PowerShell host could load WPF assemblies.'
        }

        $current = Get-NMCurrentPowerShellPath
        if (-not $isSta -or -not [string]::Equals($current, $hostPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            Start-NMSelfInHost -PowerShellPath $hostPath -EntryPath $script:NMEntryPath -AppRoot $script:NMAppRoot
            exit
        }

        if (-not (Test-NMWpfAssembliesInProcess)) {
            throw 'WPF assemblies could not be loaded in the selected PowerShell host.'
        }
    }

    $modulePaths = @(
        'Scripts\Logging.ps1'
        'Scripts\Validation.ps1'
        'Scripts\Config.ps1'
        'Scripts\MonitorState.ps1'
        'Scripts\Presentation.ps1'
        'Scripts\PingEngine.ps1'
        'Scripts\WpfTheme.ps1'
        'Scripts\WpfXaml.ps1'
        'Scripts\WpfWindowChrome.ps1'
        'Scripts\WpfBindings.ps1'
        'Scripts\SettingsWindow.ps1'
        'Scripts\MainWindow.ps1'
    )

    foreach ($modulePath in $modulePaths) {
        . (Join-Path $script:NMAppRoot $modulePath)
    }

    Start-NetworkMonitorApp -AppRoot $script:NMAppRoot
}
catch {
    $message = "Network Monitor WPF failed to start: $($_.Exception.Message)"
    Show-NMFatalStartupError -Root $script:NMAppRoot -Message $message
    exit 1
}
