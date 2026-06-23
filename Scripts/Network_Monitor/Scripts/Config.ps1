function ConvertTo-NMHashtable {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [hashtable]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = ConvertTo-NMHashtable -Value $Value[$key]
        }
        return $result
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $result[[string]$key] = ConvertTo-NMHashtable -Value $Value[$key]
        }
        return $result
    }

    if ($Value -is [pscustomobject]) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $result[$property.Name] = ConvertTo-NMHashtable -Value $property.Value
        }
        return $result
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value | ForEach-Object { ConvertTo-NMHashtable -Value $_ })
    }

    return $Value
}

function Copy-NMDeepValue {
    param([AllowNull()]$Value)

    return (ConvertTo-NMHashtable -Value $Value)
}

function Get-NMDefaultConfig {
    $columns = foreach ($id in Get-NMSupportedColumnIds) {
        [ordered]@{
            Id = $id
            Visible = [bool]$script:NMColumnDefinitions[$id].DefaultVisible
            Width = [int]$script:NMColumnDefinitions[$id].DefaultWidth
        }
    }

    return [ordered]@{
        Targets = @(
            [ordered]@{ Name = 'SMS'; Address = '192.168.51.20'; Color = '#ff40e6'; Enabled = $true }
            [ordered]@{ Name = 'MPS'; Address = '192.168.101.20'; Color = '#ff40e6'; Enabled = $true }
            [ordered]@{ Name = 'MPG'; Address = '192.168.200.100'; Color = '#27d9e6'; Enabled = $true }
        )
        RefreshMilliseconds = 1000
        PingTimeoutMilliseconds = 1000
        HistoryLength = 12
        AlwaysOnTop = $false
        AutoStart = $true
        DebugMode = $false
        Window = [ordered]@{
            Width = 1040
            Height = 270
            X = $null
            Y = $null
            Maximized = $false
        }
        Columns = @($columns)
        Health = [ordered]@{
            DownFailures = 3
            OrangeFailures = 2
            OrangeLossPercent = 25
        }
        RttThresholds = [ordered]@{
            GreenMax = 50
            YellowMax = 100
            OrangeMax = 250
        }
        LossThresholds = [ordered]@{
            YellowMax = 10
            OrangeMax = 25
        }
    }
}

function Backup-NMInvalidConfig {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $directory = Split-Path -Parent $Path
    $name = 'NetworkMonitor.config.invalid-{0}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    $backupPath = Join-Path $directory $name
    Move-Item -LiteralPath $Path -Destination $backupPath -Force
}

function Save-NMConfig {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Config)

    $errors = @()
    if (-not (Test-NMConfig -Config $Config -Errors ([ref]$errors))) {
        throw ("Config is invalid: {0}" -f ($errors -join '; '))
    }

    $directory = Split-Path -Parent $script:NMConfigPath
    if (-not (Test-Path -LiteralPath $directory)) {
        $null = New-Item -ItemType Directory -Force -Path $directory
    }

    $tempPath = Join-Path $directory ('NetworkMonitor.config.{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
    $json = $Config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempPath, $json, [System.Text.UTF8Encoding]::new($false))

    try {
        if (Test-Path -LiteralPath $script:NMConfigPath) {
            $replaceBackupPath = Join-Path $directory ('NetworkMonitor.config.replacebackup.{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
            [System.IO.File]::Replace($tempPath, $script:NMConfigPath, $replaceBackupPath, $true)
            if (Test-Path -LiteralPath $replaceBackupPath) {
                Remove-Item -LiteralPath $replaceBackupPath -Force
            }
        }
        else {
            [System.IO.File]::Move($tempPath, $script:NMConfigPath)
        }
    }
    catch {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force
        }
        throw
    }
}

function Initialize-NMConfig {
    param([Parameter(Mandatory)][string]$AppRoot)

    $configRoot = Join-Path $AppRoot 'config'
    if (-not (Test-Path -LiteralPath $configRoot)) {
        $null = New-Item -ItemType Directory -Force -Path $configRoot
    }

    $script:NMConfigPath = Join-Path $configRoot 'NetworkMonitor.config.json'

    if (-not (Test-Path -LiteralPath $script:NMConfigPath)) {
        $config = Get-NMDefaultConfig
        Save-NMConfig -Config $config
        return $config
    }

    try {
        $raw = Get-Content -Raw -LiteralPath $script:NMConfigPath
        $config = ConvertTo-NMHashtable -Value ($raw | ConvertFrom-Json)
        $errors = @()
        if (-not (Test-NMConfig -Config $config -Errors ([ref]$errors))) {
            throw ($errors -join '; ')
        }
        return $config
    }
    catch {
        Backup-NMInvalidConfig -Path $script:NMConfigPath
        $config = Get-NMDefaultConfig
        Save-NMConfig -Config $config
        return $config
    }
}

function Get-NMConfigColumn {
    param([Parameter(Mandatory)][string]$Id)

    foreach ($column in @($script:NMConfig.Columns)) {
        if ([string]$column.Id -eq $Id) {
            return $column
        }
    }

    return $null
}

function Save-NMCurrentConfig {
    Save-NMConfig -Config $script:NMConfig
}

function Invoke-NMConfigEdit {
    param([Parameter(Mandatory)][scriptblock]$Edit)

    $candidate = Copy-NMDeepValue -Value $script:NMConfig
    & $Edit $candidate

    Save-NMConfig -Config $candidate
    $script:NMConfig = $candidate
    return $true
}
