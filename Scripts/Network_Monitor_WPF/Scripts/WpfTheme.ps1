$script:NMTitleBarHeight = 46
$script:NMGridHeaderHeight = 38
$script:NMGridRowHeight = 52

$script:NMThemeHex = [ordered]@{
    Window = '#080d10'
    TitleBar = '#101619'
    TitleBarHover = '#1b2429'
    TitleBarPressed = '#263239'
    Surface = '#0d1417'
    SurfaceAlt = '#151d22'
    Grid = '#0b1215'
    GridAlt = '#0f171b'
    GridLine = '#333b42'
    Border = '#4b5258'
    Text = '#f3f5f7'
    Muted = '#aeb7bf'
    Accent = '#5db8ff'
    AccentDark = '#0078d4'
    Green = '#61e243'
    Yellow = '#f5cf4f'
    Orange = '#ff9a3d'
    Red = '#ff4438'
    Disabled = '#777d82'
}

function New-NMWpfBrush {
    param(
        [Parameter(Mandatory)][string]$Hex,
        [switch]$Mutable
    )

    $brush = [System.Windows.Media.SolidColorBrush]::new(
        [System.Windows.Media.ColorConverter]::ConvertFromString($Hex)
    )
    if (-not $Mutable) {
        $brush.Freeze()
    }
    return $brush
}

function Initialize-NMWpfTheme {
    $script:NMBrushes = @{}
    foreach ($name in $script:NMThemeHex.Keys) {
        $script:NMBrushes[$name] = New-NMWpfBrush -Hex $script:NMThemeHex[$name]
    }
}

function Get-NMThemeBrush {
    param([Parameter(Mandatory)][string]$Name)

    if (-not $script:NMBrushes -or -not $script:NMBrushes.ContainsKey($Name)) {
        if (-not $script:NMBrushes) {
            Initialize-NMWpfTheme
        }
    }

    if ($script:NMBrushes.ContainsKey($Name)) {
        return $script:NMBrushes[$Name]
    }

    return $script:NMBrushes.Text
}

function ConvertTo-NMWpfBrush {
    param([Parameter(Mandatory)][string]$HtmlColor)

    if (-not (Test-NMHtmlColor -Color $HtmlColor)) {
        return (Get-NMThemeBrush -Name 'Text')
    }

    $key = $HtmlColor.ToLowerInvariant()
    if (-not $script:NMTargetBrushCache) {
        $script:NMTargetBrushCache = @{}
    }
    if (-not $script:NMTargetBrushCache.ContainsKey($key)) {
        $script:NMTargetBrushCache[$key] = New-NMWpfBrush -Hex $key
    }
    return $script:NMTargetBrushCache[$key]
}

function Get-NMBrushHex {
    param([Parameter(Mandatory)][System.Windows.Media.SolidColorBrush]$Brush)

    $color = $Brush.Color
    return ('#{0:x2}{1:x2}{2:x2}' -f $color.R, $color.G, $color.B)
}
