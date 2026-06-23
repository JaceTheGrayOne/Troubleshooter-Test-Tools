function Set-NMWpfWindowChrome {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [double]$CaptionHeight = 0
    )

    $chrome = [System.Windows.Shell.WindowChrome]::new()
    $chrome.CaptionHeight = $CaptionHeight
    $chrome.CornerRadius = [System.Windows.CornerRadius]::new(0)
    $chrome.GlassFrameThickness = [System.Windows.Thickness]::new(0)
    $chrome.ResizeBorderThickness = [System.Windows.Thickness]::new(6)
    $chrome.UseAeroCaptionButtons = $false
    [System.Windows.Shell.WindowChrome]::SetWindowChrome($Window, $chrome)
}

function Invoke-NMWpfMaximizeToggle {
    param([Parameter(Mandatory)][System.Windows.Window]$Window)

    if ($Window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $Window.WindowState = [System.Windows.WindowState]::Normal
    }
    else {
        $Window.WindowState = [System.Windows.WindowState]::Maximized
    }
}

function Register-NMWpfTitleDrag {
    param(
        [Parameter(Mandatory)][System.Windows.FrameworkElement]$TitleBar,
        [Parameter(Mandatory)][System.Windows.Window]$Window,
        [switch]$CanMaximize
    )

    $TitleBar.Add_MouseLeftButtonDown({
        param($sender, $eventArgs)
        [void]$sender
        try {
            if ($CanMaximize -and $eventArgs.ClickCount -eq 2) {
                Invoke-NMWpfMaximizeToggle -Window $Window
                $eventArgs.Handled = $true
                return
            }

            if ($eventArgs.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
                $Window.DragMove()
            }
        }
        catch {
            Write-NMDebugLog -Message ("Title drag failed: {0}" -f $_.Exception.Message)
        }
    }.GetNewClosure())
}

function Set-NMTitleButtonActive {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.Button]$Button,
        [bool]$Active
    )

    $Button.Tag = [pscustomobject]@{
        Active = $Active
        Kind = if ($Button.Tag -and $Button.Tag.PSObject.Properties['Kind']) { [string]$Button.Tag.Kind } else { '' }
    }
    $Button.Foreground = if ($Active) { Get-NMThemeBrush -Name 'Accent' } else { Get-NMThemeBrush -Name 'Text' }
}

function Find-NMWpfDescendantByName {
    param(
        [Parameter(Mandatory)][System.Windows.DependencyObject]$Root,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Root -is [System.Windows.FrameworkElement] -and $Root.Name -eq $Name) {
        return $Root
    }

    $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Root)
    for ($i = 0; $i -lt $count; $i++) {
        $child = [System.Windows.Media.VisualTreeHelper]::GetChild($Root, $i)
        $found = Find-NMWpfDescendantByName -Root $child -Name $Name
        if ($found) {
            return $found
        }
    }

    return $null
}

function Set-NMIconButtonKind {
    param(
        [Parameter(Mandatory)][System.Windows.Controls.Button]$Button,
        [Parameter(Mandatory)][string]$Kind
    )

    $active = if ($Button.Tag -and $Button.Tag.PSObject.Properties['Active']) { [bool]$Button.Tag.Active } else { $false }
    $Button.Tag = [pscustomobject]@{
        Active = $active
        Kind = $Kind
    }

    $glyph = Find-NMWpfDescendantByName -Root $Button -Name 'MaximizeGlyph'
    if ($glyph -and $glyph -is [System.Windows.Controls.TextBlock]) {
        $glyph.Text = if ($Kind -eq 'Restore') { [string][char]0xE923 } else { [string][char]0xE922 }
        return
    }

    $maxPath = Find-NMWpfDescendantByName -Root $Button -Name 'MaximizePath'
    $restorePathA = Find-NMWpfDescendantByName -Root $Button -Name 'RestorePathA'
    $restorePathB = Find-NMWpfDescendantByName -Root $Button -Name 'RestorePathB'
    if ($maxPath -and $restorePathA -and $restorePathB) {
        if ($Kind -eq 'Restore') {
            $maxPath.Visibility = [System.Windows.Visibility]::Collapsed
            $restorePathA.Visibility = [System.Windows.Visibility]::Visible
            $restorePathB.Visibility = [System.Windows.Visibility]::Visible
        }
        else {
            $maxPath.Visibility = [System.Windows.Visibility]::Visible
            $restorePathA.Visibility = [System.Windows.Visibility]::Collapsed
            $restorePathB.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}
