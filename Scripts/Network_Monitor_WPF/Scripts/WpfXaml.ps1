function Import-NMXaml {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "XAML file was not found: $Path"
    }

    $reader = $null
    try {
        $reader = [System.Xml.XmlReader]::Create($Path)
        return [System.Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        throw "Unable to load XAML '$Path': $($_.Exception.Message)"
    }
    finally {
        if ($reader) {
            $reader.Close()
        }
    }
}

function Get-NMNamedElement {
    param(
        [Parameter(Mandatory)][System.Windows.FrameworkElement]$Root,
        [Parameter(Mandatory)][string]$Name
    )

    $element = $Root.FindName($Name)
    if (-not $element) {
        throw "Required XAML element '$Name' was not found."
    }
    return $element
}

function New-NMControlMap {
    param(
        [Parameter(Mandatory)][System.Windows.FrameworkElement]$Root,
        [Parameter(Mandatory)][string[]]$Names
    )

    $map = @{}
    foreach ($name in $Names) {
        $map[$name] = Get-NMNamedElement -Root $Root -Name $name
    }
    return $map
}

function Import-NMWindowXaml {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$RequiredNames
    )

    $window = Import-NMXaml -Path $Path
    if (-not ($window -is [System.Windows.Window])) {
        throw "XAML root must be a System.Windows.Window: $Path"
    }

    $controls = New-NMControlMap -Root $window -Names $RequiredNames
    return [pscustomobject]@{
        Window = $window
        Controls = $controls
    }
}
