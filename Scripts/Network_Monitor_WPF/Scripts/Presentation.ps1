function New-NMColumnPresentation {
    param(
        [AllowEmptyString()][string]$Text = '',
        [AllowNull()][System.Windows.Media.Brush]$Foreground = $null,
        [string]$FontWeight = 'Normal',
        [string]$TemplateKind = 'Text',
        [string]$HorizontalAlignment = 'Left'
    )

    if (-not $Foreground) {
        $Foreground = Get-NMThemeBrush -Name 'Text'
    }

    return [pscustomobject]@{
        Text = $Text
        Foreground = $Foreground
        FontWeight = $FontWeight
        TemplateKind = $TemplateKind
        HorizontalAlignment = $HorizontalAlignment
    }
}

function Get-NMReplyValueText {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [AllowNull()]$Value
    )

    if ($State.LatestSuccess -and $null -ne $Value) {
        return [string]$Value
    }

    return (Get-NMNeutralValue)
}

function Get-NMReplyValueBrush {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [AllowNull()]$Value
    )

    if ($State.LatestSuccess -and $null -ne $Value) {
        return (Get-NMThemeBrush -Name 'Text')
    }

    return (Get-NMThemeBrush -Name 'Muted')
}

function Get-NMHistorySampleBrush {
    param([AllowNull()]$Sample)

    if ($null -eq $Sample) {
        return (Get-NMThemeBrush -Name 'Yellow')
    }

    if ([bool]$Sample) {
        return (Get-NMThemeBrush -Name 'Green')
    }

    return (Get-NMThemeBrush -Name 'Red')
}

function Get-NMColumnPresentation {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ColumnId
    )

    switch ($ColumnId) {
        'Node' {
            return New-NMColumnPresentation -Text ([string]$Target.Name) -Foreground (ConvertTo-NMWpfBrush -HtmlColor ([string]$Target.Color)) -FontWeight 'Bold'
        }
        'Address' {
            return New-NMColumnPresentation -Text ([string]$Target.Address)
        }
        'Status' {
            return New-NMColumnPresentation -Text (Get-NMStatusText -State $State) -Foreground (Get-NMThemeBrush -Name (Get-NMHealthName -State $State)) -FontWeight 'Bold' -TemplateKind 'Status'
        }
        'RTT' {
            return New-NMColumnPresentation -Text (Get-NMRttText -State $State) -Foreground (Get-NMThemeBrush -Name (Get-NMRttHealthName -State $State))
        }
        'Loss' {
            return New-NMColumnPresentation -Text (Get-NMLossText -State $State) -Foreground (Get-NMThemeBrush -Name (Get-NMLossHealthName -State $State))
        }
        'TTL' {
            return New-NMColumnPresentation -Text (Get-NMReplyValueText -State $State -Value $State.LatestTtl) -Foreground (Get-NMReplyValueBrush -State $State -Value $State.LatestTtl)
        }
        'Bytes' {
            return New-NMColumnPresentation -Text (Get-NMReplyValueText -State $State -Value $State.LatestBytes) -Foreground (Get-NMReplyValueBrush -State $State -Value $State.LatestBytes)
        }
        'History' {
            return New-NMColumnPresentation -TemplateKind 'History'
        }
        default {
            return New-NMColumnPresentation
        }
    }
}
