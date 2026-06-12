$ErrorActionPreference = 'Stop'
$toolRuntimeRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    Join-Path (Get-Location) 'Scripts'
}
. (Join-Path $toolRuntimeRoot 'ToolCommon.ps1')

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
    foreach ($tool in @($catalog.tools)) {
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

        $hasScript = ($tool.PSObject.Properties.Name -contains 'script') -and -not [string]::IsNullOrWhiteSpace($tool.script)
        $hasLaunchPath = ($tool.PSObject.Properties.Name -contains 'launchPath') -and -not [string]::IsNullOrWhiteSpace($tool.launchPath)

        if (-not $hasScript -and -not $hasLaunchPath) {
            throw "Tool '$($tool.id)' is missing a script path or launch path."
        }

        if ($tool.PSObject.Properties.Name -contains 'presetsPath' -and [string]::IsNullOrWhiteSpace($tool.presetsPath)) {
            throw "Tool '$($tool.id)' has an empty presetsPath."
        }

        foreach ($field in @($tool.fields)) {
            if ([string]::IsNullOrWhiteSpace($field.name)) {
                throw "Tool '$($tool.id)' has a field without a name."
            }
            if ([string]::IsNullOrWhiteSpace($field.type)) {
                $field | Add-Member -NotePropertyName type -NotePropertyValue 'text' -Force
            }
        }

        $tool
    }
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

function Get-ToolPresets {
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)]$Tool
    )

    if (-not ($Tool.PSObject.Properties.Name -contains 'presetsPath') -or [string]::IsNullOrWhiteSpace($Tool.presetsPath)) {
        return @()
    }

    $presetsPath = Resolve-ToolPath -RootPath $RootPath -Path ([string]$Tool.presetsPath)
    if (-not (Test-Path -LiteralPath $presetsPath)) {
        throw "Tool preset file not found: $presetsPath"
    }

    $presetCatalog = Get-Content -Raw -LiteralPath $presetsPath | ConvertFrom-Json
    if (-not $presetCatalog.presets) {
        throw "Tool preset file has no 'presets' array: $presetsPath"
    }

    $ids = @{}
    foreach ($preset in @($presetCatalog.presets)) {
        if ([string]::IsNullOrWhiteSpace($preset.id)) {
            throw "A preset in '$presetsPath' is missing an id."
        }

        if ($ids.ContainsKey($preset.id)) {
            throw "Duplicate preset id '$($preset.id)' in '$presetsPath'."
        }
        $ids[$preset.id] = $true

        if ([string]::IsNullOrWhiteSpace($preset.label)) {
            throw "Preset '$($preset.id)' in '$presetsPath' is missing a label."
        }

        if (-not $preset.values) {
            throw "Preset '$($preset.id)' in '$presetsPath' has no values object."
        }

        $preset
    }
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
        [Parameter(Mandatory)][string]$LogPath,
        [AllowEmptyString()][string]$InputPath = ''
    )

    $parts = @('& {0}' -f (ConvertTo-PowerShellLiteral -Value $ScriptPath))

    foreach ($field in @($Tool.fields)) {
        if ($FieldValues.ContainsKey($field.name)) {
            $value = $FieldValues[$field.name]
        }
        else {
            $value = $field.default
        }

        $parts += '-{0} {1}' -f $field.name, (ConvertTo-PowerShellLiteral -Value $value)
    }

    $parts += '-LogPath {0}' -f (ConvertTo-PowerShellLiteral -Value $LogPath)

    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $parts += '-InputPath {0}' -f (ConvertTo-PowerShellLiteral -Value $InputPath)
    }

    return $parts -join ' '
}

function Start-ConfiguredTool {
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][string]$LogsPath,
        [Parameter(Mandatory)]$Tool,
        [Parameter(Mandatory)][hashtable]$FieldValues
    )

    Ensure-Directory -Path $LogsPath

    $scriptPath = Resolve-ToolPath -RootPath $RootPath -Path ([string]$Tool.script)
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Tool script not found: $scriptPath"
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $logName = Get-SafeLogName -Value ([string]$Tool.id)
    $logPath = Join-Path $LogsPath ('{0}-{1}.log' -f $logName, $timestamp)
    $inputPath = $null

    if ($Tool.interactiveInput -and [bool]$Tool.interactiveInput) {
        $inputPath = Join-Path $LogsPath ('{0}-{1}.input.jsonl' -f $logName, $timestamp)
        Ensure-TextFile -Path $inputPath
    }

    $command = New-PowerShellWorkerCommand -ScriptPath $scriptPath -Tool $Tool -FieldValues $FieldValues -LogPath $logPath -InputPath $inputPath
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
    $process = Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" -WindowStyle Hidden -PassThru

    return [pscustomobject]@{
        ToolId = [string]$Tool.id
        ToolName = [string]$Tool.name
        Process = $process
        LogPath = $logPath
        InputPath = $inputPath
        StartedAt = Get-Date
        EndedAt = $null
        ExitCode = $null
    }
}

function Send-ToolRunInput {
    param(
        [Parameter(Mandatory)]$Run,
        [AllowEmptyString()][string]$Text
    )

    if (-not $Run -or [string]::IsNullOrWhiteSpace($Run.InputPath)) {
        throw 'The selected tool run does not accept console input.'
    }

    Ensure-TextFile -Path $Run.InputPath

    $entry = [pscustomobject]@{
        submittedAt = (Get-Date).ToString('o')
        text = $Text
    }

    $entry | ConvertTo-Json -Compress | Add-Content -LiteralPath $Run.InputPath -Encoding UTF8
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
