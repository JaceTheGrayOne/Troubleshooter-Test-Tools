function New-RemoteAccessTcpClient {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][int]$TcpPort,
        [Parameter(Mandatory)][int]$TimeoutMilliseconds
    )

    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null

    try {
        $asyncResult = $client.BeginConnect($ComputerName, $TcpPort, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            $client.Close()
            throw "Timed out connecting to $ComputerName`:$TcpPort after $TimeoutMilliseconds ms."
        }

        $client.EndConnect($asyncResult)
        $client.NoDelay = $true
        return $client
    }
    catch {
        $client.Close()
        throw
    }
    finally {
        if ($asyncResult -and $asyncResult.AsyncWaitHandle) {
            $asyncResult.AsyncWaitHandle.Close()
        }
    }
}

function Send-RemoteTelnetOptionResponse {
    param(
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream,
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)][int]$Command,
        [Parameter(Mandatory)][int]$Option
    )

    $reply = $null

    if ($Command -eq $State.Do) {
        if ($Option -eq $State.OptionSuppressGoAhead) {
            $reply = $State.Will
        }
        else {
            $reply = $State.Wont
        }
    }
    elseif ($Command -eq $State.Will) {
        if ($Option -eq $State.OptionEcho -or $Option -eq $State.OptionSuppressGoAhead) {
            $reply = $State.Do
        }
        else {
            $reply = $State.Dont
        }
    }

    if ($null -eq $reply) {
        return
    }

    $response = New-Object byte[] 3
    $response[0] = [byte]$State.Iac
    $response[1] = [byte]$reply
    $response[2] = [byte]$Option
    $NetworkStream.Write($response, 0, $response.Length)
    $NetworkStream.Flush()
}

function ConvertFrom-RemoteTelnetPayload {
    param(
        [Parameter(Mandatory)][byte[]]$Buffer,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream,
        [Parameter(Mandatory)][hashtable]$State
    )

    $outputBytes = New-Object 'System.Collections.Generic.List[System.Byte]'

    for ($index = 0; $index -lt $Count; $index++) {
        $value = [int]$Buffer[$index]

        switch ($State.ParserState) {
            'Data' {
                if ($value -eq $State.Iac) {
                    $State.ParserState = 'Iac'
                }
                else {
                    [void]$outputBytes.Add([byte]$value)
                }
            }

            'Iac' {
                if ($value -eq $State.Iac) {
                    [void]$outputBytes.Add([byte]$value)
                    $State.ParserState = 'Data'
                }
                elseif ($value -eq $State.Will -or $value -eq $State.Wont -or $value -eq $State.Do -or $value -eq $State.Dont) {
                    $State.Command = $value
                    $State.ParserState = 'Option'
                }
                elseif ($value -eq $State.Sb) {
                    $State.SubnegotiationIac = $false
                    $State.ParserState = 'Subnegotiation'
                }
                else {
                    $State.ParserState = 'Data'
                }
            }

            'Option' {
                Send-RemoteTelnetOptionResponse -NetworkStream $NetworkStream -State $State -Command $State.Command -Option $value
                $State.ParserState = 'Data'
            }

            'Subnegotiation' {
                if ($State.SubnegotiationIac) {
                    if ($value -eq $State.Se) {
                        $State.ParserState = 'Data'
                    }

                    $State.SubnegotiationIac = $false
                }
                elseif ($value -eq $State.Iac) {
                    $State.SubnegotiationIac = $true
                }
            }
        }
    }

    if ($outputBytes.Count -eq 0) {
        return ''
    }

    return $State.Encoding.GetString($outputBytes.ToArray())
}

function Send-RemoteTelnetLine {
    param(
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream,
        [Parameter(Mandatory)][hashtable]$State,
        [AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][scriptblock]$WriteStatus
    )

    $payload = $State.Encoding.GetBytes($Text + "`r`n")
    $NetworkStream.Write($payload, 0, $payload.Length)
    $NetworkStream.Flush()

    if ([string]::IsNullOrEmpty($Text)) {
        & $WriteStatus 'Sent blank input line.'
    }
    else {
        & $WriteStatus ('Sent input: {0}' -f $Text)
    }
}

function Start-RemoteTelnetSession {
    param(
        [Parameter(Mandatory)][string]$TargetHost,
        [Parameter(Mandatory)][int]$TcpPort,
        [Parameter(Mandatory)][int]$ConnectTimeoutMilliseconds,
        [Parameter(Mandatory)][int]$PollMilliseconds,
        [Parameter(Mandatory)][int]$ReceiveBufferBytes,
        [AllowEmptyString()][string]$InputPath,
        [Parameter(Mandatory)][scriptblock]$WriteStatus,
        [Parameter(Mandatory)][scriptblock]$WriteReceived
    )

    $telnetState = @{
        Iac = 255
        Se = 240
        Sb = 250
        Will = 251
        Wont = 252
        Do = 253
        Dont = 254
        OptionEcho = 1
        OptionSuppressGoAhead = 3
        ParserState = 'Data'
        Command = 0
        SubnegotiationIac = $false
        Encoding = [System.Text.Encoding]::ASCII
    }

    $client = $null
    $networkStream = $null

    try {
        & $WriteStatus ('Connecting to {0}:{1}...' -f $TargetHost, $TcpPort)

        $client = New-RemoteAccessTcpClient -ComputerName $TargetHost -TcpPort $TcpPort -TimeoutMilliseconds $ConnectTimeoutMilliseconds
        $networkStream = $client.GetStream()

        & $WriteStatus 'Connected. Console output follows.'

        $buffer = New-Object byte[] $ReceiveBufferBytes
        $readInput = New-RemoteAccessInputReader -Path $InputPath -WriteStatus $WriteStatus
        $sessionClosed = $false

        while (-not $sessionClosed) {
            foreach ($inputText in @(& $readInput)) {
                Send-RemoteTelnetLine -NetworkStream $networkStream -State $telnetState -Text $inputText -WriteStatus $WriteStatus
            }

            $readAny = $false
            while ($client.Available -gt 0) {
                $bytesToRead = [Math]::Min($buffer.Length, $client.Available)
                $count = $networkStream.Read($buffer, 0, $bytesToRead)
                if ($count -le 0) {
                    & $WriteStatus 'Telnet session closed.'
                    $sessionClosed = $true
                    break
                }

                $receivedText = ConvertFrom-RemoteTelnetPayload -Buffer $buffer -Count $count -NetworkStream $networkStream -State $telnetState
                & $WriteReceived $receivedText
                $readAny = $true
            }

            if ($sessionClosed) {
                break
            }

            if ($client.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -and $client.Available -eq 0) {
                & $WriteStatus 'Telnet session closed.'
                break
            }

            if (-not $readAny) {
                Start-Sleep -Milliseconds $PollMilliseconds
            }
        }
    }
    finally {
        if ($networkStream) {
            $networkStream.Dispose()
        }

        if ($client) {
            $client.Close()
        }

        & $WriteStatus 'Telnet session stopped.'
    }
}
