if (-not ('NetworkMonitorForm' -as [type])) {
    $nmTypeReferences = @(
        [System.Windows.Forms.Form].Assembly.Location
        [System.Windows.Forms.Message].Assembly.Location
        [System.Drawing.Point].Assembly.Location
        [System.ComponentModel.Component].Assembly.Location
    ) | Select-Object -Unique

    Add-Type -ReferencedAssemblies $nmTypeReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class NetworkMonitorForm : Form {
    public int ResizeGripSize = 8;

    protected override void WndProc(ref Message m) {
        const int WM_NCHITTEST = 0x0084;
        const int HTLEFT = 10;
        const int HTRIGHT = 11;
        const int HTTOP = 12;
        const int HTTOPLEFT = 13;
        const int HTTOPRIGHT = 14;
        const int HTBOTTOM = 15;
        const int HTBOTTOMLEFT = 16;
        const int HTBOTTOMRIGHT = 17;

        base.WndProc(ref m);

        if (m.Msg != WM_NCHITTEST || this.WindowState != FormWindowState.Normal) {
            return;
        }

        long value = m.LParam.ToInt64();
        int x = unchecked((short)(value & 0xffff));
        int y = unchecked((short)((value >> 16) & 0xffff));
        Point point = this.PointToClient(new Point(x, y));

        bool left = point.X <= ResizeGripSize;
        bool right = point.X >= this.ClientSize.Width - ResizeGripSize;
        bool top = point.Y <= ResizeGripSize;
        bool bottom = point.Y >= this.ClientSize.Height - ResizeGripSize;

        if (left && top) m.Result = (IntPtr)HTTOPLEFT;
        else if (right && top) m.Result = (IntPtr)HTTOPRIGHT;
        else if (left && bottom) m.Result = (IntPtr)HTBOTTOMLEFT;
        else if (right && bottom) m.Result = (IntPtr)HTBOTTOMRIGHT;
        else if (left) m.Result = (IntPtr)HTLEFT;
        else if (right) m.Result = (IntPtr)HTRIGHT;
        else if (top) m.Result = (IntPtr)HTTOP;
        else if (bottom) m.Result = (IntPtr)HTBOTTOM;
    }
}

public static class NetworkMonitorNative {
    [DllImport("user32.dll")]
    public static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
'@
}

function Initialize-NMTheme {
    $script:NMColors = @{
        Window = [System.Drawing.ColorTranslator]::FromHtml('#080d10')
        TitleBar = [System.Drawing.ColorTranslator]::FromHtml('#101619')
        TitleBarHover = [System.Drawing.ColorTranslator]::FromHtml('#1b2429')
        TitleBarPressed = [System.Drawing.ColorTranslator]::FromHtml('#263239')
        Surface = [System.Drawing.ColorTranslator]::FromHtml('#0d1417')
        SurfaceAlt = [System.Drawing.ColorTranslator]::FromHtml('#151d22')
        Grid = [System.Drawing.ColorTranslator]::FromHtml('#0b1215')
        GridAlt = [System.Drawing.ColorTranslator]::FromHtml('#0f171b')
        GridLine = [System.Drawing.ColorTranslator]::FromHtml('#333b42')
        Border = [System.Drawing.ColorTranslator]::FromHtml('#4b5258')
        Text = [System.Drawing.ColorTranslator]::FromHtml('#f3f5f7')
        Muted = [System.Drawing.ColorTranslator]::FromHtml('#aeb7bf')
        Accent = [System.Drawing.ColorTranslator]::FromHtml('#5db8ff')
        AccentDark = [System.Drawing.ColorTranslator]::FromHtml('#0078d4')
        Green = [System.Drawing.ColorTranslator]::FromHtml('#61e243')
        Yellow = [System.Drawing.ColorTranslator]::FromHtml('#f5cf4f')
        Orange = [System.Drawing.ColorTranslator]::FromHtml('#ff9a3d')
        Red = [System.Drawing.ColorTranslator]::FromHtml('#ff4438')
        Disabled = [System.Drawing.ColorTranslator]::FromHtml('#777d82')
    }

    $script:NMFonts = @{
        Title = [System.Drawing.Font]::new('Segoe UI', 12, [System.Drawing.FontStyle]::Regular)
        GridHeader = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        Grid = [System.Drawing.Font]::new('Consolas', 11, [System.Drawing.FontStyle]::Regular)
        GridBold = [System.Drawing.Font]::new('Consolas', 11, [System.Drawing.FontStyle]::Bold)
        SettingsTitle = [System.Drawing.Font]::new('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
        Settings = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
        SettingsBold = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
        Mono = [System.Drawing.Font]::new('Consolas', 9, [System.Drawing.FontStyle]::Regular)
    }
}

function Get-NMPoint {
    param([int]$X, [int]$Y)
    return [System.Drawing.Point]::new($X, $Y)
}

function Get-NMSize {
    param([int]$Width, [int]$Height)
    return [System.Drawing.Size]::new($Width, $Height)
}

function Get-NMRectangle {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height)
    return [System.Drawing.Rectangle]::new($X, $Y, $Width, $Height)
}

function Get-NMThemeColor {
    param([Parameter(Mandatory)][string]$Name)

    if ($script:NMColors.ContainsKey($Name)) {
        return $script:NMColors[$Name]
    }

    return $script:NMColors.Text
}

function ConvertTo-NMDrawingColor {
    param([Parameter(Mandatory)][string]$HtmlColor)

    return [System.Drawing.ColorTranslator]::FromHtml($HtmlColor)
}

function Add-NMSafeEvent {
    param(
        [Parameter(Mandatory)]$Control,
        [Parameter(Mandatory)][string]$EventName,
        [Parameter(Mandatory)][scriptblock]$Handler
    )

    $adder = 'Add_{0}' -f $EventName
    $Control.$adder($Handler.GetNewClosure())
}

function New-NMAppWindow {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][System.Drawing.Size]$Size,
        [Parameter(Mandatory)][System.Drawing.Size]$MinimumSize,
        [bool]$ShowInTaskbar,
        [bool]$TopMost,
        [bool]$Resizable
    )

    $form = if ($Resizable) {
        [NetworkMonitorForm]::new()
    }
    else {
        [System.Windows.Forms.Form]::new()
    }

    $form.Name = $Name
    $form.Text = $Title
    $form.Size = $Size
    $form.MinimumSize = $MinimumSize
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    $form.ShowInTaskbar = $ShowInTaskbar
    $form.TopMost = $TopMost
    $form.BackColor = $script:NMColors.Window
    $form.ForeColor = $script:NMColors.Text
    $form.Font = $script:NMFonts.Settings
    $form.KeyPreview = $true
    $form.MaximizeBox = $Resizable
    $form.MinimizeBox = $true

    $form.Add_Paint({
        param($sender, $eventArgs)

        $pen = [System.Drawing.Pen]::new($script:NMColors.Border, 1)
        try {
            $eventArgs.Graphics.DrawRectangle($pen, 0, 0, $sender.ClientSize.Width - 1, $sender.ClientSize.Height - 1)
        }
        finally {
            $pen.Dispose()
        }
    })

    return $form
}

function Set-NMTitleButtonMargin {
    param([Parameter(Mandatory)][System.Windows.Forms.Control]$Control)

    $Control.Margin = [System.Windows.Forms.Padding]::new(3, 4, 3, 4)
}

function Invoke-NMFormMaximizeToggle {
    param([Parameter(Mandatory)][System.Windows.Forms.Form]$Form)

    if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
        $Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
    }
    else {
        $Form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
    }
}

function Enable-NMWindowDrag {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory)][System.Windows.Forms.Form]$Form,
        [switch]$EnableDoubleClickMaximize
    )

    $targetForm = $Form

    if ($EnableDoubleClickMaximize) {
        $Control.Add_MouseDoubleClick({
            param($sender, $eventArgs)
            [void]$sender

            if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                Invoke-NMFormMaximizeToggle -Form $targetForm
            }
        }.GetNewClosure())
    }

    $Control.Add_MouseDown({
        param($sender, $eventArgs)
        [void]$sender

        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [NetworkMonitorNative]::ReleaseCapture() | Out-Null
            [NetworkMonitorNative]::SendMessage($targetForm.Handle, 0xA1, 0x2, 0) | Out-Null
        }
    }.GetNewClosure())
}

function New-NMTitleBar {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Form]$Form,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Buttons,
        [switch]$CanMaximize,
        [int]$Height = 46
    )

    $titleBar = [System.Windows.Forms.Panel]::new()
    $titleBar.Name = 'NMTitleBar'
    $titleBar.Dock = [System.Windows.Forms.DockStyle]::Top
    $titleBar.Height = $Height
    $titleBar.BackColor = $script:NMColors.TitleBar
    Enable-NMWindowDrag -Control $titleBar -Form $Form -EnableDoubleClickMaximize:$CanMaximize

    $buttonPanel = [System.Windows.Forms.FlowLayoutPanel]::new()
    $buttonPanel.Name = 'NMTitleButtonPanel'
    $buttonPanel.Dock = [System.Windows.Forms.DockStyle]::Right
    $buttonPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $buttonPanel.WrapContents = $false
    $buttonPanel.Padding = [System.Windows.Forms.Padding]::new(4, 0, 8, 0)
    $buttonPanel.BackColor = $script:NMColors.TitleBar

    $buttonMap = @{}
    $panelWidth = 12
    foreach ($definition in @($Buttons)) {
        if ([string]$definition.Kind -eq 'Separator') {
            $panelWidth += 17
        }
        else {
            $panelWidth += 44
        }
    }
    $buttonPanel.Width = [math]::Max(50, $panelWidth)

    $titleLabel = [System.Windows.Forms.Label]::new()
    $titleLabel.Name = 'NMTitleLabel'
    $titleLabel.Text = $Title
    $titleLabel.AutoSize = $false
    $titleLabel.AutoEllipsis = $true
    $titleLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titleLabel.Padding = [System.Windows.Forms.Padding]::new(18, 0, 8, 0)
    $titleLabel.BackColor = $script:NMColors.TitleBar
    $titleLabel.ForeColor = $script:NMColors.Text
    $titleLabel.Font = $script:NMFonts.Title
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    Enable-NMWindowDrag -Control $titleLabel -Form $Form -EnableDoubleClickMaximize:$CanMaximize

    $titleBar.Controls.Add($titleLabel)
    $titleBar.Controls.Add($buttonPanel)

    foreach ($definition in @($Buttons)) {
        if ([string]$definition.Kind -eq 'Separator') {
            $separator = [System.Windows.Forms.Panel]::new()
            $separator.Size = Get-NMSize 1 30
            $separator.Margin = [System.Windows.Forms.Padding]::new(8, 8, 8, 8)
            $separator.BackColor = $script:NMColors.GridLine
            $buttonPanel.Controls.Add($separator)
            continue
        }

        $key = if (-not [string]::IsNullOrWhiteSpace([string]$definition.Key)) { [string]$definition.Key } else { [string]$definition.Kind }
        $toolTip = if (-not [string]::IsNullOrWhiteSpace([string]$definition.ToolTip)) { [string]$definition.ToolTip } else { $key }
        $button = New-NMIconButton -Parent $buttonPanel -Kind ([string]$definition.Kind) -ToolTipText $toolTip -Bounds @(0, 0, 38, 38) -OnClick $definition.OnClick
        $button.Name = 'NMTitleButton{0}' -f $key
        Set-NMTitleButtonMargin -Control $button
        if ($definition.Active) {
            Set-NMIconButtonActive -Button $button -Active ([bool]$definition.Active)
        }
        $buttonMap[$key] = $button
    }

    return [pscustomobject]@{
        Panel = $titleBar
        Buttons = $buttonMap
        TitleLabel = $titleLabel
    }
}

function Use-NMButtonTheme {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Button]$Button,
        [switch]$Primary
    )

    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderColor = if ($Primary) { $script:NMColors.AccentDark } else { $script:NMColors.Border }
    $Button.FlatAppearance.MouseOverBackColor = if ($Primary) { $script:NMColors.AccentDark } else { $script:NMColors.TitleBarHover }
    $Button.BackColor = if ($Primary) { $script:NMColors.AccentDark } else { $script:NMColors.SurfaceAlt }
    $Button.ForeColor = $script:NMColors.Text
    $Button.Font = $script:NMFonts.Settings
}

function New-NMButton {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int[]]$Bounds,
        [scriptblock]$OnClick = $null,
        [switch]$Primary
    )

    $button = [System.Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Location = Get-NMPoint $Bounds[0] $Bounds[1]
    $button.Size = Get-NMSize $Bounds[2] $Bounds[3]
    Use-NMButtonTheme -Button $button -Primary:$Primary
    if ($OnClick) {
        $button.Tag = [pscustomobject]@{ OnClick = $OnClick }
        $button.Add_Click({
            param($sender, $eventArgs)
            if ($sender.Tag -and $sender.Tag.OnClick) {
                & $sender.Tag.OnClick $sender $eventArgs
            }
        })
    }
    $Parent.Controls.Add($button)
    return $button
}

function New-NMLabel {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int[]]$Bounds,
        [System.Drawing.Font]$Font = $script:NMFonts.Settings,
        [System.Drawing.Color]$ForeColor = $script:NMColors.Text
    )

    $label = [System.Windows.Forms.Label]::new()
    $label.Text = $Text
    $label.Location = Get-NMPoint $Bounds[0] $Bounds[1]
    $label.Size = Get-NMSize $Bounds[2] $Bounds[3]
    $label.BackColor = $Parent.BackColor
    $label.ForeColor = $ForeColor
    $label.Font = $Font
    $Parent.Controls.Add($label)
    return $label
}

function Use-NMTextBoxTheme {
    param([Parameter(Mandatory)][System.Windows.Forms.TextBox]$TextBox)

    $TextBox.BackColor = $script:NMColors.Surface
    $TextBox.ForeColor = $script:NMColors.Text
    $TextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $TextBox.Font = $script:NMFonts.Settings
}

function Draw-NMIcon {
    param(
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][System.Drawing.Graphics]$Graphics,
        [Parameter(Mandatory)][System.Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory)][System.Drawing.Color]$Color
    )

    $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $pen = [System.Drawing.Pen]::new($Color, 2.0)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $brush = [System.Drawing.SolidBrush]::new($Color)

    try {
        $cx = $Bounds.Left + [int]($Bounds.Width / 2)
        $cy = $Bounds.Top + [int]($Bounds.Height / 2)

        switch ($Kind) {
            'Settings' {
                for ($i = 0; $i -lt 8; $i++) {
                    $angle = ($i * [math]::PI) / 4
                    $x1 = $cx + [int]([math]::Cos($angle) * 8)
                    $y1 = $cy + [int]([math]::Sin($angle) * 8)
                    $x2 = $cx + [int]([math]::Cos($angle) * 12)
                    $y2 = $cy + [int]([math]::Sin($angle) * 12)
                    $Graphics.DrawLine($pen, $x1, $y1, $x2, $y2)
                }
                $Graphics.DrawEllipse($pen, (Get-NMRectangle ($cx - 8) ($cy - 8) 16 16))
                $Graphics.DrawEllipse($pen, (Get-NMRectangle ($cx - 3) ($cy - 3) 6 6))
            }
            'Refresh' {
                $Graphics.DrawArc($pen, (Get-NMRectangle ($cx - 11) ($cy - 11) 22 22), 35, 275)
                $Graphics.DrawLine($pen, $cx + 9, $cy - 11, $cx + 13, $cy - 4)
                $Graphics.DrawLine($pen, $cx + 9, $cy - 11, $cx + 2, $cy - 10)
            }
            'Pin' {
                $points = [System.Drawing.Point[]]@(
                    (Get-NMPoint ($cx - 4) ($cy - 13)),
                    (Get-NMPoint ($cx + 10) ($cy + 1)),
                    (Get-NMPoint ($cx + 5) ($cy + 6)),
                    (Get-NMPoint ($cx - 9) ($cy - 8))
                )
                $Graphics.DrawPolygon($pen, $points)
                $Graphics.DrawLine($pen, $cx + 3, $cy + 4, $cx - 10, $cy + 15)
                $Graphics.DrawLine($pen, $cx - 3, $cy + 2, $cx - 12, $cy + 11)
            }
            'Minimize' {
                $Graphics.DrawLine($pen, $cx - 11, $cy + 5, $cx + 11, $cy + 5)
            }
            'Maximize' {
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 9) ($cy - 9) 18 18))
            }
            'Restore' {
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 6) ($cy - 10) 15 15))
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 10) ($cy - 5) 15 15))
            }
            'Close' {
                $Graphics.DrawLine($pen, $cx - 10, $cy - 10, $cx + 10, $cy + 10)
                $Graphics.DrawLine($pen, $cx + 10, $cy - 10, $cx - 10, $cy + 10)
            }
            'Monitor' {
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 16) ($cy - 12) 22 14))
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 6) ($cy - 3) 22 14))
                $Graphics.DrawLine($pen, $cx - 5, $cy + 5, $cx + 6, $cy + 5)
                $Graphics.DrawLine($pen, $cx + 3, $cy + 11, $cx + 8, $cy + 11)
                $Graphics.FillRectangle($brush, (Get-NMRectangle ($cx - 11) ($cy - 8) 5 2))
                $Graphics.FillRectangle($brush, (Get-NMRectangle ($cx - 4) ($cy - 8) 5 2))
                $Graphics.FillRectangle($brush, (Get-NMRectangle ($cx + 3) ($cy - 8) 5 2))
            }
        }
    }
    finally {
        $pen.Dispose()
        $brush.Dispose()
    }
}

function New-NMIconButton {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][string]$ToolTipText,
        [Parameter(Mandatory)][int[]]$Bounds,
        [scriptblock]$OnClick = $null
    )

    $button = [System.Windows.Forms.Panel]::new()
    $button.Location = Get-NMPoint $Bounds[0] $Bounds[1]
    $button.Size = Get-NMSize $Bounds[2] $Bounds[3]
    $button.BackColor = $script:NMColors.TitleBar
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.Tag = [pscustomobject]@{
        Kind = $Kind
        Hover = $false
        Pressed = $false
        Active = $false
        OnClick = $OnClick
    }

    $button.Add_MouseEnter({
        param($sender, $eventArgs)
        [void]$eventArgs
        $sender.Tag.Hover = $true
        $sender.Invalidate()
    })
    $button.Add_MouseLeave({
        param($sender, $eventArgs)
        [void]$eventArgs
        $sender.Tag.Hover = $false
        $sender.Tag.Pressed = $false
        $sender.Invalidate()
    })
    $button.Add_MouseDown({
        param($sender, $eventArgs)
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $sender.Tag.Pressed = $true
            $sender.Invalidate()
        }
    })
    $button.Add_MouseUp({
        param($sender, $eventArgs)
        $wasPressed = [bool]$sender.Tag.Pressed
        $sender.Tag.Pressed = $false
        $sender.Invalidate()
        if ($wasPressed -and $eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left -and $sender.Tag.OnClick) {
            & $sender.Tag.OnClick $sender $eventArgs
        }
    })

    $button.Add_Paint({
        param($sender, $paintEventArgs)
        $state = $sender.Tag
        $background = if ($state.Pressed) {
            $script:NMColors.TitleBarPressed
        }
        elseif ($state.Hover) {
            $script:NMColors.TitleBarHover
        }
        else {
            $script:NMColors.TitleBar
        }

        $brush = [System.Drawing.SolidBrush]::new($background)
        try {
            $paintEventArgs.Graphics.FillRectangle($brush, $sender.ClientRectangle)
        }
        finally {
            $brush.Dispose()
        }
        $color = if ($state.Active) { $script:NMColors.Accent } else { $script:NMColors.Text }
        Draw-NMIcon -Kind ([string]$state.Kind) -Graphics $paintEventArgs.Graphics -Bounds $sender.ClientRectangle -Color $color
    })

    $toolTip = [System.Windows.Forms.ToolTip]::new()
    $toolTip.SetToolTip($button, $ToolTipText)
    $Parent.Controls.Add($button)
    return $button
}

function Set-NMIconButtonActive {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Button,
        [bool]$Active
    )

    $Button.Tag.Active = $Active
    $Button.Invalidate()
}

function Set-NMIconButtonKind {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Button,
        [Parameter(Mandatory)][string]$Kind
    )

    $Button.Tag.Kind = $Kind
    $Button.Invalidate()
}

function Enable-NMTitleDrag {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory)][System.Windows.Forms.Form]$Form
    )

    Enable-NMWindowDrag -Control $Control -Form $Form -EnableDoubleClickMaximize
}
