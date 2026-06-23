# WPF Verification And Acceptance Plan

Generated: 2026-06-23

## Purpose

This document defines the minimum verification for the WPF rewrite.

Parser checks are not enough. The current app's history shows that rendering, event capture, settings commits, ping completion, and window interactions need explicit verification.

## Automated Test Harness

Create:

`Scripts\Network_Monitor_WPF\Tests\Invoke-NetMonWpfChecks.ps1`

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor_WPF\Tests\Invoke-NetMonWpfChecks.ps1
```

The resolved runtime strategy prefers PowerShell 7 but falls back to Windows PowerShell if WPF assemblies cannot load under PowerShell 7. When validating the fallback path, also run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor_WPF\Tests\Invoke-NetMonWpfChecks.ps1
```

Exit code:

- `0` on pass.
- Nonzero on failure.

Output:

- Print clear `PASS <name>` and `FAIL <name>: <reason>` lines.

## Automated Checks

### 1. Parser Check

Parse every `.ps1` file under the WPF app root.

Fail if any parser error exists.

### 2. Assembly Load Check

Load WPF assemblies:

- `PresentationFramework`
- `PresentationCore`
- `WindowsBase`
- `System.Xaml` if required by implementation

Fail with a clear message if the selected host cannot load WPF.

Also verify the launcher/runtime probe behavior:

- It attempts `pwsh.exe` first.
- It probes WPF assembly loading.
- It falls back to `powershell.exe` when the PowerShell 7 probe fails.
- It reports a fatal startup error only if both hosts fail.

### 3. XAML Load Check

Load:

- `Views\MainWindow.xaml`
- `Views\SettingsWindow.xaml`

Fail if:

- XAML cannot parse.
- Root object is not a `Window`.
- Required named controls are missing.

Required main names:

- main window root
- title bar
- settings button
- refresh button
- pin button
- minimize button
- maximize button
- close button
- monitor grid

Required settings names:

- settings window root
- title bar
- close button
- settings tabs
- feedback text
- targets editor/list/grid
- columns visibility list
- columns order list
- timing inputs
- health inputs
- general controls

### 4. Module Load Check

Load modules in runtime order.

Runtime order:

1. `Logging.ps1`
2. `Validation.ps1`
3. `Config.ps1`
4. `MonitorState.ps1`
5. `Presentation.ps1`
6. `PingEngine.ps1`
7. `WpfTheme.ps1`
8. `WpfXaml.ps1`
9. `WpfWindowChrome.ps1`
10. `WpfBindings.ps1`
11. `SettingsWindow.ps1`
12. `MainWindow.ps1`

Fail if expected public functions are missing.

### 5. Config Check

Use a temporary app root.

Verify:

- Default config validates.
- Missing config auto-creates defaults.
- Invalid config is rejected as a whole.
- Invalid config is backed up as `NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json`.
- Defaults regenerate after invalid config rejection.
- Transactional edit failure does not replace live config.
- Atomic save leaves no partial real config.

### 6. Presentation Check

For each supported column, call the WPF presentation API.

Verify returned object has:

- text or display value
- foreground brush/hex/resource key
- template kind
- alignment or equivalent

Scenarios:

No sample:

- Status text `UP`
- Status color green
- RTT text `NA`
- Loss text `0.0%`
- TTL text `--`
- Bytes text `--`
- History template kind

One failed sample:

- Status text `UP`
- RTT text `timeout`
- Loss text `100.0%`
- Health is yellow or orange depending thresholds, but not down.
- Latest history sample failed/red.

Three failed samples:

- Status text `DOWN`
- Status color red
- RTT text `timeout`
- Loss text `100.0%`
- History failed/red.

One successful sample:

- Status text `UP`
- RTT text `<n> ms`
- Loss text `0.0%`
- TTL value if supplied
- Bytes value if supplied
- History success/green.

### 7. Main Window Construction Check

Build main WPF window under STA without starting the full application loop.

Verify:

- Window exists.
- Title is exact.
- DataGrid exists.
- Default row collection has 3 enabled targets.
- Default visible columns are Node, Address, Status, RTT, Loss, History.
- TTL and Bytes are present in config and hidden in grid.
- Title buttons exist.
- Window has custom/no standard title bar.

### 8. Settings Window Construction Check

Build settings window under STA without showing modally.

Verify:

- Settings window exists.
- Owner can be assigned to main window.
- It has five tabs.
- Tab names are exact and in order.
- Feedback label/text block exists.
- Close button exists.
- Targets controls exist.
- Columns controls exist.
- Timing controls exist.
- Health controls exist.
- General controls exist.

### 9. Row View Model Update Check

Simulate state changes and update row view models.

Verify:

- Existing row object remains the same for ordinary ping updates.
- Row fields update in place.
- Target add/delete/enable/reorder change rebuilds row collection.
- Target rename updates row identity/order and resets monitor state/history.
- Target address edit updates the displayed address and resets monitor state/history.
- Target color edit updates node foreground/color presentation and resets monitor state/history.
- If WPF updates target address/color row properties in place instead of rebuilding row objects, verify the existing row object remains valid and the visible presentation updates immediately.
- History display list length equals `HistoryLength`.
- Missing history samples render as yellow.

### 10. Column Persistence Check

Simulate:

- Column width change.
- Column order change.
- Column visibility change.

Verify:

- Config updates transactionally.
- Column layout persists.
- Invalid width is rejected.
- Hiding final visible column is blocked.
- Main grid rebuilds/applies columns.

### 11. Selection Color Check

Programmatically select first row/cell in DataGrid.

Verify:

- RTT foreground remains presentation foreground.
- Loss foreground remains presentation foreground.
- Status foreground remains presentation foreground.
- No selected/current cell turns health text white unless presentation foreground is white.

### 12. Ping State Check

Call state update directly with synthetic results.

Cases:

- one failed result for every target
- three failed results for every target
- one successful result for first target and failures for others
- empty result set

Verify:

- History counts increment once per attempted result.
- Empty result set does not mutate state.
- Down threshold works.
- Rolling loss works.
- Success resets consecutive failures.

### 13. Ping Engine Check

Configure temporary targets:

- `Loopback` -> `127.0.0.1`
- `NoRoute` -> `203.0.113.1`

Use short timeout, for example `100 ms`.

Verify:

- Ping cycle completes.
- Each target produces one sample.
- Loopback is successful where available.
- NoRoute records failure.
- No runspace/dispatcher exceptions occur.
- UI dispatcher remains responsive.

### 14. Event Capture Audit

Search WPF app scripts for event registration patterns:

- `.Add_`
- `add_`
- `Register-ObjectEvent`
- task continuations

Verify:

- Helper-local variables are explicitly captured with `.GetNewClosure()` or stored in stable state.
- Worker/task callbacks do not call UI/state functions directly off dispatcher.
- Main and settings title bar handlers target the correct window.
- Settings close closes settings only.

## Manual Launch Checks

Run direct:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor_WPF\Network_Monitor_WPF.ps1
```

Run CMD shim:

```powershell
Scripts\Network_Monitor_WPF\Run_Network_Monitor_WPF.cmd
```

Run VBS shim:

```powershell
wscript.exe Scripts\Network_Monitor_WPF\Run_Network_Monitor_WPF.vbs
```

Verify:

- App appears.
- App appears in taskbar.
- No console remains visible from shim launch.
- Title is exact.
- Monitoring auto-starts if configured.
- Closing main exits completely.

## Manual Main Window Checks

Verify:

- Window opens bottom-left on first run.
- Window does not cover taskbar.
- Window has no visible gap from taskbar working-area boundary.
- Window is resizable.
- Dragging title bar moves main window.
- Double-click title bar maximizes/restores.
- Minimize works.
- Maximize/restore works and icon changes.
- Close exits completely.
- Pin toggles topmost and active blue icon.
- Pin persists across relaunch.
- Settings cog opens settings and becomes active blue.
- Reset clears samples/history and starts fresh cycle.

## Manual Grid Checks

Default grid:

- Columns: Node, Address, Status, RTT, Loss, History.
- Rows: SMS, MPS, MPG.
- Node colors:
  - SMS magenta.
  - MPS magenta.
  - MPG cyan.
- Address text exactly as configured.
- Status uses dot plus text.
- RTT and Loss use health colors.
- History uses 12 bars.
- TTL and Bytes hidden by default.

Interactions:

- Column resize persists.
- Column reorder persists.
- Horizontal scroll appears if needed.
- Row selection does not alter health colors.
- No sorting is available.

## Manual Monitoring Checks

With a controlled unreachable test target/config, for example `203.0.113.1` with a short timeout, after at least 3 attempted cycles:

- Status `DOWN`.
- Status dot/text red.
- RTT `timeout`.
- RTT red.
- Loss `100.0%`.
- Loss red.
- History bars red.

If the configured default targets are currently unreachable, the same visual failure checks may also be observed against those rows. Do not require default targets to be unreachable on every network.

With reachable test target:

- Status `UP`.
- RTT `<n> ms`.
- Loss `0.0%`.
- History bars green after successes.
- TTL/Bytes display values if columns are visible.

Busy cycle behavior:

- Use a timeout/refresh combination likely to overlap.
- Confirm skipped ticks do not add history samples.
- Confirm UI remains responsive.

## Manual Settings Checks

Settings window:

- Opens non-modally.
- Repeated cog click focuses existing settings.
- Only one settings instance exists.
- Settings stays above main.
- Settings topmost mirrors pinned main.
- Monitoring continues while open.
- Close button closes settings only.
- Settings cog active state clears when settings closes.

Targets tab:

- Add target.
- Edit target name.
- Edit target address.
- Edit target color.
- Color preview updates.
- Delete target.
- Move target up/down.
- Enable/disable target.
- Duplicate target names are rejected.
- Invalid address is rejected.
- Invalid color is rejected.
- Disabling/deleting last enabled target is blocked.

Columns tab:

- Hide/show each column.
- Hiding the last visible column is blocked.
- Move columns up/down.
- Change selected width.
- Invalid width is rejected.

Timing tab:

- Refresh interval commits on Enter.
- Refresh interval commits on focus leave.
- Invalid partial input does not mutate config.
- Ping timeout commits correctly.
- History length commits correctly.
- Auto-start checkbox persists.

Health tab:

- All labels visible and aligned.
- Down/Orange failure thresholds commit correctly.
- RTT thresholds commit correctly.
- Invalid RTT ordering is rejected.
- Loss thresholds commit correctly.
- Invalid loss ordering is rejected.

General tab:

- Always on top toggles and persists.
- Debug logging toggles and persists.
- Reset window position moves main bottom-left and persists.
- Reset to Defaults prompts for confirmation.
- Reset to Defaults restores default config and closes settings.

## Manual Config Checks

First run:

- Delete/move config.
- Launch app.
- Confirm default config created.

Invalid config:

- Write malformed or incomplete JSON.
- Launch app.
- Confirm invalid config backup file created.
- Confirm defaults regenerate.

Persistence:

- Move/resize window, close, relaunch.
- Confirm bounds restored.
- Move saved config to off-screen coordinates, launch.
- Confirm bottom-left fallback.

Debug logging:

- With debug off, normal operation creates no routine logs.
- With debug on, diagnostic log can be written.
- Fatal startup error writes startup error log.

## Visual Acceptance

Compare against `Network_Monitor_Winform_UI.png`.

Accept if:

- Dark palette is recognizably the same.
- Title text and button order match.
- Main content is grid-only.
- Default six columns and three default rows match.
- Row/header heights are close.
- Status dot/history bars match intent and color.
- Text does not clip at default size.
- Settings window uses the same dark language.
- WPF-native text and grid rendering differences are acceptable when layout, palette, typography, column widths, and visual hierarchy remain close.

Check at:

- 100 percent Windows scaling.
- 125 percent Windows scaling if available.
- Restored compact window.
- Maximized window.

## Final Completion Gate

Do not report rewrite complete unless:

- Automated WPF harness passes.
- Visible app launched through the selected production shim.
- Main title-bar drag tested.
- Settings title-bar drag tested.
- Selected grid cell health colors tested.
- Unreachable ping behavior tested.
- Reachable ping behavior tested.
- Settings commit and invalid rollback tested.
- Config invalid-backup behavior tested.
- Any skipped checks are listed with reason.
