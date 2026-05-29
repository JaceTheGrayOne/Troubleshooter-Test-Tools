$ErrorActionPreference = 'Stop'

function Get-ToolDefinitions {
    param([Parameter(Mandatory)][string]$CatalogPath)

    if (-not (Test-Path -LiteralPath $CatalogPath)) {
        throw "Tool catalog not found: $CatalogPath"
    }

    $catalog = Get-Content -Raw -LiteralPath $CatalogPath | ConvertFrom-Json
    if (-not $catalog.tools) {
        throw "Tool catalog has no 'tools' array: $CatalogPath"
    }

    $ids = @{}
    $tools = foreach ($tool in @($catalog.tools)) {
        if ([string]::IsNullOrWhiteSpace($tool.id)) {
            throw 'A tool entry is missing an id.'
        }

        if ($ids.ContainsKey($tool.id)) {
            throw "Duplicate tool id '$($tool.id)' in catalog."
        }
        $ids[$tool.id] = $true

        if ([string]::IsNullOrWhiteSpace($tool.name)) {
            throw "Tool '$($tool.id)' is missing a name."
        }

        if ([string]::IsNullOrWhiteSpace($tool.script)) {
            throw "Tool '$($tool.id)' is missing a script path."
        }

        foreach ($field in @($tool.fields)) {
            if ([string]::IsNullOrWhiteSpace($field.name)) {
                throw "Tool '$($tool.id)' has a field without a name."
            }
            if ([string]::IsNullOrWhiteSpace($field.type)) {
                $field | Add-Member -NotePropertyName type -NotePropertyValue 'text' -Force
            }
            if ([string]::IsNullOrWhiteSpace($field.argument)) {
                $field | Add-Member -NotePropertyName argument -NotePropertyValue $field.name -Force
            }
        }

        $tool
    }

    return @($tools | Sort-Object @{ Expression = { if ($null -ne $_.order) { [int]$_.order } else { 9999 } } }, name)
}

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $RootPath $Path
}

function ConvertTo-PowerShellLiteral {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return '$null'
    }

    if ($Value -is [bool]) {
        if ($Value) {
            return '$true'
        }
        return '$false'
    }

    if ($Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [int] -or
        $Value -is [long] -or
        $Value -is [decimal] -or
        $Value -is [double] -or
        $Value -is [float]) {
        return [string]$Value
    }

    return "'{0}'" -f ([string]$Value -replace "'", "''")
}

function Get-SafeLogName {
    param([Parameter(Mandatory)][string]$Value)

    $safe = $Value -replace '[^a-zA-Z0-9_.-]', '-'
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'Tool'
    }

    return $safe
}

function New-PowerShellWorkerCommand {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][hashtable]$FieldValues,
        [Parameter(Mandatory)][string]$LogPath
    )

    $parts = @('& {0}' -f (ConvertTo-PowerShellLiteral -Value $ScriptPath))

    if (-not [string]::IsNullOrWhiteSpace($Tool.mode)) {
        $modeArgument = if ([string]::IsNullOrWhiteSpace($Tool.modeArgument)) { 'Mode' } else { [string]$Tool.modeArgument }
        $parts += '-{0} {1}' -f $modeArgument, (ConvertTo-PowerShellLiteral -Value $Tool.mode)
    }

    foreach ($field in @($Tool.fields)) {
        $argument = if ([string]::IsNullOrWhiteSpace($field.argument)) { [string]$field.name } else { [string]$field.argument }
        $value = $FieldValues[$field.name]
        $parts += '-{0} {1}' -f $argument, (ConvertTo-PowerShellLiteral -Value $value)
    }

    $logArgument = if ([string]::IsNullOrWhiteSpace($Tool.logArgument)) { 'LogPath' } else { [string]$Tool.logArgument }
    $parts += '-{0} {1}' -f $logArgument, (ConvertTo-PowerShellLiteral -Value $LogPath)

    return $parts -join ' '
}

function Start-ConfiguredTool {
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][string]$LogsPath,
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][hashtable]$FieldValues
    )

    if (-not (Test-Path -LiteralPath $LogsPath)) {
        $null = New-Item -ItemType Directory -Path $LogsPath -Force
    }

    $scriptPath = Resolve-ToolPath -RootPath $RootPath -Path ([string]$Tool.script)
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Tool script not found: $scriptPath"
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logPrefix = if ([string]::IsNullOrWhiteSpace($Tool.logPrefix)) { [string]$Tool.id } else { [string]$Tool.logPrefix }
    $logPath = Join-Path $LogsPath ('{0}-{1}.log' -f (Get-SafeLogName -Value $logPrefix), $timestamp)

    $scriptType = if ([string]::IsNullOrWhiteSpace($Tool.scriptType)) { 'powershell' } else { [string]$Tool.scriptType }

    switch ($scriptType.ToLowerInvariant()) {
        'powershell' {
            $command = New-PowerShellWorkerCommand -ScriptPath $scriptPath -Tool $Tool -FieldValues $FieldValues -LogPath $logPath
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
            $process = Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -WindowStyle Hidden -PassThru
        }

        'batch' {
            $process = Start-Process -FilePath cmd.exe -ArgumentList ('/c "{0}"' -f $scriptPath) -WindowStyle Hidden -PassThru
        }

        default {
            throw "Unsupported scriptType '$scriptType' for tool '$($Tool.id)'."
        }
    }

    return [pscustomobject]@{
        ToolId = [string]$Tool.id
        ToolName = [string]$Tool.name
        Process = $process
        LogPath = $logPath
        StartedAt = Get-Date
        EndedAt = $null
        ExitCode = $null
    }
}

function Test-ToolRunActive {
    param([AllowNull()]$Run)

    if (-not $Run -or -not $Run.Process) {
        return $false
    }

    return -not $Run.Process.HasExited
}

function Stop-ToolRun {
    param([Parameter(Mandatory)]$Run)

    if (-not (Test-ToolRunActive -Run $Run)) {
        return
    }

    $Run.Process.Kill()
    $Run.Process.WaitForExit(2000) | Out-Null
    $Run.EndedAt = Get-Date

    if ($Run.Process.HasExited) {
        $Run.ExitCode = $Run.Process.ExitCode
    }
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
        $reader = New-Object System.IO.StreamReader($stream)
        return $reader.ReadToEnd()
    }
    catch {
        return "Unable to read log file yet: $($_.Exception.Message)"
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
