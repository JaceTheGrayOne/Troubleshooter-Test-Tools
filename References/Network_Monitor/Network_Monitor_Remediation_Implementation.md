# Network Monitor Remediation Implementation Plan

Generated: 2026-06-22

## Scope

This plan covers remediation of the generated app under:

`Scripts\Network_Monitor`

It is based on the contract, QA conversation, mockup, original console script, current generated implementation, and `Network_Monitor_Remediation.md`.

The reference script must remain untouched:

`References\Network_Monitor\Network_Monitor.ps1`

The target remains a native, standalone PowerShell WinForms application with no external packages, downloads, web assets, WPF rewrite, or HTML wrapper.

## Remediation Goal

Repair the current implementation so it renders as a compact dark WinForms dashboard matching the mockup direction and contract, while retaining the working monitoring core where practical.

The main failure is presentation-layer architecture. The ping engine, state model, validation helpers, launcher shims, and much of the icon drawing are salvageable. The main form, grid rendering, settings commit behavior, and config load/edit semantics need targeted rewrites.

## Current Failure Map

1. `Scripts\Network_Monitor\Scripts\MainForm.ps1`
   - `CellPainting` calls `Graphics.Clear($background)` for every data cell.
   - This clears the whole grid drawing surface instead of the current cell, causing previously painted cells, headers, and borders to disappear.
   - This directly explains the black box with surviving yellow history stripes.

2. `Scripts\Network_Monitor\Scripts\MainForm.ps1`
   - The grid manually paints almost every cell.
   - Native `DataGridView` text, header, background, and border behavior is mostly bypassed.
   - This creates avoidable fragility around repaint order, DPI, resizing, scrolling, and invalidation.

3. `Scripts\Network_Monitor\Scripts\MainForm.ps1`
   - `Render-NMGrid` clears and recreates all rows after each ping cycle.
   - This creates flicker, layout churn, unnecessary allocation, and lost row state.

4. `Scripts\Network_Monitor\Scripts\MainForm.ps1` and `UiHelpers.ps1`
   - Default geometry is too large for the compact dashboard and too small for its own current controls.
   - Title bar, headers, rows, and fonts are oversized relative to the mockup and utility use case.
   - Title bar layout uses hard-coded coordinates and includes a monitor icon even though the contract says no title icon is required.

5. `Scripts\Network_Monitor\Scripts\MainForm.ps1`
   - Monitoring starts before `Application.Run()`.
   - Startup should start monitoring from the form `Shown` event after controls and message loop exist.

6. `Scripts\Network_Monitor\config\NetworkMonitor.config.json`
   - The distributed runtime config contains development-machine window coordinates.
   - This prevents true first-run bottom-left placement when copied to another machine.

7. `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
   - Several settings commit on `ValueChanged`, contrary to the Enter/focus-leave requirement.
   - This causes repeated JSON writes, repeated grid rebuilds, and needless state resets.

8. `Scripts\Network_Monitor\Scripts\Config.ps1`
   - Config loading merges supplied values into defaults before validation.
   - The contract requires rejecting the whole invalid or incomplete config file, backing it up, and regenerating defaults.

9. Error handling
   - Hidden launch plus debug-off normal operation can hide fatal startup, paint, or worker exceptions.
   - Fatal initialization errors should surface through a message box and a small startup error log even when debug logging is off.

## Implementation Principles

- Treat `MainForm.ps1` as a failed presentation layer and rewrite it around stable WinForms patterns.
- Keep code compact and modular for hand-copying to the target machine.
- Let `DataGridView` render ordinary backgrounds, text, headers, selection, scrolling, and borders.
- Use custom painting only where it has clear value:
  - Status dot plus status text if needed.
  - History tick bars.
- Keep rows persistent and update cell values in place after ping cycles.
- Rebuild rows only when target or column configuration changes.
- Use transactional config edits: validate and save a cloned config before replacing the live in-memory config.
- Start monitoring only after the main form has been shown.
- Preserve normal log-free operation, but make fatal startup failures visible.

## Retain With Limited Changes

These areas are directionally sound and should not be rewritten wholesale:

- `Network_Monitor.ps1`
  - Relative app-root discovery.
  - STA relaunch behavior.
  - Modular script loading.

- `Run_Network_Monitor.cmd` and `Run_Network_Monitor.vbs`
  - PowerShell 7 preference and hidden launch pattern.

- `Scripts\PingEngine.ps1`
  - Background worker model.
  - Concurrent `SendPingAsync()` calls.
  - Skipping cycles when the worker is busy.
  - Disposal of `Ping` instances.

- `Scripts\MonitorState.ps1`
  - Rolling history model.
  - Consecutive failure tracking.
  - Health precedence.
  - RTT, loss, TTL, and bytes text helpers.

- `Scripts\Validation.ps1`
  - Supported column definitions.
  - IPv4, hostname, color, threshold, and config validation helpers.
  - Some validation tightening may be needed for strict whole-file config rejection.

- `Scripts\UiHelpers.ps1`
  - Borderless resize subclass.
  - Native drag support.
  - Custom-drawn title-bar icons.

## Phase 1 - Stabilize Rendering For Diagnosis

Purpose: make the existing app visible enough to debug while the larger UI remediation is underway.

Changes:

- In `MainForm.ps1`, replace `Graphics.Clear($background)` inside grid `CellPainting`.
- Fill only `eventArgs.CellBounds`, or use:
  - `eventArgs.CellStyle.BackColor = $background`
  - `eventArgs.PaintBackground($eventArgs.CellBounds, $true)`
- Wrap the custom paint path in a narrow `try/catch`.
- When debug mode is enabled, log paint exceptions with row, column, and target name.

Expected result:

- The black box/yellow stripe failure should be eliminated.
- This is not the final UI architecture. It is only the first safe checkpoint.

## Phase 2 - Rebuild Main Form Layout

Primary file:

`Scripts\Network_Monitor\Scripts\MainForm.ps1`

Supporting file:

`Scripts\Network_Monitor\Scripts\UiHelpers.ps1`

Changes:

- Keep the borderless `NetworkMonitorForm` resize subclass.
- Use a docked form layout:
  - Outer form with `FormBorderStyle = None`.
  - Top title bar docked `Top`.
  - Grid docked `Fill`.
- Remove the monitor title-bar icon.
- Build the title bar with layout containers instead of fixed pixel positions:
  - Title label docked/filling the remaining left area.
  - Right-side button container with fixed-width icon buttons.
  - Settings, reset/refresh, pin, separator, minimize, maximize/restore, close.
- Keep title-bar drag and double-click maximize/restore behavior.
- Ensure the window/taskbar title is exactly:

`Network Monitor - Troubleshooter Test Tools`

- Reduce visual scale to match the compact utility dashboard:
  - Title bar: about 44 to 48 px.
  - Column header: about 36 to 40 px.
  - Rows: about 48 to 54 px.
  - Title font: about 12 pt Segoe UI.
  - Header font: about 10.5 to 11.5 pt Segoe UI bold.
  - Grid font: about 10.5 to 11.5 pt Consolas.
- Keep minimum size large enough for the default six columns without clipping, likely around `820 x 260`.
- Calculate default height from title bar height, header height, enabled target count, row height, border, and scrollbar allowance.
- Initial width should be the sum of default visible column widths plus border/scrollbar allowance.

Expected result:

- The first viewport resembles the mockup: title bar above a compact six-column grid, no summary strip, no footer, no warning banner.
- The title bar behaves like a normal Windows app despite being custom-drawn.

## Phase 3 - Replace Grid Rendering Strategy

Primary file:

`Scripts\Network_Monitor\Scripts\MainForm.ps1`

Changes:

- Configure `DataGridView` to handle standard rendering:
  - Dark background and alternating row colors.
  - Header styling.
  - Grid line color.
  - No row headers.
  - No user-added rows.
  - Read-only.
  - Column resize and reorder enabled.
  - Sorting disabled.
  - Horizontal and vertical scrollbars enabled.
- Keep `DataGridViewTextBoxColumn` for all columns.
- Use `CellFormatting` for:
  - Node color from target color.
  - RTT text color from RTT health.
  - Loss text color from loss health.
  - TTL and Bytes neutral placeholders.
  - Normal Address text.
- Use `CellPainting` only for:
  - `Status`
  - `History`
- In custom paint:
  - Paint only the current cell background.
  - Use `PaintBackground()` or fill `CellBounds`, never `Graphics.Clear()`.
  - Draw the status dot and status text within `CellBounds`.
  - Draw history bars within `CellBounds`.
  - Draw only the current cell border if overriding border painting.
  - Set `eventArgs.Handled = $true` only for custom-painted cells.
- Let normal cells remain unhandled and allow `DataGridView` to paint them.

Expected result:

- Headers, text, row backgrounds, and scrolling become stable under repaint, resize, and DPI changes.
- Custom drawing is limited to the two pieces that actually need it.

## Phase 4 - Persistent Rows And Incremental Updates

Primary file:

`Scripts\Network_Monitor\Scripts\MainForm.ps1`

Changes:

- Replace per-cycle `Render-NMGrid` row clearing with persistent row construction.
- Add a row map:

`$script:NMRowsByTarget`

- Add focused helpers:
  - `Rebuild-NMGridColumns`
  - `Rebuild-NMGridRows`
  - `Update-NMGridRow`
  - `Update-NMGridFromState`
  - `Invalidate-NMCustomCells`
- Build rows once for the enabled targets in configured target order.
- Store target name in `row.Tag`.
- After each ping cycle:
  - Update only changed cell values for each existing row.
  - Invalidate the row or only the `Status` and `History` cells.
  - Do not clear rows.
  - Do not recreate columns.
- Rebuild rows only when:
  - Target list changes.
  - Target order changes.
  - Target enabled state changes.
  - Column visibility/order changes in a way that requires a grid reset.
- Preserve column width/order from the live grid before a rebuild.

Expected result:

- Reduced flicker.
- Lower UI thread work.
- Stable scroll/selection state.
- More predictable custom painting.

## Phase 5 - Correct Monitoring Lifecycle

Primary file:

`Scripts\Network_Monitor\Scripts\MainForm.ps1`

Supporting file:

`Scripts\Network_Monitor\Scripts\PingEngine.ps1`

Changes:

- Initialize the ping engine before showing the form, but do not start monitoring immediately.
- Add form `Shown` handler:
  - If `AutoStart` is true, call `Start-NMMonitoring`.
  - Immediately call `Invoke-NMPingCycle`.
- Keep timer ticks skipped when the worker is busy.
- Ensure reset/refresh:
  - Increments generation.
  - Clears state/history.
  - Updates grid rows in place.
  - Starts or continues monitoring.
  - Starts a fresh ping cycle if the worker is not busy.
- Ensure form close:
  - Stops the timer.
  - Saves window placement.
  - Saves config.
  - Exits completely.

Expected result:

- Ping work begins after WinForms is ready.
- Reset behavior matches the contract without closing or recreating the window.

## Phase 6 - Strict Config Loading And Runtime Config Handling

Primary file:

`Scripts\Network_Monitor\Scripts\Config.ps1`

Supporting file:

`Scripts\Network_Monitor\Scripts\Validation.ps1`

Changes:

- Change load flow to strict whole-file validation:
  1. Read JSON.
  2. Convert to ordered dictionaries.
  3. Validate the supplied structure as-is.
  4. If any required section or field is missing or invalid, reject the entire file.
  5. Move the invalid file to `NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json`.
  6. Create and save complete defaults.
- Remove config merge from normal load path.
- Keep default generation for first run.
- Keep atomic save behavior:
  - Write temp file.
  - Replace or move into place.
  - Delete replace backup when successful.
- Add a transactional config edit helper, for example:

`Invoke-NMConfigEdit`

The helper should:

  - Clone the current config.
  - Apply the proposed edit to the clone.
  - Validate the clone.
  - Save the clone.
  - Replace `$script:NMConfig` only after successful validation and save.
  - Leave the live config unchanged on failure.

- Do not distribute machine-specific runtime coordinates:
  - Preferred: add `Scripts/Network_Monitor/config/NetworkMonitor.config.json` to `.gitignore`.
  - Preferred: commit `NetworkMonitor.config.example.json` only if a template is useful.
  - Minimum acceptable fallback: set distributed `Window.X` and `Window.Y` to `null`.

Expected result:

- Invalid config behavior matches the contract.
- Live settings changes cannot leave rejected values active in memory.
- Fresh copies open bottom-left instead of using development-machine coordinates.

## Phase 7 - Settings Commit Semantics

Primary file:

`Scripts\Network_Monitor\Scripts\SettingsForm.ps1`

Supporting file:

`Scripts\Network_Monitor\Scripts\Config.ps1`

Changes:

- Replace direct live config mutation with transactional edit calls.
- Replace numeric `ValueChanged` commits for timing, health, RTT, loss, and column widths.
- Commit numeric fields on:
  - Enter key.
  - Focus leave or `Validated`.
- Checkboxes may still commit on click when the value change is the deliberate interaction:
  - Always on top.
  - Debug logging.
  - Auto-start.
  - Target enabled.
  - Column visible.
- Text target fields commit on:
  - Enter key.
  - Cell end edit.
  - Row focus change.
- Invalid input should:
  - Reject the proposed edit.
  - Keep the previous valid value.
  - Restore the UI control to the active value.
  - Show inline feedback.
- Column width persistence:
  - Persist after resizing completes, after a short debounce, or on form close.
  - Do not write JSON for every intermediate drag event.
- Settings window topmost behavior:
  - Owned by the monitor form.
  - Always above the monitor.
  - Also topmost when the monitor is pinned.
- Settings cog active color:
  - Active blue while settings window exists.
  - Neutral when closed.

Expected result:

- Settings match the user's Enter/focus-leave requirement.
- Grid rebuilds and state resets happen only on committed changes.
- Invalid edits do not leak into runtime state.

## Phase 8 - Error Reporting And Diagnostics

Primary files:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Scripts\Logging.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`

Changes:

- Add top-level startup `try/catch` around module loading and app startup.
- If WinForms can be loaded, show a `MessageBox` for fatal initialization errors.
- Write a small startup error log when the app cannot start, even if debug mode is off:

`logs\NetworkMonitor.startup-error.log`

- Register:
  - `[System.Windows.Forms.Application]::ThreadException`
  - `[System.AppDomain]::CurrentDomain.UnhandledException`
- Keep normal operation log-free unless debug mode is enabled.
- Continue using debug logging for:
  - Config reject/load/save details.
  - Ping worker exceptions.
  - Paint handler exceptions.
  - Settings commit failures.

Expected result:

- A hidden launch no longer fails silently into an unusable black window.
- Normal no-debug operation still avoids routine log noise.

## Phase 9 - Final Visual Pass

Primary files:

- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`

Changes:

- Align the UI to the mockup and contract:
  - Dark custom title bar.
  - Compact title text.
  - Right title-bar buttons in the required order.
  - No app title icon.
  - No summary strip, footer, warning banner, or bottom controls.
  - Grid-only content area.
  - Default columns: `Node`, `Address`, `Status`, `RTT`, `Loss`, `History`.
  - Hidden optional columns: `TTL`, `Bytes`.
- Ensure node color is used only for target identity/accent.
- Ensure health colors control:
  - Status dot.
  - Status text if custom-painted.
  - History ticks.
  - RTT text.
  - Loss text.
- Use yellow for unfilled history samples.
- Keep red history ticks for failed/timeout samples.
- Ensure text does not clip at default width and practical minimum widths.

Expected result:

- The app looks like the mockup's compact dark dashboard rather than a blank/oversized custom-painted panel.

## Verification Plan

Run these checks after implementation.

### Static Checks

- Parse all PowerShell files with the PowerShell parser.
- Confirm no syntax errors in:
  - `Network_Monitor.ps1`
  - every file under `Scripts\Network_Monitor\Scripts`
- Confirm `References\Network_Monitor\Network_Monitor.ps1` is unchanged.

### Launch Checks

- Direct launch:

`pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Network_Monitor.ps1`

- CMD shim launch:

`Scripts\Network_Monitor\Run_Network_Monitor.cmd`

- VBS launch:

`wscript.exe Scripts\Network_Monitor\Run_Network_Monitor.vbs`

Acceptance:

- App appears in taskbar.
- No console remains visible from shim launch.
- App starts in STA.
- Monitoring auto-starts.
- Closing the main window exits completely.

### First-Run And Config Checks

- Delete or move runtime config, then launch.
- Confirm config auto-creates in:

`Scripts\Network_Monitor\config\NetworkMonitor.config.json`

- Confirm first-run location is bottom-left of primary working area:
  - Flush against left edge.
  - Flush against taskbar boundary.
  - Does not cover taskbar.
- Move/resize window, close, relaunch, confirm bounds persist.
- Write invalid config, relaunch, confirm:
  - Invalid file is backed up with timestamp.
  - Defaults regenerate.
  - App still starts.
- Write off-screen saved coordinates, relaunch, confirm bottom-left fallback.

### Grid Checks

- Confirm default visible columns:
  - `Node`
  - `Address`
  - `Status`
  - `RTT`
  - `Loss`
  - `History`
- Confirm `TTL` and `Bytes` exist and are hidden by default.
- Confirm rows show enabled targets in configured order.
- Confirm row updates do not clear/recreate the full grid every second.
- Confirm no flicker or disappearing headers during refresh.
- Confirm column resize and reorder persist.
- Confirm horizontal scrolling appears when visible columns exceed window width.

### Monitoring Checks

- Confirm one concurrent `SendPingAsync()` ping per enabled target per cycle.
- Confirm UI remains responsive during timeouts.
- Confirm a busy worker causes a skipped timer tick with no history/loss mutation.
- Confirm timeout/failure produces a red history tick.
- Confirm unfilled history is yellow.
- Confirm `Status` remains `UP` for yellow/orange health and changes to `DOWN` only after the down threshold.
- Confirm `RTT` shows:
  - `NA` before first sample.
  - `<n> ms` on success.
  - `timeout` on latest failed attempt.
- Confirm `Loss` is rolling loss over the configured history window.

### Settings Checks

- Open settings, click cog again, confirm the existing settings window focuses.
- Confirm settings remains above monitor.
- Toggle pin, confirm monitor and settings topmost behavior.
- Edit timing/threshold numeric values:
  - No commit on every intermediate spinner/text change.
  - Commit on Enter or focus leave.
  - Invalid input restores the previous valid value.
- Edit targets:
  - Add target.
  - Edit target name/address/color.
  - Delete target.
  - Reorder target.
  - Disable target.
  - Confirm zero enabled targets is blocked.
  - Confirm duplicate names are blocked.
  - Confirm invalid address/color is blocked.
- Confirm settings changes that affect monitoring reset all ping history/state.
- Confirm Reset to Defaults prompts for confirmation and restores defaults.

### Visual Checks

- Check at 100 percent and 125 percent Windows display scaling.
- Check default window at 1080p-class monitor height.
- Check compact height with three targets.
- Check maximized and restored states.
- Check all title-bar buttons:
  - Settings.
  - Reset/refresh.
  - Pin.
  - Minimize.
  - Maximize/restore.
  - Close.

## Suggested Implementation Order

1. Create a working branch or checkpoint.
2. Apply the minimal `Graphics.Clear` fix and debug paint logging.
3. Add startup fatal error handling.
4. Refactor title bar to docked layout and remove title icon.
5. Reduce theme font sizes, title/header/row heights, and default geometry.
6. Convert grid to mostly standard `DataGridView` rendering.
7. Add persistent rows and in-place row updates.
8. Move monitoring start to form `Shown`.
9. Replace config load merge with strict validation and backup behavior.
10. Add transactional config edit helper.
11. Refactor settings commits to Enter/focus-leave semantics.
12. Remove or neutralize distributed runtime config coordinates.
13. Run the verification plan.
14. Do a final visual pass against the mockup.

## Definition Of Done

- The app no longer renders as a black box or yellow-stripe artifact.
- The main window visually resembles the compact mockup and uses only the grid as main content.
- Monitoring starts automatically and stays responsive during timeout scenarios.
- The grid updates in place without full row recreation each cycle.
- Status, RTT, loss, and history behavior match the contract.
- Settings commit behavior matches Enter/focus-leave semantics.
- Invalid config is rejected as a whole and backed up.
- First-run placement and persisted/off-screen placement behavior match the contract.
- Debug-off normal operation writes no routine logs.
- Fatal startup failures are visible and diagnosable.
- The reference console script remains untouched.
