function New-NMColumnPresentation {
    param(
        [AllowEmptyString()][string]$Text = '',
        [System.Drawing.Color]$ForeColor = $script:NMColors.Text,
        [System.Drawing.Font]$Font = $script:NMFonts.Grid,
        [string]$PaintKind = 'Text',
        [System.Windows.Forms.DataGridViewContentAlignment]$Align = [System.Windows.Forms.DataGridViewContentAlignment]::MiddleLeft
    )

    return [pscustomobject]@{
        Text = $Text
        ForeColor = $ForeColor
        Font = $Font
        PaintKind = $PaintKind
        Align = $Align
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

function Get-NMReplyValueColor {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [AllowNull()]$Value
    )

    if ($State.LatestSuccess -and $null -ne $Value) {
        return $script:NMColors.Text
    }

    return $script:NMColors.Muted
}

function Get-NMHistorySampleColor {
    param([AllowNull()]$Sample)

    if ($null -eq $Sample) {
        return $script:NMColors.Yellow
    }

    if ([bool]$Sample) {
        return $script:NMColors.Green
    }

    return $script:NMColors.Red
}

function Get-NMColumnPresentation {
    param(
        [Parameter(Mandatory)][hashtable]$State,
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)][string]$ColumnId
    )

    switch ($ColumnId) {
        'Node' {
            return New-NMColumnPresentation -Text ([string]$Target.Name) -ForeColor (ConvertTo-NMDrawingColor -HtmlColor ([string]$Target.Color)) -Font $script:NMFonts.GridBold
        }
        'Address' {
            return New-NMColumnPresentation -Text ([string]$Target.Address)
        }
        'Status' {
            return New-NMColumnPresentation -Text (Get-NMStatusText -State $State) -ForeColor (Get-NMThemeColor -Name (Get-NMHealthName -State $State)) -Font $script:NMFonts.GridBold -PaintKind 'Status'
        }
        'RTT' {
            return New-NMColumnPresentation -Text (Get-NMRttText -State $State) -ForeColor (Get-NMThemeColor -Name (Get-NMRttHealthName -State $State))
        }
        'Loss' {
            return New-NMColumnPresentation -Text (Get-NMLossText -State $State) -ForeColor (Get-NMThemeColor -Name (Get-NMLossHealthName -State $State))
        }
        'TTL' {
            return New-NMColumnPresentation -Text (Get-NMReplyValueText -State $State -Value $State.LatestTtl) -ForeColor (Get-NMReplyValueColor -State $State -Value $State.LatestTtl)
        }
        'Bytes' {
            return New-NMColumnPresentation -Text (Get-NMReplyValueText -State $State -Value $State.LatestBytes) -ForeColor (Get-NMReplyValueColor -State $State -Value $State.LatestBytes)
        }
        'History' {
            return New-NMColumnPresentation -PaintKind 'History'
        }
        default {
            return New-NMColumnPresentation
        }
    }
}
