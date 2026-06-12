function Start-RemoteSerialSession {
    param(
        [Parameter(Mandatory)][string]$ComPort,
        [Parameter(Mandatory)][int]$BaudRate,
        [Parameter(Mandatory)][string]$Parity,
        [Parameter(Mandatory)][int]$DataBits,
        [Parameter(Mandatory)][string]$StopBits,
        [Parameter(Mandatory)][int]$PollMilliseconds,
        [Parameter(Mandatory)][int]$ReceiveBufferBytes,
        [AllowEmptyString()][string]$InputPath,
        [Parameter(Mandatory)][scriptblock]$WriteStatus,
        [Parameter(Mandatory)][scriptblock]$WriteReceived
    )

    $serialPort = $null

    try {
        $parityValue = [System.IO.Ports.Parity]$Parity
        $stopBitsValue = [System.IO.Ports.StopBits]$StopBits
        $serialPort = New-Object System.IO.Ports.SerialPort -ArgumentList $ComPort, $BaudRate, $parityValue, $DataBits, $stopBitsValue
        $serialPort.ReadBufferSize = $ReceiveBufferBytes

        & $WriteStatus "Opening serial port $ComPort..."
        $serialPort.Open()
        & $WriteStatus 'Opened. Serial output follows.'

        $readInput = New-RemoteAccessInputReader -Path $InputPath -WriteStatus $WriteStatus

        while ($true) {
            foreach ($inputText in @(& $readInput)) {
                $serialPort.WriteLine($inputText)

                if ([string]::IsNullOrEmpty($inputText)) {
                    & $WriteStatus 'Sent blank input line.'
                }
                else {
                    & $WriteStatus ('Sent input: {0}' -f $inputText)
                }
            }

            $receivedText = $serialPort.ReadExisting()
            if (-not [string]::IsNullOrEmpty($receivedText)) {
                & $WriteReceived $receivedText
            }

            Start-Sleep -Milliseconds $PollMilliseconds
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
