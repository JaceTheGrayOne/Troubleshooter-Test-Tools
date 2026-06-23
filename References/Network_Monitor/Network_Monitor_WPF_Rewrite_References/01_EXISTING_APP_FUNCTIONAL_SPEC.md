# Existing App Functional Spec

Generated: 2026-06-23

## Scope

This document describes the current Network Monitor app's complete functional behavior as the WPF rewrite target.

The current app is implemented under:

`Scripts\Network_Monitor`

This spec is based on:

- Current source modules under `Scripts\Network_Monitor`.
- Current config at `Scripts\Network_Monitor\config\NetworkMonitor.config.json`.
- Current UI screenshot `Network_Monitor_Winform_UI.png`.
- Prior requirements Q&A and remediation contracts.
- Passing current test harness `Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`.

## App Model

The Network Monitor is a standalone Windows desktop utility launched separately from the main Troubleshooter Test Tools launcher.

It must:

- Start independently.
- Continue running if the main launcher closes.
- Stop monitoring and exit completely when the Network Monitor main window closes.
- Not minimize to tray.
- Not require admin rights.
- Not require internet connectivity.
- Only perform ICMP ping operations against configured targets.

## Launch Behavior

Current launch files:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Run_Network_Monitor.cmd`
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`

Current behavior:

- `Run_Network_Monitor.cmd` changes directory to its folder and starts the VBS shim.
- `Run_Network_Monitor.vbs` finds `pwsh.exe` first, falls back to `powershell.exe`, then launches hidden with:
  - `-NoProfile`
  - `-ExecutionPolicy Bypass`
  - `-STA`
  - `-File "<appRoot>\Network_Monitor.ps1"`
- `Network_Monitor.ps1` detects its app root from `$PSScriptRoot`, `$PSCommandPath`, or current location.
- If not running in STA, it relaunches hidden under preferred PowerShell and exits the original process.
- Runtime preference is `pwsh.exe`, then `powershell.exe`.
- Fatal startup errors are written to `logs\NetworkMonitor.startup-error.log` and shown in a message box when possible.

WPF rewrite requirement:

- Use the same launch model under `Scripts\Network_Monitor_WPF` with WPF-specific script/shim names.
- Keep the hidden no-console startup path.
- Keep STA enforcement.
- Prefer `pwsh.exe`, probe WPF assembly availability, and fall back to `powershell.exe` if WPF cannot load under PowerShell 7.

## Main Window Behavior

Window title:

`Network Monitor - Troubleshooter Test Tools`

The exact title is used for:

- Title bar text.
- Window text.
- Taskbar title.

The main window:

- Appears in the Windows taskbar.
- Uses a borderless/custom dark title bar.
- Is resizable.
- Supports title-bar drag.
- Supports title-bar double-click maximize/restore.
- Has minimize, maximize/restore, and close buttons.
- Has settings, reset/refresh, and pin buttons in the title bar.
- Opens bottom-left of the primary monitor working area on first run.
- Sits flush against the left working-area edge.
- Sits flush against the taskbar boundary without covering the taskbar.
- Restores saved window size and position on later launches.
- Falls back to bottom-left placement if saved position is invalid/off-screen.
- Persists maximized state.
- Persists always-on-top state.

Current minimum size:

- Main form minimum: `820 x 260`
- Config validation allows minimum window: `760 x 220`

Current default config size:

- Default generated config: `1040 x 270`, `X = null`, `Y = null`
- Current working config in this repo: `1120 x 330`, `X = 539`, `Y = 48`

WPF rewrite requirement:

- Use WPF device-independent units to approximate the same 96 DPI visual dimensions.
- Compute first-run size from visible column widths and enabled target count, with `1040 x 270` as the generated config baseline and `820 x 260` as the practical minimum.
- Keep the current default first-run placement algorithm.
- Persist and restore normal/restored bounds and maximized state.

## Title Bar Commands

Title bar button order, left to right in the button cluster:

1. Settings
2. Reset/refresh
3. Pin
4. Separator
5. Minimize
6. Maximize/restore
7. Close

Settings button:

- Opens the settings window.
- Allows only one settings window at a time.
- If settings is already open, focuses/activates that window.
- Shows active accent color while settings is open.
- Returns to neutral when settings closes.

Reset/refresh button:

- Increments the monitor generation.
- Clears all current target states, ping history, latest RTT/TTL/bytes values, consecutive failure counters, and loss values.
- Updates the grid immediately.
- Starts or continues monitoring.
- Starts a fresh ping cycle if possible.
- Does not reset persisted settings.
- Does not close/reopen the window.

Pin button:

- Toggles `AlwaysOnTop`.
- Applies topmost immediately.
- Persists to config.
- Shows neutral/no accent when unpinned.
- Shows Windows/PowerShell-style light blue active color when pinned.

Minimize button:

- Minimizes the main window.

Maximize/restore button:

- Toggles maximized/restored state.
- Icon changes between maximize and restore visual states.

Close button:

- Stops monitoring.
- Saves column layout if dirty.
- Saves window placement.
- Saves current config.
- Exits completely.

## Main Content

The main content area is the monitor grid only.

There must be no:

- Top summary strip.
- Bottom control bar.
- Footer.
- Warning banner.
- Start/pause controls.
- App icon in the title bar.

## Grid Behavior

Default visible columns:

1. `Node`
2. `Address`
3. `Status`
4. `RTT`
5. `Loss`
6. `History`

Supported optional hidden-by-default columns:

7. `TTL`
8. `Bytes`

Unsupported/not included columns:

- `Last Seen`
- `Last Success`
- `Avg RTT`
- `Min RTT`
- `Max RTT`
- Cumulative loss

Grid rules:

- Rows display enabled targets only.
- Disabled targets are hidden entirely.
- Rows are always in configured target order.
- Sorting is not supported.
- Column reordering is supported and persisted.
- Column resizing is supported and persisted.
- Column visibility is configurable and persisted.
- At least one column must remain visible.
- Columns have practical minimum widths.
- Horizontal and vertical scrolling are allowed when content exceeds the available window.
- Grid is read-only in the main window.
- Selection must not change health/status text colors.

Current WinForms implementation details to preserve conceptually:

- Rows are persistent and updated in place after ping cycles.
- Rows are rebuilt only when target/order/enabled or column config changes.
- Ordinary text rendering uses native grid rendering.
- Status and history are special visual templates:
  - Status: colored dot plus text.
  - History: colored sample bars.

WPF rewrite requirement:

- Use a WPF `DataGrid` for the main monitor because column resize, reorder, visibility, headers, scrolling, and persisted widths are required.
- Use templates for Status and History instead of custom GDI painting.
- Keep presentation logic centralized so text/color rules are consistent across normal and selected states.

## Default Targets

The default targets are:

| Name | Address | Color | Enabled |
|---|---|---|---|
| `SMS` | `192.168.51.20` | `#ff40e6` | `true` |
| `MPS` | `192.168.101.20` | `#ff40e6` | `true` |
| `MPG` | `192.168.200.100` | `#27d9e6` | `true` |

Target color rules:

- Target color is used for node identity/accent.
- Health colors control status dot, status text, RTT, loss, and history ticks.

Address rules:

- IPv4 addresses and hostnames are accepted.
- The `Address` column displays exactly the configured address string.
- Hostnames are not resolved into a separate IP display column.

## Monitoring Behavior

Monitoring:

- Auto-starts when the main window is shown if `AutoStart = true`.
- Has no visible start/pause controls in the main window.
- Uses `.NET System.Net.NetworkInformation.Ping.SendPingAsync()`.
- Sends one ping per enabled target per refresh cycle.
- Starts pings for all enabled targets in a cycle concurrently.
- Does ping work off the UI thread.
- Applies state/UI updates on the UI thread.
- Uses default refresh interval `1000 ms`.
- Uses default ping timeout `1000 ms`.
- Allows refresh interval and timeout to be changed in settings.

Overlapping cycle behavior:

- If a refresh tick occurs while a prior cycle is busy, skip the tick.
- Do not queue a later cycle.
- Do not add history samples for skipped ticks.
- Do not alter loss, counters, health, or timestamps for skipped ticks.
- Do not show skipped tick indicators.

Attempted ping behavior:

- Every attempted ping produces exactly one result sample.
- Success produces a successful sample.
- Timeout, DNS/start error, exception, or non-success reply status produces a failed sample.
- Failed attempted pings are recorded immediately as red history samples.
- Ping objects are disposed after use.

Generation behavior:

- Config changes or reset can increment a generation counter.
- Results from an old generation are discarded.
- If old results complete after a reset while monitoring is enabled, a fresh cycle may be started.

## State Model

Each target has runtime state:

- `HasSample`
- `LatestSuccess`
- `LatestRttMs`
- `LatestBytes`
- `LatestTtl`
- `ConsecutiveFailures`
- `LossPercent`
- `History`

`History` stores boolean success/failure samples:

- `true` = successful ping
- `false` = failed attempted ping
- Missing/not-yet-filled samples are rendered as `null` in the visual history template.

History length:

- Default: `12`
- Configurable range: `4` to `60`
- Rolling window only; oldest samples are removed when over length.

Loss:

- Rolling loss over current history sample count, not cumulative loss since launch.
- Formatted with one decimal place, for example `100.0%`.

## Status And Health

Status text:

- `UP` unless the configured down condition is met.
- `DOWN` only when consecutive failures meet or exceed `Health.DownFailures`.
- Degraded/yellow/orange health does not change text to `WARN` or `DEGRADED`.

Default health thresholds:

- Red/down: `ConsecutiveFailures >= 3`
- Orange: `LossPercent >= 25` or `ConsecutiveFailures >= 2`
- Yellow: latest attempted ping failed or rolling loss is greater than `0`
- Green: otherwise

Health precedence:

1. Red/down.
2. Orange degraded.
3. Yellow dropped/lossy.
4. Green healthy.

RTT text:

- Before any sample: `NA`
- Latest attempted ping failed: `timeout`
- Latest success: `<n> ms`, for example `3 ms`

RTT color defaults:

- Green: `<= 50 ms`
- Yellow: `> 50 ms` through `100 ms`
- Orange: `> 100 ms` through `250 ms`
- Red: `> 250 ms`, timeout, failure, or no latest RTT

Loss text and color defaults:

- Text: one decimal percentage, for example `0.0%`
- Green: `0%`
- Yellow: `> 0%` through `10%`
- Orange: `> 10%` through `25%`
- Red: `> 25%`

History colors:

- Green: successful ping sample.
- Red: failed attempted ping sample.
- Yellow: no sample yet/not enough data.

TTL and Bytes:

- Use values from successful ping replies only.
- Hidden by default.
- On failed/no sample: display `--` in muted color.

## Settings Window Behavior

The settings window:

- Opens from the title-bar settings cog.
- Is non-modal.
- Only one settings window may exist at a time.
- Repeated settings button click focuses the existing settings window.
- Is owned by the main monitor window.
- Does not show separately in taskbar in the current WinForms implementation.
- Stays above the main monitor window.
- Is topmost when the monitor is pinned.
- Monitoring continues while settings is open.
- Has only a close button in its custom title bar.
- Has no Save/Apply/Cancel buttons.
- Shows inline feedback near the bottom of the settings window.

Current size:

- `800 x 470`
- Minimum `760 x 430`
- Not resizable in the current WinForms implementation.

Current tabs:

1. `Targets`
2. `Columns`
3. `Timing`
4. `Health`
5. `General`

Settings commit semantics:

- Numeric/text edits commit on Enter or focus leave/validation.
- Checkboxes commit on deliberate click.
- Target grid text commits on cell edit end.
- Invalid edits are rejected.
- Previous valid value remains active.
- UI controls restore to the active value after rejected edits.
- Inline feedback explains errors.
- Settings that affect monitoring reset all target state/history.

## Settings - Targets Tab

Targets tab capabilities:

- Add target.
- Delete target.
- Move selected target up.
- Move selected target down.
- Enable/disable target.
- Edit target name.
- Edit target address.
- Edit target color hex.
- Show color preview swatch for selected target.

Current target grid columns:

- `Enabled`
- `Node`
- `Address`
- `Color`

Add target behavior:

- New target name is `Node1`, `Node2`, etc., choosing the first unused name.
- New target address is `localhost`.
- New target color is `#27d9e6`.
- New target is enabled.
- Main monitor state resets and grid rebuilds.

Delete behavior:

- Deletes selected target.
- If selected target is the last enabled target, deletion is blocked.
- Main monitor state resets and grid rebuilds.

Enable/disable behavior:

- Disabled targets are hidden from main grid.
- Disabling the last enabled target is blocked.
- Main monitor state resets and grid rebuilds.

Validation:

- Target name cannot be blank.
- Target names are unique, case-insensitive.
- Address must be valid IPv4 or valid hostname.
- Color must match `#RRGGBB`.
- At least one enabled target is required.

## Settings - Columns Tab

Columns tab capabilities:

- Toggle visibility for any supported column.
- Move selected column up/down.
- Edit selected column width.

Column visibility rules:

- Any supported column can be hidden.
- Hiding the last visible column is blocked.

Column order:

- Controlled by persisted `Columns` array order.
- Main grid rows remain target-order only.

Width behavior:

- Width edits commit on Enter or focus leave.
- Width is constrained by each column's minimum and max `2000`.
- Main grid column resize/reorder persistence is debounced in the current WinForms app.

## Settings - Timing Tab

Timing controls:

- `Refresh interval (ms)`
  - Range: `250` to `60000`
  - Default: `1000`
  - Resets monitor state on change.
- `Ping timeout (ms)`
  - Range: `100` to `60000`
  - Default: `1000`
  - Resets monitor state on change.
- `History length`
  - Range: `4` to `60`
  - Default: `12`
  - Resets monitor state on change.
- `Auto-start monitoring on launch`
  - Boolean.
  - Default: `true`.
  - If enabled while monitoring is stopped, starts monitoring and triggers a cycle.

## Settings - Health Tab

Health controls:

- `DOWN after failed pings`
  - Config key: `Health.DownFailures`
  - Range: `1` to `20`
  - Default: `3`
- `Orange after failed pings`
  - Config key: `Health.OrangeFailures`
  - Range: `1` to `20`
  - Default: `2`
- `Orange rolling loss (%)`
  - Config key: `Health.OrangeLossPercent`
  - Range: `0` to `100`
  - Default: `25`

RTT controls:

- `Green max (ms)`
  - Range: `0` to `60000`
  - Default: `50`
- `Yellow max (ms)`
  - Range: `1` to `60000`
  - Default: `100`
- `Orange max (ms)`
  - Range: `1` to `60000`
  - Default: `250`

RTT ordering validation:

- `GreenMax < YellowMax < OrangeMax`

Loss controls:

- `Yellow max (%)`
  - Range: `0` to `100`
  - Default: `10`
- `Orange max (%)`
  - Range: `0` to `100`
  - Default: `25`

Loss ordering validation:

- `YellowMax <= OrangeMax`

All health/RTT/loss edits reset monitor state.

## Settings - General Tab

General controls:

- `Always on top`
  - Boolean.
  - Default: `false`.
  - Applies immediately.
  - Persists to config.
- `Debug logging`
  - Boolean.
  - Default: `false`.
  - Persists to config.
- `Reset Window Position`
  - Moves main window to bottom-left default placement.
  - Persists current bounds after movement.
- `Reset to Defaults`
  - Shows confirmation prompt.
  - On yes, writes default config, resets monitor state, applies columns, resets window location, restarts monitoring if auto-start is true, shows feedback, and closes settings.

## Config Behavior

Config path:

`Scripts\Network_Monitor\config\NetworkMonitor.config.json`

Current behavior:

- Auto-create on first run.
- Strictly validate loaded config as supplied.
- Reject malformed/incomplete/invalid config as a whole.
- Back up rejected config as `NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json`.
- Generate complete defaults after rejection.
- Save atomically via temp file and replace/move.
- Live edits are transactional:
  - Deep clone current config.
  - Apply candidate edit to clone.
  - Validate clone.
  - Save clone.
  - Replace live config only after successful save.

## Logging Behavior

Normal operation:

- No routine logs when debug mode is off.

Debug mode:

- Logs to `logs\NetworkMonitor-YYYYMMDD.log`.
- Logs selected debug-only diagnostics, including:
  - Ping start/result errors.
  - Runtime config effect messages.
  - Config edit errors surfaced through `Show-NMConfigError`.
  - Column persistence failures.
  - Grid paint failures.
  - Config save failures on close.
- Target validation and settings commit failures are primarily surfaced through inline settings feedback unless they pass through `Show-NMConfigError`.

Startup failures:

- Always may write `logs\NetworkMonitor.startup-error.log`, even if debug mode is off.
- Show message box if UI assemblies are available.

WPF rewrite requirement:

- Preserve no-noise normal operation.
- Preserve startup failure visibility.
- Add WPF dispatcher exception handling equivalent to WinForms thread exception handling.
