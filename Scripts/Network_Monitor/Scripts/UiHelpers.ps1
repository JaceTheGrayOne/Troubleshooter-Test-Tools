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
        Title = [System.Drawing.Font]::new('Segoe UI', 18, [System.Drawing.FontStyle]::Regular)
        GridHeader = [System.Drawing.Font]::new('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
        Grid = [System.Drawing.Font]::new('Consolas', 15, [System.Drawing.FontStyle]::Regular)
        GridBold = [System.Drawing.Font]::new('Consolas', 15, [System.Drawing.FontStyle]::Bold)
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
        [Parameter(Mandatory)][string]$Text,
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
        $button.Add_Click($OnClick)
    }
    $Parent.Controls.Add($button)
    return $button
}

function New-NMLabel {
    param(
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Parent,
        [Parameter(Mandatory)][string]$Text,
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
    $pen = [System.Drawing.Pen]::new($Color, 2.4)
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
                    $x1 = $cx + [int]([math]::Cos($angle) * 11)
                    $y1 = $cy + [int]([math]::Sin($angle) * 11)
                    $x2 = $cx + [int]([math]::Cos($angle) * 15)
                    $y2 = $cy + [int]([math]::Sin($angle) * 15)
                    $Graphics.DrawLine($pen, $x1, $y1, $x2, $y2)
                }
                $Graphics.DrawEllipse($pen, (Get-NMRectangle ($cx - 10) ($cy - 10) 20 20))
                $Graphics.DrawEllipse($pen, (Get-NMRectangle ($cx - 4) ($cy - 4) 8 8))
            }
            'Refresh' {
                $Graphics.DrawArc($pen, (Get-NMRectangle ($cx - 13) ($cy - 13) 26 26), 35, 275)
                $Graphics.DrawLine($pen, $cx + 11, $cy - 13, $cx + 15, $cy - 4)
                $Graphics.DrawLine($pen, $cx + 11, $cy - 13, $cx + 2, $cy - 12)
            }
            'Pin' {
                $Graphics.DrawLine($pen, $cx - 2, $cy - 15, $cx + 12, $cy - 1)
                $Graphics.DrawLine($pen, $cx - 12, $cy - 2, $cx + 2, $cy - 16)
                $Graphics.DrawLine($pen, $cx - 7, $cy + 3, $cx + 7, $cy - 11)
                $Graphics.DrawLine($pen, $cx - 1, $cy + 2, $cx + 12, $cy + 15)
                $Graphics.DrawLine($pen, $cx - 7, $cy + 7, $cx - 15, $cy + 15)
            }
            'Minimize' {
                $Graphics.DrawLine($pen, $cx - 13, $cy + 5, $cx + 13, $cy + 5)
            }
            'Maximize' {
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 10) ($cy - 10) 20 20))
            }
            'Restore' {
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 7) ($cy - 11) 17 17))
                $Graphics.DrawRectangle($pen, (Get-NMRectangle ($cx - 11) ($cy - 6) 17 17))
            }
            'Close' {
                $Graphics.DrawLine($pen, $cx - 11, $cy - 11, $cx + 11, $cy + 11)
                $Graphics.DrawLine($pen, $cx + 11, $cy - 11, $cx - 11, $cy + 11)
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
        [void]$eventArgs
        $sender.Tag.Pressed = $false
        $sender.Invalidate()
    })
    if ($OnClick) {
        $button.Add_Click($OnClick)
    }

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

        $paintEventArgs.Graphics.Clear($background)
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

    $Control.Add_MouseDoubleClick({
        param($sender, $eventArgs)
        [void]$sender
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Invoke-NMToggleMaximize
        }
    })

    $Control.Add_MouseDown({
        param($sender, $eventArgs)
        [void]$sender
        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            [NetworkMonitorNative]::ReleaseCapture() | Out-Null
            [NetworkMonitorNative]::SendMessage($Form.Handle, 0xA1, 0x2, 0) | Out-Null
        }
    })
}
