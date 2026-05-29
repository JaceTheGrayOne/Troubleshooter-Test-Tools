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

$ErrorActionPreference = 'Stop'

$logDirectory = Split-Path -Parent $LogPath
if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not (Test-Path -LiteralPath $logDirectory)) {
    $null = New-Item -ItemType Directory -Path $logDirectory -Force
}

if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $inputDirectory = Split-Path -Parent $InputPath
    if (-not [string]::IsNullOrWhiteSpace($inputDirectory) -and -not (Test-Path -LiteralPath $inputDirectory)) {
        $null = New-Item -ItemType Directory -Path $inputDirectory -Force
    }

    if (-not (Test-Path -LiteralPath $InputPath)) {
        Set-Content -LiteralPath $InputPath -Value '' -NoNewline -Encoding UTF8
    }
}

$script:TelnetIac = 255
$script:TelnetSe = 240
$script:TelnetSb = 250
$script:TelnetWill = 251
$script:TelnetWont = 252
$script:TelnetDo = 253
$script:TelnetDont = 254
$script:TelnetOptionEcho = 1
$script:TelnetOptionSuppressGoAhead = 3
$script:TelnetState = 'Data'
$script:TelnetCommand = 0
$script:SubnegotiationIac = $false
$script:InputLineIndex = 0
$script:TextEncoding = [System.Text.Encoding]::ASCII

$logStream = [System.IO.File]::Open($LogPath, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
$script:LogWriter = New-Object System.IO.StreamWriter -ArgumentList $logStream, ([System.Text.Encoding]::UTF8)
$script:LogWriter.AutoFlush = $true

function Write-StatusLog {
    param([Parameter(Mandatory)][string]$Message)

    $line = '{0} [RMUP] {1}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'), $Message
    $script:LogWriter.WriteLine($line)
    Write-Host $line
}

function Write-ReceivedText {
    param([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return
    }

    $script:LogWriter.Write($Text)
    Write-Host -NoNewline $Text
}

function Read-SharedTextFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    $stream = $null
    $reader = $null

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = New-Object System.IO.StreamReader -ArgumentList $stream, ([System.Text.Encoding]::UTF8)
        return $reader.ReadToEnd()
    }
    catch {
        return ''
    }
    finally {
        if ($reader) {
            $reader.Dispose()
        }
        elseif ($stream) {
            $stream.Dispose()
        }
    }
}

function New-ConnectedTcpClient {
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

function Send-TelnetOptionResponse {
    param(
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream,
        [Parameter(Mandatory)][int]$Command,
        [Parameter(Mandatory)][int]$Option
    )

    $reply = $null

    if ($Command -eq $script:TelnetDo) {
        if ($Option -eq $script:TelnetOptionSuppressGoAhead) {
            $reply = $script:TelnetWill
        }
        else {
            $reply = $script:TelnetWont
        }
    }
    elseif ($Command -eq $script:TelnetWill) {
        if ($Option -eq $script:TelnetOptionEcho -or $Option -eq $script:TelnetOptionSuppressGoAhead) {
            $reply = $script:TelnetDo
        }
        else {
            $reply = $script:TelnetDont
        }
    }

    if ($null -eq $reply) {
        return
    }

    $response = New-Object byte[] 3
    $response[0] = [byte]$script:TelnetIac
    $response[1] = [byte]$reply
    $response[2] = [byte]$Option
    $NetworkStream.Write($response, 0, $response.Length)
    $NetworkStream.Flush()
}

function ConvertFrom-TelnetPayload {
    param(
        [Parameter(Mandatory)][byte[]]$Buffer,
        [Parameter(Mandatory)][int]$Count,
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream
    )

    $outputBytes = New-Object 'System.Collections.Generic.List[System.Byte]'

    for ($index = 0; $index -lt $Count; $index++) {
        $value = [int]$Buffer[$index]

        switch ($script:TelnetState) {
            'Data' {
                if ($value -eq $script:TelnetIac) {
                    $script:TelnetState = 'Iac'
                }
                else {
                    [void]$outputBytes.Add([byte]$value)
                }
            }

            'Iac' {
                if ($value -eq $script:TelnetIac) {
                    [void]$outputBytes.Add([byte]$value)
                    $script:TelnetState = 'Data'
                }
                elseif ($value -eq $script:TelnetWill -or $value -eq $script:TelnetWont -or $value -eq $script:TelnetDo -or $value -eq $script:TelnetDont) {
                    $script:TelnetCommand = $value
                    $script:TelnetState = 'Option'
                }
                elseif ($value -eq $script:TelnetSb) {
                    $script:SubnegotiationIac = $false
                    $script:TelnetState = 'Subnegotiation'
                }
                else {
                    $script:TelnetState = 'Data'
                }
            }

            'Option' {
                Send-TelnetOptionResponse -NetworkStream $NetworkStream -Command $script:TelnetCommand -Option $value
                $script:TelnetState = 'Data'
            }

            'Subnegotiation' {
                if ($script:SubnegotiationIac) {
                    if ($value -eq $script:TelnetSe) {
                        $script:TelnetState = 'Data'
                    }

                    $script:SubnegotiationIac = $false
                }
                elseif ($value -eq $script:TelnetIac) {
                    $script:SubnegotiationIac = $true
                }
            }
        }
    }

    if ($outputBytes.Count -eq 0) {
        return ''
    }

    return $script:TextEncoding.GetString($outputBytes.ToArray())
}

function Get-PendingConsoleInput {
    param([AllowEmptyString()][string]$Path)

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

    if ($lines.Count -lt $script:InputLineIndex) {
        $script:InputLineIndex = 0
    }

    if ($lines.Count -eq $script:InputLineIndex) {
        return @()
    }

    $pending = @()
    $nextIndex = $script:InputLineIndex

    for ($index = $script:InputLineIndex; $index -lt $lines.Count; $index++) {
        try {
            $entry = $lines[$index] | ConvertFrom-Json
            $pending += ,([string]$entry.text)
            $nextIndex = $index + 1
        }
        catch {
            if ($index -lt ($lines.Count - 1)) {
                Write-StatusLog "Ignored malformed console input entry at line $($index + 1)."
                $nextIndex = $index + 1
            }
        }
    }

    $script:InputLineIndex = $nextIndex
    return $pending
}

function Send-TelnetLine {
    param(
        [Parameter(Mandatory)][System.Net.Sockets.NetworkStream]$NetworkStream,
        [AllowEmptyString()][string]$Text
    )

    $payload = $script:TextEncoding.GetBytes($Text + "`r`n")
    $NetworkStream.Write($payload, 0, $payload.Length)
    $NetworkStream.Flush()

    if ([string]::IsNullOrEmpty($Text)) {
        Write-StatusLog 'Sent blank input line.'
    }
    else {
        Write-StatusLog ('Sent input: {0}' -f $Text)
    }
}

$client = $null
$networkStream = $null
$exitCode = 0

try {
    if ([string]::IsNullOrWhiteSpace($TargetHost)) {
        throw 'Target host is required.'
    }

    Write-StatusLog ('Starting native RMUP telnet console. PID={0} Target={1}:{2}' -f $PID, $TargetHost, $Port)
    Write-StatusLog 'Connecting...'

    $client = New-ConnectedTcpClient -ComputerName $TargetHost -TcpPort $Port -TimeoutMilliseconds $ConnectTimeoutMilliseconds
    $networkStream = $client.GetStream()

    Write-StatusLog 'Connected. Console output follows.'

    $buffer = New-Object byte[] $ReceiveBufferBytes
    $sessionClosed = $false

    while (-not $sessionClosed) {
        foreach ($inputText in @(Get-PendingConsoleInput -Path $InputPath)) {
            Send-TelnetLine -NetworkStream $networkStream -Text $inputText
        }

        $readAny = $false
        while ($client.Available -gt 0) {
            $bytesToRead = [Math]::Min($buffer.Length, $client.Available)
            $count = $networkStream.Read($buffer, 0, $bytesToRead)
            if ($count -le 0) {
                Write-StatusLog 'RMUP telnet session closed.'
                $sessionClosed = $true
                break
            }

            $receivedText = ConvertFrom-TelnetPayload -Buffer $buffer -Count $count -NetworkStream $networkStream
            Write-ReceivedText -Text $receivedText
            $readAny = $true
        }

        if ($sessionClosed) {
            break
        }

        if ($client.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead) -and $client.Available -eq 0) {
            Write-StatusLog 'RMUP telnet session closed.'
            break
        }

        if (-not $readAny) {
            Start-Sleep -Milliseconds $PollMilliseconds
        }
    }
}
catch {
    Write-StatusLog "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally {
    if ($networkStream) {
        $networkStream.Dispose()
    }

    if ($client) {
        $client.Close()
    }

    Write-StatusLog 'RMUP telnet console stopped.'

    if ($script:LogWriter) {
        $script:LogWriter.Dispose()
    }
}

exit $exitCode
