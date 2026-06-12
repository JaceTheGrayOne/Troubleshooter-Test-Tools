param(
    [string]$TargetHost = '192.168.200.100',

    [ValidateRange(1, 65535)]
    [int]$Port = 23,

    [ValidateRange(100, 60000)]
    [int]$ConnectTimeoutMilliseconds = 10000,

    [ValidateRange(10, 5000)]
    [int]$PollMilliseconds = 75,

    [ValidateRange(128, 65536)]
    [int]$ReceiveBufferBytes = 4096,

    [string]$InputPath = '',

    [string]$LogPath = (Join-Path $PSScriptRoot '..\Logs\RmupConsole.log')
)

$toolScriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    (Get-Location).Path
}

& (Join-Path $toolScriptRoot 'RemoteAccess.ps1') `
    -Protocol Telnet `
    -TargetHost $TargetHost `
    -TcpPort $Port `
    -ConnectTimeoutMilliseconds $ConnectTimeoutMilliseconds `
    -PollMilliseconds $PollMilliseconds `
    -ReceiveBufferBytes $ReceiveBufferBytes `
    -InputPath $InputPath `
    -LogPath $LogPath
