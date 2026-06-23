$script:NMWindowTitle = 'Network Monitor - Troubleshooter Test Tools'

function Test-NMRectangleVisible {
    param(
        [Parameter(Mandatory)][double]$X,
        [Parameter(Mandatory)][double]$Y,
        [Parameter(Mandatory)][double]$Width,
        [Parameter(Mandatory)][double]$Height
    )

    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $rect = [System.Drawing.Rectangle]::new([int]$X, [int]$Y, [int]$Width, [int]$Height)
    foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        if ($screen.WorkingArea.IntersectsWith($rect)) {
            return $true
        }
    }

    return $false
}

function Get-NMCalculatedDefaultWindowSize {
    $visibleWidth = 0
    foreach ($column in @($script:NMConfig.Columns)) {
        if ($column.Visible) {
            $visibleWidth += [int]$column.Width
        }
    }

    $enabledCount = [math]::Max(1, @(Get-NMEnabledTargets).Count)
    $width = [math]::Max(820, $visibleWidth + 28)
    $height = [math]::Max(
        260,
        $script:NMTitleBarHeight + $script:NMGridHeaderHeight + ($enabledCount * $script:NMGridRowHeight) + 18
    )

    return [pscustomobject]@{
        Width = [int]$width
        Height = [int]$height
    }
}

function Set-NMDefaultWindowLocation {
    if (-not $script:NMMainWindow) {
        return
    }

    $workingArea = [System.Windows.SystemParameters]::WorkArea
    $script:NMMainWindow.WindowState = [System.Windows.WindowState]::Normal
    $script:NMMainWindow.Left = [double]$workingArea.Left
    $script:NMMainWindow.Top = [double]($workingArea.Bottom - $script:NMMainWindow.Height)
}

function Apply-NMInitialWindowPlacement {
    if (-not $script:NMMainWindow) {
        return
    }

    $defaultSize = Get-NMCalculatedDefaultWindowSize
    $width = [math]::Max([int]$script:NMConfig.Window.Width, [int]$defaultSize.Width)
    $height = [math]::Max([int]$script:NMConfig.Window.Height, [int]$defaultSize.Height)
    $script:NMMainWindow.Width = [double]$width
    $script:NMMainWindow.Height = [double]$height

    $hasPosition = ($null -ne $script:NMConfig.Window.X -and $null -ne $script:NMConfig.Window.Y)
    if ($hasPosition -and (Test-NMRectangleVisible -X ([double]$script:NMConfig.Window.X) -Y ([double]$script:NMConfig.Window.Y) -Width $width -Height $height)) {
        $script:NMMainWindow.Left = [double][int]$script:NMConfig.Window.X
        $script:NMMainWindow.Top = [double][int]$script:NMConfig.Window.Y
    }
    else {
        Set-NMDefaultWindowLocation
    }

    if ($script:NMConfig.Window.Maximized) {
        $script:NMMainWindow.WindowState = [System.Windows.WindowState]::Maximized
    }
}

function Update-NMMainWindowMinimumSize {
    if (-not $script:NMMainWindow) {
        return
    }

    $minimumColumnWidth = Get-NMVisibleMonitorColumnMinimumWidth
    $enabledCount = [math]::Max(1, @(Get-NMEnabledTargets).Count)

    $script:NMMainWindow.MinWidth = [math]::Max(820.0, ($minimumColumnWidth + 2.0))
    $script:NMMainWindow.MinHeight = [double]($script:NMTitleBarHeight + $script:NMGridHeaderHeight + ($enabledCount * $script:NMGridRowHeight) + 2)
}

function Save-NMWindowPlacement {
    if (-not $script:NMMainWindow) {
        return
    }

    $script:NMConfig.Window.Maximized = ($script:NMMainWindow.WindowState -eq [System.Windows.WindowState]::Maximized)
    $bounds = if ($script:NMMainWindow.WindowState -eq [System.Windows.WindowState]::Normal) {
        [System.Windows.Rect]::new($script:NMMainWindow.Left, $script:NMMainWindow.Top, $script:NMMainWindow.Width, $script:NMMainWindow.Height)
    }
    else {
        $script:NMMainWindow.RestoreBounds
    }

    if ($bounds.Width -ge $script:NMMainWindow.MinWidth -and $bounds.Height -ge $script:NMMainWindow.MinHeight) {
        $script:NMConfig.Window.Width = [int][math]::Round($bounds.Width)
        $script:NMConfig.Window.Height = [int][math]::Round($bounds.Height)
        $script:NMConfig.Window.X = [int][math]::Round($bounds.X)
        $script:NMConfig.Window.Y = [int][math]::Round($bounds.Y)
    }
}

function Set-NMSettingsFeedback {
    param(
        [Parameter(Mandatory)][string]$Message,
        [switch]$Error
    )

    if (-not $script:NMSettingsFeedbackText) {
        return
    }

    $script:NMSettingsFeedbackText.Text = $Message
    $script:NMSettingsFeedbackText.Foreground = if ($Error) { Get-NMThemeBrush -Name 'Red' } else { Get-NMThemeBrush -Name 'Muted' }
    $script:NMSettingsFeedbackText.Visibility = [System.Windows.Visibility]::Visible
}

function Show-NMConfigError {
    param([Parameter(Mandatory)][string]$Message)

    if ($script:NMMainWindow -and -not $script:NMSuppressMessageBoxes) {
        [System.Windows.MessageBox]::Show(
            $script:NMMainWindow,
            $Message,
            'Settings Rejected',
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }

    Set-NMSettingsFeedback -Message $Message -Error
}

function Apply-NMAlwaysOnTopState {
    if ($script:NMMainWindow) {
        $script:NMMainWindow.Topmost = [bool]$script:NMConfig.AlwaysOnTop
    }
    if ($script:NMSettingsWindow) {
        $script:NMSettingsWindow.Topmost = [bool]$script:NMConfig.AlwaysOnTop
    }
    if ($script:NMPinButton) {
        Set-NMTitleButtonActive -Button $script:NMPinButton -Active ([bool]$script:NMConfig.AlwaysOnTop)
    }
    if ($script:NMAlwaysOnTopCheckBox) {
        $script:NMSettingsSuppress = $true
        try { $script:NMAlwaysOnTopCheckBox.IsChecked = [bool]$script:NMConfig.AlwaysOnTop }
        finally { $script:NMSettingsSuppress = $false }
    }
}

function Invoke-NMMinimize {
    if ($script:NMMainWindow) {
        $script:NMMainWindow.WindowState = [System.Windows.WindowState]::Minimized
    }
}

function Invoke-NMToggleMaximize {
    if ($script:NMMainWindow) {
        Invoke-NMWpfMaximizeToggle -Window $script:NMMainWindow
    }
}

function Invoke-NMTogglePin {
    if (Invoke-NMConfigEditAndApply -Edit {
        param($config)
        $config.AlwaysOnTop = -not [bool]$config.AlwaysOnTop
    } -Reason 'Always-on-top changed') {
        Apply-NMAlwaysOnTopState
    }
}

function Invoke-NMResetAndRefresh {
    $script:NMGeneration++
    Reset-NMMonitorState
    Update-NMMonitorRowsFromState
    Start-NMMonitoring
    Invoke-NMPingCycle
}

function Apply-NMRuntimeConfigEffects {
    param(
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        Write-NMDebugLog -Message $Reason
    }

    if ($ResetMonitor) {
        $script:NMGeneration++
        Reset-NMMonitorState
    }

    Update-NMPingTimerInterval
    Apply-NMAlwaysOnTopState

    if ($RebuildGrid) {
        Apply-NMColumnsToGrid
    }
    else {
        Update-NMMonitorRowsFromState
    }

    Update-NMMainWindowMinimumSize
    Update-NMMonitorGridViewportWidth

    if ($ResetMonitor -and (Test-NMMonitoringEnabled)) {
        Invoke-NMPingCycle
    }
}

function Invoke-NMConfigChanged {
    param(
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

    try {
        Save-NMCurrentConfig
    }
    catch {
        Show-NMConfigError -Message $_.Exception.Message
        return $false
    }

    Apply-NMRuntimeConfigEffects -ResetMonitor:$ResetMonitor -RebuildGrid:$RebuildGrid -Reason $Reason
    return $true
}

function Invoke-NMConfigEditAndApply {
    param(
        [Parameter(Mandatory)][scriptblock]$Edit,
        [switch]$ResetMonitor,
        [switch]$RebuildGrid,
        [AllowEmptyString()][string]$Reason = ''
    )

    try {
        [void](Invoke-NMConfigEdit -Edit $Edit)
    }
    catch {
        Show-NMConfigError -Message $_.Exception.Message
        return $false
    }

    Apply-NMRuntimeConfigEffects -ResetMonitor:$ResetMonitor -RebuildGrid:$RebuildGrid -Reason $Reason
    return $true
}

function Invoke-NMOnPingResults {
    param([AllowNull()]$Results)

    Update-NMStateFromPingResults -Results $Results
    Update-NMMonitorRowsFromState
}

function Register-NMWpfExceptionHandlers {
    param([Parameter(Mandatory)][System.Windows.Application]$Application)

    if ($script:NMRuntimeExceptionHandlersRegistered) {
        return
    }

    $script:NMRuntimeExceptionHandlersRegistered = $true

    $Application.add_DispatcherUnhandledException({
        param($sender, $eventArgs)
        [void]$sender
        $details = $eventArgs.Exception.ToString()
        $message = "WPF dispatcher exception: $($eventArgs.Exception.Message)"
        Write-NMDebugLog -Message $message
        Write-NMStartupErrorLog -Message ("{0}`n{1}" -f $message, $details)
        [System.Windows.MessageBox]::Show($message, 'Network Monitor Error', [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) | Out-Null
        $eventArgs.Handled = $true
    })

    [System.AppDomain]::CurrentDomain.add_UnhandledException({
        param($sender, $eventArgs)
        [void]$sender
        $exception = $eventArgs.ExceptionObject
        $message = if ($exception -is [System.Exception]) { $exception.Message } else { [string]$exception }
        Write-NMStartupErrorLog -Message ("Unhandled exception: {0}" -f $message)
    })
}

function Initialize-NetworkMonitorWpfCore {
    param([Parameter(Mandatory)][string]$AppRoot)

    Initialize-NMWpfTheme
    $script:NMAppRoot = $AppRoot
    $script:NMConfig = Initialize-NMConfig -AppRoot $AppRoot
    $script:NMGeneration = 1
    Initialize-NMMonitorState
    Initialize-NMPingEngine
}

function Build-NMMainWindow {
    param([Parameter(Mandatory)][string]$AppRoot)

    $xamlPath = Join-Path $AppRoot 'Views\MainWindow.xaml'
    $loaded = Import-NMWindowXaml -Path $xamlPath -RequiredNames @(
        'MainWindowRoot',
        'TitleBar',
        'TitleText',
        'SettingsButton',
        'RefreshButton',
        'PinButton',
        'MinimizeButton',
        'MaximizeButton',
        'CloseButton',
        'MonitorGrid'
    )

    $window = $loaded.Window
    $controls = $loaded.Controls
    $script:NMMainWindow = $window
    $script:NMMainControls = $controls
    $script:NMPinButton = $controls.PinButton
    $script:NMSettingsButton = $controls.SettingsButton
    $script:NMMaximizeButton = $controls.MaximizeButton
    $script:NMCloseButton = $controls.CloseButton

    Set-NMWpfWindowChrome -Window $window
    Register-NMWpfTitleDrag -TitleBar $controls.TitleBar -Window $window -CanMaximize
    Register-NMWpfTitleDrag -TitleBar $controls.TitleText -Window $window -CanMaximize

    Update-NMMainWindowMinimumSize
    Apply-NMInitialWindowPlacement
    Apply-NMAlwaysOnTopState
    Set-NMIconButtonKind -Button $script:NMMaximizeButton -Kind 'Maximize'

    Initialize-NMMonitorGridBinding -Grid $controls.MonitorGrid
    Register-NMGridColumnPersistence -Grid $controls.MonitorGrid
    Update-NMMainWindowMinimumSize

    $controls.SettingsButton.Add_Click({ Show-NMSettingsWindow })
    $controls.RefreshButton.Add_Click({ Invoke-NMResetAndRefresh })
    $controls.PinButton.Add_Click({ Invoke-NMTogglePin })
    $controls.MinimizeButton.Add_Click({ Invoke-NMMinimize })
    $controls.MaximizeButton.Add_Click({ Invoke-NMToggleMaximize })
    $controls.CloseButton.Add_Click({ $script:NMMainWindow.Close() })

    $window.Add_Loaded({
        if ($script:NMConfig.AutoStart) {
            Start-NMMonitoring
            Invoke-NMPingCycle
        }
    })

    $window.Add_StateChanged({
        if ($script:NMMaximizeButton) {
            $kind = if ($script:NMMainWindow.WindowState -eq [System.Windows.WindowState]::Maximized) { 'Restore' } else { 'Maximize' }
            Set-NMIconButtonKind -Button $script:NMMaximizeButton -Kind $kind
        }
    })

    $window.Add_SizeChanged({
        Update-NMMonitorGridViewportWidth
    })

    $window.Add_Closing({
        Stop-NMMonitoring
        Save-NMGridColumnLayoutIfDirty
        Save-NMWindowPlacement
        try {
            Save-NMCurrentConfig
        }
        catch {
            Write-NMDebugLog -Message ("Unable to save config on close: {0}" -f $_.Exception.Message)
        }
    })

    return $window
}

function Start-NetworkMonitorApp {
    param([Parameter(Mandatory)][string]$AppRoot)

    $app = [System.Windows.Application]::Current
    if (-not $app) {
        $app = [System.Windows.Application]::new()
    }

    Initialize-NetworkMonitorWpfCore -AppRoot $AppRoot
    Register-NMWpfExceptionHandlers -Application $app

    $window = Build-NMMainWindow -AppRoot $AppRoot
    [void]$app.Run($window)
}
