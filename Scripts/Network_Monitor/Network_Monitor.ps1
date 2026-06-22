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

function Get-NMPreferredPowerShell {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) {
        return $pwsh.Source
    }

    $powershell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($powershell) {
        return $powershell.Source
    }

    return 'powershell.exe'
}

$script:NMAppRoot = Get-NMEntryRoot
$script:NMEntryPath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $PSCommandPath
}
else {
    Join-Path $script:NMAppRoot 'Network_Monitor.ps1'
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $powerShellPath = Get-NMPreferredPowerShell
    Start-Process -FilePath $powerShellPath -WorkingDirectory $script:NMAppRoot -WindowStyle Hidden -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-STA'
        '-File'
        ('"{0}"' -f $script:NMEntryPath)
    )
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modulePaths = @(
    'Scripts\Logging.ps1'
    'Scripts\Validation.ps1'
    'Scripts\Config.ps1'
    'Scripts\MonitorState.ps1'
    'Scripts\PingEngine.ps1'
    'Scripts\UiHelpers.ps1'
    'Scripts\SettingsForm.ps1'
    'Scripts\MainForm.ps1'
)

foreach ($modulePath in $modulePaths) {
    . (Join-Path $script:NMAppRoot $modulePath)
}

Start-NetworkMonitorApp -AppRoot $script:NMAppRoot
