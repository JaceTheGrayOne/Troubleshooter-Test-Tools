param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$ArchivePath = (Join-Path $RootPath 'archive'),
    [string]$OutputPath = (Join-Path $RootPath 'docs\Update_Diffs'),
    [int]$ContextLines = 8
)

$ErrorActionPreference = 'Stop'

function ConvertTo-RepoRelativePath {
    param(
        [Parameter(Mandatory)][string]$BasePath,
        [Parameter(Mandatory)][string]$FullPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/')
    $targetFullPath = [System.IO.Path]::GetFullPath($FullPath)
    $basePrefix = $baseFullPath + [System.IO.Path]::DirectorySeparatorChar

    if (-not $targetFullPath.StartsWith($basePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$FullPath' is not inside '$BasePath'."
    }

    return $targetFullPath.Substring($basePrefix.Length)
}

function Get-DiffOutputName {
    param(
        [Parameter(Mandatory)][System.IO.FileInfo]$ArchiveFile,
        [Parameter(Mandatory)][string]$RelativeArchivePath,
        [Parameter(Mandatory)][hashtable]$UsedOutputNames
    )

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($ArchiveFile.Name)
    $outputName = '{0}_update.diff' -f $stem

    if (-not $UsedOutputNames.ContainsKey($outputName)) {
        $UsedOutputNames[$outputName] = $RelativeArchivePath
        return $outputName
    }

    $relativeStem = [System.IO.Path]::ChangeExtension($RelativeArchivePath, $null)
    $safeStem = $relativeStem -replace '[\\/]+', '__'
    $outputName = '{0}_update.diff' -f $safeStem
    $UsedOutputNames[$outputName] = $RelativeArchivePath
    return $outputName
}

function ConvertTo-HtmlDiffReport {
    param(
        [Parameter(Mandatory)][string]$DiffPath,
        [Parameter(Mandatory)][string]$HtmlPath,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$ArchiveFile,
        [Parameter(Mandatory)][string]$CurrentFile
    )

    $style = @'
body {
    color: #1f2328;
    font-family: Consolas, "Courier New", monospace;
    margin: 24px;
}

h1 {
    font-family: Arial, sans-serif;
    font-size: 18px;
    font-weight: 700;
    margin: 0 0 8px;
}

.meta {
    color: #57606a;
    font-size: 12px;
    margin: 0 0 16px;
}

table.diff {
    border-collapse: collapse;
    font-size: 12px;
    line-height: 1.35;
    table-layout: fixed;
    width: 100%;
}

td {
    vertical-align: top;
}

.ln {
    color: #6e7781;
    padding: 0 10px 0 0;
    text-align: right;
    user-select: none;
    width: 54px;
}

.code {
    overflow-wrap: anywhere;
    padding: 0 6px;
    white-space: pre-wrap;
}

.added .ln,
.added .code {
    background: #e6ffed;
}

.removed .ln,
.removed .code {
    background: #ffeef0;
}

.hunk .ln,
.hunk .code {
    background: #ddf4ff;
    color: #0550ae;
    font-weight: 700;
}

.file .ln,
.file .code {
    background: #f6f8fa;
    color: #57606a;
}

.note .ln,
.note .code {
    background: #fff8c5;
    color: #7d4e00;
}

@media print {
    body {
        margin: 0.35in;
    }

    table.diff {
        font-size: 9pt;
    }
}
'@

    $titleEncoded = [System.Net.WebUtility]::HtmlEncode($Title)
    $archiveEncoded = [System.Net.WebUtility]::HtmlEncode($ArchiveFile)
    $currentEncoded = [System.Net.WebUtility]::HtmlEncode($CurrentFile)

    if ((Test-Path -LiteralPath $DiffPath) -and ((Get-Item -LiteralPath $DiffPath).Length -gt 0)) {
        $diffLines = @(Get-Content -LiteralPath $DiffPath)
    }
    else {
        $diffLines = @('No differences found.')
    }

    $rows = New-Object System.Collections.Generic.List[string]
    $lineNumber = 0

    foreach ($line in $diffLines) {
        $lineNumber++

        if ($line.StartsWith('@@')) {
            $className = 'hunk'
        }
        elseif ($line.StartsWith('diff --git ') -or $line.StartsWith('index ') -or $line.StartsWith('--- ') -or $line.StartsWith('+++ ')) {
            $className = 'file'
        }
        elseif ($line.StartsWith('+')) {
            $className = 'added'
        }
        elseif ($line.StartsWith('-')) {
            $className = 'removed'
        }
        elseif ($line.StartsWith('\')) {
            $className = 'note'
        }
        else {
            $className = 'context'
        }

        $lineEncoded = [System.Net.WebUtility]::HtmlEncode($line)
        if ([string]::IsNullOrEmpty($lineEncoded)) {
            $lineEncoded = '&nbsp;'
        }

        $rows.Add(('<tr class="{0}"><td class="ln">{1}</td><td class="code">{2}</td></tr>' -f $className, $lineNumber, $lineEncoded))
    }

    $bodyRows = $rows -join [Environment]::NewLine
    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$titleEncoded</title>
<style>
$style
</style>
</head>
<body>
<h1>$titleEncoded</h1>
<p class="meta">Old: $archiveEncoded<br>New: $currentEncoded</p>
<table class="diff">
<tbody>
$bodyRows
</tbody>
</table>
</body>
</html>
"@

    Set-Content -LiteralPath $HtmlPath -Value $html -Encoding UTF8
}

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCommand) {
    throw 'git was not found on PATH.'
}

$RootPath = (Resolve-Path -LiteralPath $RootPath).Path
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path

if (-not (Test-Path -LiteralPath $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}
$OutputPath = (Resolve-Path -LiteralPath $OutputPath).Path

$archiveFiles = Get-ChildItem -LiteralPath $ArchivePath -Recurse -File | Sort-Object FullName
if (-not $archiveFiles) {
    Write-Warning "No files found in archive path: $ArchivePath"
    exit 0
}

$usedOutputNames = @{}
$created = @()
$skipped = @()

Push-Location $RootPath
try {
    foreach ($archiveFile in $archiveFiles) {
        $relativeArchiveChildPath = ConvertTo-RepoRelativePath -BasePath $ArchivePath -FullPath $archiveFile.FullName
        $currentFilePath = Join-Path $RootPath $relativeArchiveChildPath

        if (-not (Test-Path -LiteralPath $currentFilePath -PathType Leaf)) {
            $skipped += $relativeArchiveChildPath
            Write-Warning "Skipping '$relativeArchiveChildPath' because no current file exists at the matching repo path."
            continue
        }

        $repoRelativeArchiveChildPath = $relativeArchiveChildPath -replace '\\', '/'
        $archiveRepoPath = 'archive/{0}' -f $repoRelativeArchiveChildPath
        $currentRepoPath = $repoRelativeArchiveChildPath
        $outputName = Get-DiffOutputName -ArchiveFile $archiveFile -RelativeArchivePath $relativeArchiveChildPath -UsedOutputNames $usedOutputNames
        $diffPath = Join-Path $OutputPath $outputName
        $htmlPath = [System.IO.Path]::ChangeExtension($diffPath, '.html')

        $diffArgs = @(
            '-c',
            'core.autocrlf=false',
            '-c',
            'core.safecrlf=false',
            'diff',
            '--no-index',
            '--patience',
            "--unified=$ContextLines",
            "--output=$diffPath",
            '--',
            $archiveRepoPath,
            $currentRepoPath
        )

        & git @diffArgs
        $exitCode = $LASTEXITCODE

        if ($exitCode -notin @(0, 1)) {
            throw "git diff failed for '$relativeArchiveChildPath' with exit code $exitCode."
        }

        if (-not (Test-Path -LiteralPath $diffPath)) {
            New-Item -ItemType File -Path $diffPath | Out-Null
        }

        ConvertTo-HtmlDiffReport `
            -DiffPath $diffPath `
            -HtmlPath $htmlPath `
            -Title ([System.IO.Path]::GetFileName($htmlPath)) `
            -ArchiveFile $archiveRepoPath `
            -CurrentFile $currentRepoPath

        $created += [pscustomobject]@{
            ArchiveFile = $archiveRepoPath
            CurrentFile = $currentRepoPath
            DiffFile = $diffPath
            HtmlFile = $htmlPath
            HasChanges = ((Get-Item -LiteralPath $diffPath).Length -gt 0)
        }
    }
}
finally {
    Pop-Location
}

Write-Host "Created $($created.Count) diff/html file set(s) in $OutputPath"
foreach ($item in $created) {
    $changeLabel = if ($item.HasChanges) { 'changed' } else { 'no changes' }
    Write-Host ("{0} -> {1}, {2} ({3})" -f $item.ArchiveFile, (Split-Path -Leaf $item.DiffFile), (Split-Path -Leaf $item.HtmlFile), $changeLabel)
}

if ($skipped.Count -gt 0) {
    Write-Warning "Skipped $($skipped.Count) archive file(s) with no matching current file."
}
