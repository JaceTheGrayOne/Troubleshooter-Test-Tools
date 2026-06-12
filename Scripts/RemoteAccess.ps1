param(
    [ValidateSet('Telnet', 'Serial')]
    [string]$Protocol = 'Telnet',

    [string]$PresetId = '',
    [string]$Action = '',

    [string]$TargetHost = '',
    [ValidateRange(1, 65535)]
    [int]$TcpPort = 23,
    [ValidateRange(100, 60000)]
    [int]$ConnectTimeoutMilliseconds = 10000,

    [string]$ComPort = '',
    [ValidateRange(300, 921600)]
    [int]$BaudRate = 9600,
    [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')]
    [string]$Parity = 'None',
    [ValidateRange(5, 8)]
    [int]$DataBits = 8,
    [ValidateSet('One', 'Two', 'OnePointFive')]
    [string]$StopBits = 'One',

    [string]$Username = '',
    [string]$Password = '',
    [bool]$WakePrompt = $true,
    [ValidateRange(0, 10000)]
    [int]$OpenDelayMilliseconds = 100,
    [ValidateRange(0, 10000)]
    [int]$PromptDelayMilliseconds = 300,

    [ValidateRange(10, 5000)]
    [int]$PollMilliseconds = 75,
    [ValidateRange(128, 65536)]
    [int]$ReceiveBufferBytes = 4096,

    [string]$InputPath = '',
    [string]$LogPath = (Join-Path $PSScriptRoot '..\Logs\RemoteAccess.log')
)

$ErrorActionPreference = 'Stop'
$toolScriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    (Get-Location).Path
}

. (Join-Path $toolScriptRoot 'ToolCommon.ps1')
. (Join-Path $toolScriptRoot 'RemoteAccess.Telnet.ps1')
. (Join-Path $toolScriptRoot 'RemoteAccess.Serial.ps1')
. (Join-Path $toolScriptRoot 'RemoteAccess.Actions.SpectracomGpsAuth.ps1')

if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    Ensure-TextFile -Path $InputPath
}

$script:LogWriter = New-SharedLogWriter -Path $LogPath

function Write-RemoteAccessStatus {
    param(
        [Parameter(Mandatory)][string]$Prefix,
        [Parameter(Mandatory)][string]$Message
    )

    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Prefix, $Message
    $script:LogWriter.WriteLine($line)
    Write-Host $line
}

function Write-RemoteAccessReceived {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return
    }

    $script:LogWriter.Write($Text)
    Write-Host -NoNewline $Text
}

function New-RemoteAccessInputReader {
    param(
        [AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][scriptblock]$WriteStatus
    )

    $state = @{
        LineIndex = 0
    }

    return {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            return @()
        }

        $content = Read-SharedTextFile -Path $Path
        if ([string]::IsNullOrEmpty($content)) {
            return @()
        }

        $lines = @($content -split '\r?\n')
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
            if ($lines.Count -eq 1) {
                $lines = @()
            }
            else {
                $lines = @($lines[0..($lines.Count - 2)])
            }
        }

        if ($lines.Count -lt [int]$state.LineIndex) {
            $state.LineIndex = 0
        }

        if ($lines.Count -eq [int]$state.LineIndex) {
            return @()
        }

        $pending = @()
        $nextIndex = [int]$state.LineIndex

        for ($index = [int]$state.LineIndex; $index -lt $lines.Count; $index++) {
            try {
                $entry = $lines[$index] | ConvertFrom-Json
                $pending += ,([string]$entry.text)
                $nextIndex = $index + 1
            }
            catch {
                if ($index -lt ($lines.Count - 1)) {
                    & $WriteStatus "Ignored malformed console input entry at line $($index + 1)."
                    $nextIndex = $index + 1
                }
            }
        }

        $state.LineIndex = $nextIndex
        return $pending
    }.GetNewClosure()
}

$writeRemoteAccessStatus = {
    param([string]$Message)
    Write-RemoteAccessStatus -Prefix 'RemoteAccess' -Message $Message
}.GetNewClosure()

$writeTelnetStatus = {
    param([string]$Message)
    Write-RemoteAccessStatus -Prefix 'Telnet' -Message $Message
}.GetNewClosure()

$writeSerialStatus = {
    param([string]$Message)
    Write-RemoteAccessStatus -Prefix 'Serial' -Message $Message
}.GetNewClosure()

$writeGpsAuthStatus = {
    param([string]$Message)
    Write-RemoteAccessStatus -Prefix 'GPS Auth' -Message $Message
}.GetNewClosure()

$writeReceived = {
    param([AllowEmptyString()][string]$Text)
    Write-RemoteAccessReceived -Text $Text
}.GetNewClosure()

$exitCode = 0

try {
    & $writeRemoteAccessStatus ('Starting Remote Access. PID={0} Protocol={1} PresetId={2} Action={3}' -f $PID, $Protocol, $PresetId, $Action)

    switch ($Protocol) {
        'Telnet' {
            if (-not [string]::IsNullOrWhiteSpace($Action)) {
                throw "Action '$Action' is not supported for Telnet."
            }

            if ([string]::IsNullOrWhiteSpace($TargetHost)) {
                throw 'Target host is required for Telnet.'
            }

            & $writeRemoteAccessStatus ('Telnet configuration: Target={0}:{1} ConnectTimeoutMilliseconds={2} PollMilliseconds={3} ReceiveBufferBytes={4}' -f $TargetHost, $TcpPort, $ConnectTimeoutMilliseconds, $PollMilliseconds, $ReceiveBufferBytes)
            Start-RemoteTelnetSession `
                -TargetHost $TargetHost `
                -TcpPort $TcpPort `
                -ConnectTimeoutMilliseconds $ConnectTimeoutMilliseconds `
                -PollMilliseconds $PollMilliseconds `
                -ReceiveBufferBytes $ReceiveBufferBytes `
                -InputPath $InputPath `
                -WriteStatus $writeTelnetStatus `
                -WriteReceived $writeReceived
        }

        'Serial' {
            if ([string]::IsNullOrWhiteSpace($ComPort)) {
                throw 'COM port is required for Serial.'
            }

            & $writeRemoteAccessStatus ('Serial configuration: ComPort={0} BaudRate={1} Parity={2} DataBits={3} StopBits={4} PollMilliseconds={5} ReceiveBufferBytes={6} Action={7}' -f $ComPort, $BaudRate, $Parity, $DataBits, $StopBits, $PollMilliseconds, $ReceiveBufferBytes, $Action)

            if ([string]::IsNullOrWhiteSpace($Action)) {
                Start-RemoteSerialSession `
                    -ComPort $ComPort `
                    -BaudRate $BaudRate `
                    -Parity $Parity `
                    -DataBits $DataBits `
                    -StopBits $StopBits `
                    -PollMilliseconds $PollMilliseconds `
                    -ReceiveBufferBytes $ReceiveBufferBytes `
                    -InputPath $InputPath `
                    -WriteStatus $writeSerialStatus `
                    -WriteReceived $writeReceived
            }
            elseif ($Action -eq 'SpectracomGpsAuth') {
                if ([string]::IsNullOrWhiteSpace($Username)) {
                    throw 'Username is required for GPS Auth.'
                }

                & $writeRemoteAccessStatus ('GPS Auth configuration: ComPort={0} BaudRate={1} Parity={2} DataBits={3} StopBits={4} Username={5} Password=(hidden) WakePrompt={6} OpenDelayMilliseconds={7} PromptDelayMilliseconds={8}' -f $ComPort, $BaudRate, $Parity, $DataBits, $StopBits, $Username, $WakePrompt, $OpenDelayMilliseconds, $PromptDelayMilliseconds)
                Invoke-SpectracomGpsAuth `
                    -ComPort $ComPort `
                    -BaudRate $BaudRate `
                    -Parity $Parity `
                    -DataBits $DataBits `
                    -StopBits $StopBits `
                    -Username $Username `
                    -Password $Password `
                    -WakePrompt $WakePrompt `
                    -OpenDelayMilliseconds $OpenDelayMilliseconds `
                    -PromptDelayMilliseconds $PromptDelayMilliseconds `
                    -WriteStatus $writeGpsAuthStatus `
                    -WriteReceived $writeReceived
            }
            else {
                throw "Unknown Remote Access serial action '$Action'."
            }
        }
    }
}
catch {
    & $writeRemoteAccessStatus "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    & $writeRemoteAccessStatus 'Remote Access stopped.'

    if ($script:LogWriter) {
        $script:LogWriter.Dispose()
    }
}

exit $exitCode
