# Network Monitor Verification Checklist

Generated: 2026-06-23

## Purpose

This checklist defines the minimum verification required after the Network Monitor remediation pass. Parser checks are necessary, but they are not enough. The previous implementation failures were mostly interaction, event, rendering, and ping-state failures.

## Required Test Harness

Create this script:

`Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`

It must run without internet, external modules, administrator rights, or package downloads.

Run it with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1
```

The script should exit with:

- `0` on pass
- nonzero on failure

It should print clear pass/fail messages.

## Nonvisual Automated Checks

### 1. Parser Check

Parse every `.ps1` file under:

`Scripts\Network_Monitor`

Fail if any parser errors are found.

### 2. Module Load Check

Dot-source the modules in runtime order:

1. `Logging.ps1`
2. `Validation.ps1`
3. `Config.ps1`
4. `MonitorState.ps1`
5. `PingEngine.ps1`
6. `UiHelpers.ps1`
7. `Presentation.ps1`
8. `SettingsForm.ps1`
9. `MainForm.ps1`

Fail if any module cannot load.

### 3. Config Check

Verify:

- default config validates
- invalid config is rejected as a whole
- invalid config is backed up as `NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json`
- defaults regenerate after invalid config rejection
- transactional edit does not replace live config on failed validation

Use a temporary app root for destructive config tests.

### 4. Form Construction Check

Build the main form under STA without running the full app loop.

Verify:

- main form exists
- grid exists
- default grid has 3 rows
- configured columns exist
- title bar exists

Build the settings form.

Verify:

- settings form exists
- settings form handle differs from main form handle
- settings has 5 tabs
- Health tab exists
- settings close button exists

### 5. Presentation Check

For each supported column, call:

```powershell
Get-NMColumnPresentation
```

Verify the returned object has:

- `Text`
- `ForeColor`
- `Font`
- `PaintKind`

Required scenarios:

#### No Sample

Expected:

- `Status`: `UP`, green
- `RTT`: `NA`, red or configured no-RTT health color
- `Loss`: `0.0%`, green
- `TTL`: `--`, muted
- `Bytes`: `--`, muted
- `History`: `PaintKind = History`

#### One Failed Sample

Expected:

- `Status`: `UP`
- `RTT`: `timeout`, red
- `Loss`: `100.0%`, red
- `History`: one failed sample

#### Three Failed Samples

Expected:

- `Status`: `DOWN`
- health color red
- `RTT`: `timeout`, red
- `Loss`: `100.0%`, red

#### One Successful Sample

Expected:

- `Status`: `UP`
- `RTT`: `<n> ms`, threshold color
- `Loss`: `0.0%`, green
- `TTL`: value if supplied
- `Bytes`: value if supplied

### 6. Grid Selection Color Check

Programmatically select the first row/cell.

Verify:

- selected RTT cell uses the same presentation color as unselected RTT cells
- selected Loss cell uses the same presentation color as unselected Loss cells
- no selected/current cell turns health text white unless white is the presentation color

### 7. Ping-State Check

Simulate results directly against `Update-NMStateFromPingResults`.

Cases:

- one failed result for each target
- three failed results for each target
- one successful result for one target and failed results for others

Verify:

- history counts increment once per attempted result
- skipped cycles do not mutate state
- `DOWN` threshold works
- rolling loss works

### 8. Ping Engine Check

Run the ping engine with a short timeout against the default unreachable addresses or known test addresses.

Verify:

- attempted timeouts produce failed samples
- no PowerShell runspace callback exceptions occur
- UI thread remains responsive enough for timer callbacks

### 9. Event Capture Audit

Search all app scripts for `.Add_`.

For every event registration, verify:

- no helper-local variable is referenced without `.GetNewClosure()`
- no callback parameter is referenced without `.GetNewClosure()`
- no target form/control parameter is referenced without `.GetNewClosure()` or `Tag`

This audit may be partly manual, but it must be performed.

## Manual Visible App Checks

Run the app through the VBS shim:

```powershell
wscript.exe Scripts\Network_Monitor\Run_Network_Monitor.vbs
```

### Main Window

Verify:

- app appears in taskbar
- no console remains visible
- title is `Network Monitor - Troubleshooter Test Tools`
- window is compact and dark
- grid is the only main content area
- title bar drag moves main window
- double-click title bar maximizes/restores if supported
- minimize works
- maximize/restore works
- close exits app
- pin toggles active blue state and topmost behavior
- reset/refresh clears samples and starts fresh

### Monitoring Display

With the default unreachable targets shown in the user screenshots, verify after at least 3 cycles:

- all unreachable targets show `DOWN`
- all unreachable targets show `timeout`
- all unreachable targets show `100.0%`
- all RTT text is red
- all Loss text is red
- history ticks are red
- no row has mismatched white RTT/Loss text due to selection

With a reachable test target, verify:

- status remains `UP`
- RTT shows `<n> ms`
- loss shows `0.0%`
- history ticks are green

### Settings Window

Verify:

- settings cog opens settings
- clicking cog again focuses existing settings window
- settings window stays above monitor
- settings title bar drag moves settings only
- main monitor does not move when dragging settings
- settings close button closes settings only
- settings does not appear as a broken native light-themed window
- tabs are readable
- Health tab labels and inputs are visible and aligned

### Settings Commit Behavior

Verify:

- numeric timing/threshold edits do not commit on every keystroke
- numeric edits commit on Enter
- numeric edits commit on focus leave
- invalid numeric edits restore previous valid value
- target edit rejects duplicate names
- target edit rejects invalid address
- color edit rejects invalid hex color
- disabling/deleting last enabled target is blocked
- reset to defaults asks for confirmation

### Config Behavior

Verify:

- first run creates config
- invalid config is backed up and defaults regenerate
- window position persists
- off-screen window position falls back to bottom-left
- always-on-top persists
- debug mode persists

## Final Completion Gate

The remediation is not complete unless all of these are true:

- test harness passes
- visible app was launched
- main drag and settings drag were manually tested
- selected-row/selected-cell health colors were manually tested
- unreachable ping behavior was manually tested
- settings Health tab was manually inspected
- final response lists any failed or skipped checks

Do not report completion if only parser checks passed.
