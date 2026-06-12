param(
    [string]$Port = 'COM1',

    [ValidateRange(300, 921600)]
    [int]$BaudRate = 9600,

    [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')]
    [string]$Parity = 'None',

    [ValidateRange(5, 8)]
    [int]$DataBits = 8,

    [ValidateSet('One', 'Two', 'OnePointFive')]
    [string]$StopBits = 'One',

    [string]$Username = 'spadmin',

    [string]$Password = 'admin123',

    [bool]$WakePrompt = $true,

    [ValidateRange(0, 10000)]
    [int]$OpenDelayMilliseconds = 100,

    [ValidateRange(0, 10000)]
    [int]$PromptDelayMilliseconds = 300,

    [string]$LogPath = (Join-Path $PSScriptRoot '..\Logs\SpectracomGpsAuth.log')
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
    -Protocol Serial `
    -Action SpectracomGpsAuth `
    -ComPort $Port `
    -BaudRate $BaudRate `
    -Parity $Parity `
    -DataBits $DataBits `
    -StopBits $StopBits `
    -Username $Username `
    -Password $Password `
    -WakePrompt $WakePrompt `
    -OpenDelayMilliseconds $OpenDelayMilliseconds `
    -PromptDelayMilliseconds $PromptDelayMilliseconds `
    -LogPath $LogPath
