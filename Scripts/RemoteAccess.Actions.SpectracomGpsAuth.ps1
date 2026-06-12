function Read-SpectracomSerialText {
    param(
        [Parameter(Mandatory)][System.IO.Ports.SerialPort]$SerialPort,
        [Parameter(Mandatory)][scriptblock]$WriteReceived
    )

    $text = $SerialPort.ReadExisting()
    if (-not [string]::IsNullOrEmpty($text)) {
        & $WriteReceived $text
    }

    return $text
}

function Invoke-SpectracomGpsAuth {
    param(
        [Parameter(Mandatory)][string]$ComPort,
        [Parameter(Mandatory)][int]$BaudRate,
        [Parameter(Mandatory)][string]$Parity,
        [Parameter(Mandatory)][int]$DataBits,
        [Parameter(Mandatory)][string]$StopBits,
        [Parameter(Mandatory)][string]$Username,
        [AllowEmptyString()][string]$Password,
        [Parameter(Mandatory)][bool]$WakePrompt,
        [Parameter(Mandatory)][int]$OpenDelayMilliseconds,
        [Parameter(Mandatory)][int]$PromptDelayMilliseconds,
        [Parameter(Mandatory)][scriptblock]$WriteStatus,
        [Parameter(Mandatory)][scriptblock]$WriteReceived
    )

    $serialPort = $null

    try {
        $parityValue = [System.IO.Ports.Parity]$Parity
        $stopBitsValue = [System.IO.Ports.StopBits]$StopBits
        $serialPort = New-Object System.IO.Ports.SerialPort -ArgumentList $ComPort, $BaudRate, $parityValue, $DataBits, $stopBitsValue

        & $WriteStatus "Opening serial port $ComPort..."
        $serialPort.Open()

        Start-Sleep -Milliseconds $OpenDelayMilliseconds

        if ($WakePrompt) {
            & $WriteStatus 'Sending wake prompt...'
            $serialPort.WriteLine('')
        }

        Start-Sleep -Milliseconds $PromptDelayMilliseconds
        $promptText = Read-SpectracomSerialText -SerialPort $serialPort -WriteReceived $WriteReceived

        if ($promptText -match '@SecureSync.*\$') {
            & $WriteStatus 'Authentication Valid'
        }
        else {
            & $WriteStatus "Authenticated prompt was not detected. Sending username '$Username'..."
            $serialPort.WriteLine($Username)
            Start-Sleep -Milliseconds $OpenDelayMilliseconds
            [void](Read-SpectracomSerialText -SerialPort $serialPort -WriteReceived $WriteReceived)

            & $WriteStatus 'Sending password...'
            $serialPort.WriteLine($Password)
            Start-Sleep -Milliseconds $PromptDelayMilliseconds
            [void](Read-SpectracomSerialText -SerialPort $serialPort -WriteReceived $WriteReceived)
        }
    }
    finally {
        if ($serialPort) {
            if ($serialPort.IsOpen) {
                $serialPort.Close()
                & $WriteStatus "Serial port $ComPort closed."
            }

            $serialPort.Dispose()
        }
    }
}
