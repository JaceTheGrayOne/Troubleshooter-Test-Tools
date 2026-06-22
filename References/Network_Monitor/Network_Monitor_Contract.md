# Network Monitor Implementation Contract

Generated: 2026-06-22

This contract is intended for a future Codex implementation session. Optimize implementation decisions for compact, maintainable PowerShell code that can be copied to an offline target machine. Do not assume internet access or package downloads.

## Objective

Build a native, standalone PowerShell WinForms Network Monitor application based on the visual direction in:

`References\Network_Monitor\Network_Monitor_Mockup.png`

The app replaces the current console/ASCII dashboard experience with a compact, resizable, dark WinForms dashboard that can run independently of `ToolLauncher.ps1`. The existing reference script must remain untouched.

## Non-Negotiable Constraints

- Do not edit `References\Network_Monitor\Network_Monitor.ps1`.
- New app code lives under `Scripts\Network_Monitor`.
- Main standalone entry point is `Scripts\Network_Monitor\Network_Monitor.ps1`.
- App must be directly launchable in isolation for target-PC testing without relying on TTT runtime helpers.
- All app-local paths resolve relative to the Network Monitor entry script location.
- Any project-root assumptions must be derived safely from the script/app location, not hard-coded absolute paths.
- No external dependencies, no internet access, no NuGet/module downloads.
- Use PowerShell plus .NET WinForms/Drawing APIs available to PowerShell 7.5.2.
- Prefer PowerShell 7 via `pwsh.exe`; fallback to Windows PowerShell only if needed.
- Code should be modularized. Avoid repeated blocks and repeated control-construction logic. Shared behavior belongs in helper functions or module/script files.

## Proposed File Layout

Implementation root:

`Scripts\Network_Monitor`

Expected files/folders:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
  - Standalone app entry point.
  - Handles app root detection, STA/runtime relaunch, module loading, and application startup.
- `Scripts\Network_Monitor\Run_Network_Monitor.cmd`
  - Group-policy-friendly visible entry shim, matching the existing TTT launcher pattern.
- `Scripts\Network_Monitor\Run_Network_Monitor.vbs`
  - Hidden launcher shim. Starts PowerShell without leaving a visible console.
- `Scripts\Network_Monitor\Scripts\*.ps1`
  - Modular implementation files for config, UI helpers, monitor state, settings form, ping engine, validation, and rendering.
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`
  - Persisted settings/config. Auto-created on first run.
- `Scripts\Network_Monitor\logs\`
  - Used only when debug mode is enabled.

## Startup Contract

- App must work when launched directly via `Network_Monitor.ps1`.
- App must work when launched through `Run_Network_Monitor.cmd`.
- `Run_Network_Monitor.cmd` starts `Run_Network_Monitor.vbs`.
- `Run_Network_Monitor.vbs` launches `pwsh.exe` hidden with:
  - `-NoProfile`
  - `-ExecutionPolicy Bypass`
  - `-STA`
  - `-File "<appRoot>\Network_Monitor.ps1"`
- If `pwsh.exe` is unavailable, VBS falls back to `powershell.exe`.
- `Network_Monitor.ps1` must also self-relaunch hidden/STA if started from a non-STA session.
- The script self-relaunch should prefer `pwsh.exe`, then fallback to `powershell.exe`.
- The app must not require the main `ToolLauncher.ps1` process to remain open.
- Later launcher integration can use the same standalone app. Preferred TTT launch target is the VBS shim if that avoids visible shell windows.

## Main Window Visual Contract

The UI should closely reproduce the saved mockup, with the following final adjustments:

- Window title text is exactly:
  - `Network Monitor - Troubleshooter Test Tools`
- The form/window/taskbar title must also use that exact text.
- No title-bar app icon is required.
- Use a custom/borderless title bar matching the mockup style and TTT dark visual language.
- Title bar supports normal user expectations:
  - click-drag to move
  - double-click maximize/restore where practical
  - minimize
  - maximize/restore
  - close
- Window appears in the Windows taskbar.
- Window is resizable.
- Window should not be optimized for tiny displays. Target systems use ultrawide/1080p-class monitors.
- Minimum size can be around `760 x 220` or larger if needed to prevent clipping.
- Initial/default size should fit the default visible columns without clipping and still feel compact in the bottom-left corner.
- On first run, open at the bottom-left of the primary monitor working area:
  - flush against the left edge
  - flush against the taskbar boundary
  - do not cover the taskbar
  - no visible gap between taskbar boundary and app window
- Persist last window size and position across launches.
- If persisted position is invalid/off-screen, fallback to bottom-left taskbar-flush placement.

## Title Bar Buttons

Right side of the custom title bar must include:

- Settings cog
- Reset/refresh button
- Pin button for always-on-top
- Minimize
- Maximize/restore
- Close

Icon rules:

- Use custom-drawn icons rather than font glyphs for consistency.
- Pin icon has neutral/no active color when unpinned.
- Pin icon uses Windows/PowerShell-style light blue active color when pinned.
- Settings cog uses the same blue active color while the settings window is open.
- Reset/refresh icon can be a typical curled-arrow refresh symbol.

Reset/refresh button behavior:

- Clears all current ping data, history, health state, loss state, and counters.
- Starts a fresh ping cycle.
- Does not reset persisted settings.
- Does not close/reopen the window.

Pin behavior:

- Toggles always-on-top immediately.
- Persists the always-on-top setting across launches.

Close behavior:

- Stops monitoring.
- Exits completely.
- Does not minimize/hide to tray.

## Main Grid Contract

The main content area is the grid only. Do not add the removed mockup elements:

- No top summary strip.
- No bottom control bar.
- No footer text.
- No warning banner.

Default visible columns:

- `Node`
- `Address`
- `Status`
- `RTT`
- `Loss`
- `History`

Supported optional columns:

- `TTL`
- `Bytes`

Columns not included in first implementation:

- `Last Seen`
- `Last Success`
- `Avg RTT`
- `Min RTT`
- `Max RTT`

Column behavior:

- Any supported column can be hidden.
- Any supported column can be reordered.
- Column widths are user-resizable.
- Column order, visibility, and widths are persisted.
- Rows are always shown in configured target order.
- No column sorting required.
- Columns must enforce practical minimum widths based on displayed data so text is not clipped/hidden.
- If many columns are visible, the grid/window should support the configured layout without silently hiding data.

Default row data:

| Node | Address | Default Color | Enabled |
|---|---|---:|---|
| SMS | 192.168.51.20 | `#ff40e6` | true |
| MPS | 192.168.101.20 | `#ff40e6` | true |
| MPG | 192.168.200.100 | `#27d9e6` | true |

Address column:

- Label is `Address`, not `IP`.
- Accepts IPv4 addresses and hostnames.
- Displays configured address exactly as entered.

Target color usage:

- Target color is used for node identity/accent, primarily the node name.
- Health colors control status dot, status state, history ticks, RTT text, and Loss text.

## Monitoring Contract

- Monitoring auto-starts immediately when the window opens.
- There are no visible Start/Pause controls in the main window.
- Use `System.Net.NetworkInformation.Ping.SendPingAsync()`.
- Send one ping per enabled target per refresh cycle.
- Pings for targets in the same cycle should run concurrently.
- Ping work must run off the WinForms UI thread.
- UI updates must be marshaled back safely to the UI thread.
- Default refresh interval is `1 second`.
- Refresh interval is configurable.
- Default ping timeout is `1000 ms`.
- Ping timeout is configurable.
- If a refresh tick fires while a previous ping cycle is still running:
  - skip the tick
  - do not queue it
  - do not alter history, loss, health, counters, or timestamps
  - do not show any skipped-tick indicator
- Attempted pings that timeout/fail are recorded immediately as failed samples.
- Settings changes that affect monitoring reset ping state/history for all targets.

## Status And Health Contract

Status text:

- `Status` remains `UP` unless the configured `DOWN` condition is met.
- Degraded yellow/orange health does not change text to `WARN` or `DEGRADED`.
- `DOWN` is shown only when the down condition is met.

Default down condition:

- `DOWN` after `3` consecutive failed pings.
- Threshold is configurable.

Health indicator precedence:

1. Red if down condition is met.
2. Orange if rolling loss is `>= 25%` or there are `2` consecutive failures.
3. Yellow if latest attempted ping failed or rolling loss is greater than `0%`.
4. Green otherwise.

These thresholds must be configurable.

History:

- Default history window is `12` samples/ticks.
- History length is configurable.
- Green tick means successful ping sample.
- Red tick means failed/timeout ping sample.
- Yellow tick means not enough data/unfilled history.
- Skipped cycles do not create ticks.

RTT:

- `RTT` displays the latest attempted cycle result for the target.
- On success, show latest successful round-trip time, e.g. `3 ms`.
- On timeout/failure for the latest attempted ping, show `timeout`.
- Before any sample exists, show a neutral placeholder such as `NA`.
- Do not show average/EMA RTT in first implementation.

RTT color thresholds:

- Green: `<= 50 ms`
- Yellow: `> 50 ms` through `100 ms`
- Orange: `> 100 ms` through `250 ms`
- Red: `> 250 ms`, timeout, failure, or no latest RTT

These thresholds must be configurable.

Loss:

- `Loss` is rolling loss over the configured history window.
- Do not use cumulative loss for the default `Loss` column.
- Cumulative loss is not required in first implementation.

Loss color thresholds:

- Green: `0%`
- Yellow: `> 0%` through `10%`
- Orange: `> 10%` through `25%`
- Red: `> 25%`

These thresholds must be configurable.

TTL and Bytes:

- Use values from successful ping replies.
- Hidden by default.
- If latest ping failed or no value exists, display a neutral placeholder such as `--`.

## Settings Window Contract

- Settings cog opens a non-modal settings window.
- Only one settings window may exist at a time.
- Clicking the cog while settings is already open focuses the existing settings window.
- Settings window is owned by the monitor window and should feel like the same app/subwindow.
- Settings window stays above the monitor window regardless of pinned state.
- If monitor is pinned always-on-top, settings should also remain topmost.
- Monitoring continues while settings is open.
- Settings window needs only a close button. No Save/Apply/Cancel buttons required.
- Committed settings persist automatically.

Settings commit behavior:

- Text/input edits commit when Enter is pressed inside the input or when focus leaves the input.
- Do not apply changes on every keystroke.
- Invalid input is rejected.
- Previous valid value remains active.
- Inline validation feedback should appear in the settings UI.

Settings layout:

- Use a simple tabbed settings window.
- Recommended tabs:
  - `Targets`
  - `Columns`
  - `Timing`
  - `Health`
  - `General`

Settings must include:

- Targets
- Target enabled/disabled
- Target order
- Target colors
- Refresh interval
- Ping timeout
- History length
- Always-on-top default/current state
- Auto-start
- Reset window position
- Visible columns
- Column order
- Column widths if practical in settings; at minimum persist widths from the grid
- Health/down thresholds
- RTT thresholds
- Loss thresholds
- Debug-mode toggle
- Reset to Defaults action with confirmation

Target settings:

- Can add targets.
- Can edit targets.
- Can delete targets.
- Can reorder targets.
- Can enable/disable targets.
- Disabled targets are hidden entirely from the main grid.
- At least one enabled target is required.
- Deleting or disabling is blocked if it would leave zero enabled targets.
- Validation blocks duplicate target names.
- Validation blocks invalid IPv4/hostname addresses.
- Target colors are entered as HTML hex colors, e.g. `#ff40e6`.
- Settings should show a small preview swatch/example box for target color values when possible.
- No color picker required in first implementation.

## Config Contract

Config path:

`Scripts\Network_Monitor\config\NetworkMonitor.config.json`

Config behavior:

- Auto-create config on first run if missing.
- Load whatever valid data exists in the config.
- If config is malformed or contains invalid data, reject the entire config.
- Preserve invalid config as a timestamped backup.
- Regenerate defaults after rejecting invalid config.
- Do not partially salvage invalid config in first implementation.
- Do not include a schema/version number for now.
- Validate config using the same rules the settings UI uses.
- Config writes must be atomic:
  - write to temp file
  - replace real config
  - avoid leaving partial files after interruption

Malformed backup naming:

`NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json`

Persisted config should include at least:

- Targets
- Enabled/disabled target state
- Target order
- Target colors
- Refresh interval
- Ping timeout
- History length
- Always-on-top
- Auto-start
- Window size
- Window position
- Visible columns
- Column order
- Column widths
- Down/health thresholds
- RTT thresholds
- Loss thresholds
- Debug mode

Default config values:

- Targets: SMS, MPS, MPG as defined above.
- Enabled targets: all three defaults enabled.
- Visible columns: Node, Address, Status, RTT, Loss, History.
- Hidden columns: TTL, Bytes.
- Refresh interval: 1 second.
- Ping timeout: 1000 ms.
- History length: 12.
- Down threshold: 3 consecutive failed pings.
- Always-on-top: persisted, initial default can be false unless better aligned with UX.
- Auto-start: true.
- Debug mode: false.

## Logging Contract

- Avoid logging during normal operation.
- Only write logs when debug mode is enabled.
- Debug mode is configurable and persisted.
- Logs live under `Scripts\Network_Monitor\logs`.
- Debug logs may include:
  - app startup/runtime path decisions
  - config load/save/reject events
  - ping-cycle errors/exceptions
  - target validation errors
  - settings commit failures
- No all-network-down warning banner. Let per-target status communicate failures.

## Code Quality Contract

Implementation should prioritize compact, hand-copyable, maintainable PowerShell over unnecessary pixel-perfect complexity.

Required code organization principles:

- Modularize repeated behavior.
- Avoid copy/paste UI construction blocks where a helper can create themed labels/buttons/panels.
- Centralize colors and fonts.
- Centralize validation.
- Centralize config load/save/default generation.
- Centralize target state initialization/reset.
- Centralize health-threshold calculation.
- Centralize UI-thread marshaling helpers if used more than once.
- Keep each file/function purpose narrow enough to debug by hand.
- Use comments sparingly, only where they clarify non-obvious behavior.

Implementation can use either:

- Styled WinForms built-in controls where they satisfy behavior cleanly, or
- Custom panel/label drawing where needed to match the mockup.

Do not waste effort on:

- Internet/network maps
- Tray icon behavior
- Start/Pause controls
- Warning banners
- Color picker dialog
- Average/min/max RTT columns
- Cumulative loss metric
- Partial config salvage parser
- PowerShell 5.1-specific support beyond incidental compatibility

## Acceptance Criteria

Manual acceptance checklist:

- Running `Scripts\Network_Monitor\Network_Monitor.ps1` starts the app standalone.
- Running `Scripts\Network_Monitor\Run_Network_Monitor.cmd` starts the app without leaving a visible console.
- App starts in STA and prefers PowerShell 7.
- App auto-starts monitoring immediately.
- Main launcher can be closed without stopping the monitor.
- Closing the monitor stops monitoring and exits.
- First run creates config under `Scripts\Network_Monitor\config`.
- Invalid config is backed up and defaults regenerate.
- Window opens bottom-left, flush to taskbar boundary, without covering taskbar.
- Window position/size persist and restore.
- Off-screen saved position falls back to bottom-left.
- Pin toggles always-on-top and persists.
- Settings cog opens one non-modal settings window and focuses it on repeated clicks.
- Settings window stays above monitor.
- Reset/refresh title-bar button clears state/history and starts fresh monitoring.
- Grid default columns are Node, Address, Status, RTT, Loss, History.
- TTL and Bytes exist but are hidden by default.
- Targets default to SMS, MPS, MPG with configured addresses and colors.
- Targets can be added, edited, deleted, reordered, enabled/disabled.
- Zero enabled targets is blocked.
- IPv4 and hostnames are accepted and displayed as entered.
- One ping per enabled target per cycle.
- Concurrent `SendPingAsync()` pings are used.
- UI remains responsive during timeouts.
- Overlapping cycles are skipped invisibly.
- Failures produce red history ticks.
- Unfilled history uses yellow ticks.
- Status remains UP for yellow/orange degradation and changes to DOWN only after down threshold.
- RTT and Loss text colors follow configured thresholds.
- Settings changes commit on Enter/focus-leave, reject invalid input, and persist valid changes.
- Normal operation writes no logs when debug mode is off.
