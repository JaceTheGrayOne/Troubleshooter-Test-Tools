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

Ensure-ParentDirectory -Path $LogPath

function Write-ToolOutput {
    param([AllowEmptyString()][string]$Message)

    Add-Content -LiteralPath $LogPath -Value $Message
    Write-Host $Message
}

function Read-SerialText {
    param([Parameter(Mandatory)][System.IO.Ports.SerialPort]$SerialPort)

    $text = $SerialPort.ReadExisting()
    if (-not [string]::IsNullOrEmpty($text)) {
        Write-ToolOutput $text
    }

    return $text
}

$title = 'Automatic Spectracom Authentication'
$width = $title.Length + 4
$padding = [math]::Floor(($width - $title.Length) / 2)

Write-ToolOutput ''
Write-ToolOutput ('+' + '-' * $width + '+')
Write-ToolOutput ('|' + ' ' * $padding + $title + ' ' * ($width - $title.Length - $padding) + '|')
Write-ToolOutput ('+' + '-' * $width + '+')
Write-ToolOutput ''
Write-ToolOutput ('Configuration: Port={0} BaudRate={1} Parity={2} DataBits={3} StopBits={4} Username={5} Password=(hidden)' -f $Port, $BaudRate, $Parity, $DataBits, $StopBits, $Username)

$serialPort = $null
$exitCode = 0

try {
    if ([string]::IsNullOrWhiteSpace($Port)) {
        throw 'Serial port is required.'
    }

    if ([string]::IsNullOrWhiteSpace($Username)) {
        throw 'Username is required.'
    }

    $parityValue = [System.IO.Ports.Parity]$Parity
    $stopBitsValue = [System.IO.Ports.StopBits]$StopBits

    $serialPort = New-Object System.IO.Ports.SerialPort -ArgumentList $Port, $BaudRate, $parityValue, $DataBits, $stopBitsValue

    Write-ToolOutput "Opening serial port $Port..."
    $serialPort.Open()

    Start-Sleep -Milliseconds $OpenDelayMilliseconds

    if ($WakePrompt) {
        Write-ToolOutput 'Sending wake prompt...'
        $serialPort.WriteLine('')
    }

    Start-Sleep -Milliseconds $PromptDelayMilliseconds
    $promptText = Read-SerialText -SerialPort $serialPort

    if ($promptText -match '@SecureSync.*\$') {
        Write-ToolOutput 'Authentication Valid'
    }
    else {
        Write-ToolOutput "Authenticated prompt was not detected. Sending username '$Username'..."
        $serialPort.WriteLine($Username)
        Start-Sleep -Milliseconds $OpenDelayMilliseconds
        [void](Read-SerialText -SerialPort $serialPort)

        Write-ToolOutput 'Sending password...'
        $serialPort.WriteLine($Password)
        Start-Sleep -Milliseconds $PromptDelayMilliseconds
        [void](Read-SerialText -SerialPort $serialPort)
    }
}
catch {
    Write-ToolOutput "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    if ($serialPort) {
        if ($serialPort.IsOpen) {
            $serialPort.Close()
            Write-ToolOutput "Serial port $Port closed."
        }

        $serialPort.Dispose()
    }
}

exit $exitCode
