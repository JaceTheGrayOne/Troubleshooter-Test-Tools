$ErrorActionPreference = 'Stop'

function Ensure-Directory {
    param([AllowEmptyString()][string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path) -and -not (Test-Path -LiteralPath $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -Force
    }
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory)][string]$Path)
    Ensure-Directory -Path (Split-Path -Parent $Path)
}

function Ensure-TextFile {
    param([Parameter(Mandatory)][string]$Path)
    Ensure-ParentDirectory -Path $Path
    if (-not (Test-Path -LiteralPath $Path)) {
        Set-Content -LiteralPath $Path -Value '' -NoNewline -Encoding UTF8
    }
}

function Read-SharedTextFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowEmptyString()][string]$ErrorPrefix = ''
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return ''
    }

    $stream = $null
    $reader = $null

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $reader = New-Object System.IO.StreamReader -ArgumentList $stream, ([System.Text.Encoding]::UTF8), $true
        return $reader.ReadToEnd()
    }
    catch {
        if (-not [string]::IsNullOrWhiteSpace($ErrorPrefix)) {
            return ('{0}: {1}' -f $ErrorPrefix, $_.Exception.Message)
        }
        return ''
    }
    finally {
        if ($reader) { $reader.Dispose() }
        elseif ($stream) { $stream.Dispose() }
    }
}

function New-SharedLogWriter {
    param([Parameter(Mandatory)][string]$Path)
    Ensure-ParentDirectory -Path $Path
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
    $writer = New-Object System.IO.StreamWriter -ArgumentList $stream, ([System.Text.Encoding]::UTF8)
    $writer.AutoFlush = $true
    return $writer
}
