# Evaluation

## Primary failure: the grid renderer erases itself

The `CellPainting` handler calls this once for **every data cell**:

```powershell
$eventArgs.Graphics.Clear($background)
```

That is the critical defect. `Graphics.Clear()` clears the entire drawing surface, not merely the current cell. Microsoft’s own `DataGridView.CellPainting` example fills only `e.CellBounds`, or recommends using `PaintBackground()` and `PaintContent()`.  ([Microsoft Learn][1])

This explains the reported appearance unusually well:

1. A cell paints its text.
2. The next cell clears the drawing surface again.
3. Earlier text, headers, and borders are erased.
4. The `History` column subsequently draws its bars using `FillRectangle()`.
5. Empty history samples are explicitly yellow, so yellow stripes are among the few things left visible.

That is not a network problem, a PowerShell 7 problem, or an offline-resource problem. It is a fundamental misuse of the WinForms painting API.

The minimum correction is:

```powershell
# Wrong:
$eventArgs.Graphics.Clear($background)

# Minimum safe replacement:
$backgroundBrush = [System.Drawing.SolidBrush]::new($background)
try {
    $eventArgs.Graphics.FillRectangle(
        $backgroundBrush,
        $eventArgs.CellBounds
    )
}
finally {
    $backgroundBrush.Dispose()
}
```

A better correction is:

```powershell
$eventArgs.CellStyle.BackColor = $background
$eventArgs.PaintBackground($eventArgs.CellBounds, $true)
```

This one change should make substantially more of the current UI visible, but it will not address the rest of the design and stability problems.

## The implementation chose the wrong rendering strategy

The contract permits normal styled WinForms controls and only calls for custom painting where it is useful. It explicitly prioritizes compact, maintainable code over unnecessary pixel-perfect complexity.

Instead, the implementation manually paints essentially every data cell:

* Node text
* Address text
* Status dot and text
* RTT text
* Loss text
* History bars
* TTL and Bytes text
* Every individual cell border

That replaces reliable native `DataGridView` behavior with a fragile paint pipeline without providing a meaningful visual advantage.

The correct division should be:

* Let `DataGridView` render headers, backgrounds, borders, and normal text.
* Use `CellFormatting` to select colors for Node, RTT, and Loss.
* Custom-paint only the Status dot and History bars.
* Let the grid render the accompanying Status text normally where practical.

This would reduce the custom rendering code considerably and make the UI much less sensitive to repaint order, scrolling, resizing, DPI scaling, and invalidation.

## The grid is destroyed and recreated every second

Every result update calls `Render-NMGrid`, which clears all rows and recreates them:

```powershell
$script:NMGrid.Rows.Clear()
...
$rowIndex = $script:NMGrid.Rows.Add($values)
```

The ping completion handler invokes that operation after every cycle.

Consequences include:

* Excessive repainting and visible flicker.
* Repeated allocation of rows and cells.
* Loss of scroll and selection state.
* A higher chance of paint events interacting badly.
* Column and row layout being recalculated every second.
* More work on the UI thread than necessary.

The rows should be created once and associated with targets, for example:

```powershell
$script:NMRowsByTarget[$target.Name] = $row
```

Each ping cycle should then update only the affected cell values and invalidate only the two custom-painted cells:

```powershell
$row.Cells['Status'].Value  = Get-NMStatusText -State $state
$row.Cells['RTT'].Value     = Get-NMRttText -State $state
$row.Cells['Loss'].Value    = Get-NMLossText -State $state

$grid.InvalidateCell($row.Cells['Status'])
$grid.InvalidateCell($row.Cells['History'])
```

Rows need rebuilding only when targets or column configuration change.

## The default geometry cannot fit its own content

The defaults specify a window height of `330`. The main elements require approximately:

* Title bar: `66`
* Column header: `58`
* Three rows at `70` each: `210`

That totals `334` before borders, padding, or a horizontal scrollbar.

Therefore, the initial window is guaranteed to clip some content. It also works against the reference requirement for a compact dashboard: a 66-pixel title bar, 58-pixel header, 70-pixel rows, 18-point title, and 15-point grid text are visually oversized for this type of utility.

A more appropriate starting point would be approximately:

* Title bar: 42–48 pixels
* Column header: 34–40 pixels
* Rows: 46–54 pixels
* Title font: 11–13 points
* Grid font: 10–12 points

The default height should be calculated from the actual number of enabled targets rather than being an unrelated constant.

## The title bar is brittle and deviates from the stated direction

The title bar uses hard-coded positions and widths:

* A 44-pixel monitor icon.
* A title label fixed initially at 560 pixels.
* A 342-pixel button panel.
* Six manually positioned 46-pixel buttons.

The Q&A said a title-bar application icon was unnecessary, but the implementation added a custom monitor icon anyway.

This should be replaced with a docked layout:

* Left: title label with `Dock = Fill`.
* Right: a fixed-width `FlowLayoutPanel` or `TableLayoutPanel`.
* No monitor icon.
* Settings, refresh, pin, minimize, maximize, and close buttons aligned consistently.
* Title text ellipsized if the window becomes too narrow.

The custom-drawn button icons themselves can remain; they are local, predictable, and offline-safe.

## Monitoring begins before the form’s message loop is running

The application builds the form, initializes the worker, starts the timer, and launches an immediate ping cycle before calling `Application.Run()`.

This is unnecessarily fragile. Initial monitoring should begin from the form’s `Shown` event, after the control handles and WinForms message loop exist:

```powershell
$form.Add_Shown({
    if ($script:NMConfig.AutoStart) {
        Start-NMMonitoring
        Invoke-NMPingCycle
    }
})
```

The current ordering may not be the cause of the black display, but it complicates startup failures and worker completion behavior.

## Hidden launch also hides useful failures

The VBS launcher correctly starts PowerShell invisibly, but debug logging is off by default. As a result, exceptions raised during paint events, worker callbacks, startup, or configuration writes can disappear without useful operator feedback.

Normal operation should remain log-free, as required. Fatal startup or rendering errors are different. At minimum:

* Wrap application startup in a top-level `try/catch`.
* Show a local `MessageBox` for fatal initialization errors.
* Write a small `NetworkMonitor.startup-error.log` only when the application cannot start.
* Register a WinForms thread-exception handler.
* Log paint-handler exceptions when debug mode is active.

Without that, a black window is all the user sees while the actual exception is lost.

## The distributed configuration contains development-machine coordinates

The committed configuration contains:

```json
"X": 553,
"Y": 260
```

Therefore, a freshly copied installation is not really a first run and will not perform the required bottom-left placement if those coordinates happen to be visible.

The best solution is not to commit the mutable runtime configuration at all:

* Add `config/NetworkMonitor.config.json` to `.gitignore`.
* Auto-create it on first run as the contract requires.
* Optionally commit `NetworkMonitor.config.example.json`.

At minimum, the distributed template must have:

```json
"X": null,
"Y": null,
"Maximized": false
```

On a shared network directory, a single mutable configuration also means different users or machines can overwrite one another’s window position and settings. The program therefore requires write permission to its application folder.

## Settings do not follow the requested commit behavior

The requirement was to commit settings on Enter or focus loss, not on every incremental change.

Several controls instead use `ValueChanged`, which fires continuously:

* Column width changes immediately save, rebuild the entire grid, and write the JSON file.
* Refresh, timeout, and history settings commit on every spinner increment.
* Health thresholds do the same.

This creates needless UI rebuilding and repeated writes, particularly undesirable when the application and configuration live on a network share.

These controls should commit on:

* `Validated`
* Enter key
* Spinner mouse-up, if desired

Column widths should be persisted after resizing ends or when the form closes, not on every `ColumnWidthChanged` event.

## Invalid configuration is partially salvaged despite the contract

The contract says a malformed or invalid configuration should be rejected as a whole, backed up, and regenerated.

Current loading first merges missing sections and fields from defaults, and only then validates the result. That silently repairs incomplete files instead of rejecting them.

The corrected flow should be:

1. Parse the JSON.
2. Convert it to the expected dictionary structure.
3. Validate the raw supplied structure without merging.
4. If anything required is absent or invalid, back up the whole file.
5. Create a complete default configuration.

Live settings should also be transactional:

1. Clone the current valid config.
2. Apply the proposed edit to the clone.
3. Validate it.
4. Save it.
5. Replace the active config only after successful validation and saving.

Currently, several handlers modify the live config before validation and saving, so a failed save can leave rejected values active in memory.

## What is worth retaining

A full rewrite is unnecessary. Several parts are directionally sound:

* Relative app-root discovery and modular file loading.
* PowerShell 7/STA launcher shims.
* Default target definitions and validation.
* Rolling history and health calculations.
* Concurrent `SendPingAsync()` calls.
* Skipping overlapping cycles.
* Disposal of each `Ping` instance.
* Custom-drawn title-bar icons that require no external assets.

The repair boundary should primarily be:

* Rewrite `Scripts/MainForm.ps1`.
* Simplify the drawing portions of `Scripts/UiHelpers.ps1`.
* Correct commit behavior in `Scripts/SettingsForm.ps1`.
* Make configuration validation and edits transactional in `Scripts/Config.ps1`.

`MonitorState.ps1`, most of `Validation.ps1`, and the underlying ping behavior can largely stay.

# Recommended repair design

The best implementation remains native PowerShell WinForms. There is no reason to introduce WPF, HTML, NuGet packages, downloaded fonts, images, modules, or web resources.

The corrected main view should use:

1. A borderless `Form` with the existing local resize subclass.
2. A compact docked title bar.
3. A normal dark-themed `DataGridView`.
4. Standard grid rendering for all ordinary text.
5. `CellFormatting` for target and health-dependent colors.
6. Custom painting only for Status and History.
7. Persistent rows updated in place.
8. Initial monitoring from `Shown`.
9. Delayed/debounced config persistence.
10. Explicit fatal-error reporting.

Everything needed is already local:

* `System.Windows.Forms`
* `System.Drawing`
* `System.Net.NetworkInformation.Ping`
* Built-in Segoe UI and Consolas fonts
* Locally drawn GDI+ icons

No internet connectivity or externally retrieved resource is necessary. The only network activity remains the configured ICMP requests to local addresses or hostnames.

## Repair order

1. Replace `Graphics.Clear()` and add paint-exception diagnostics.
2. Stop clearing and recreating rows after every ping.
3. Move initial monitoring into `Form.Shown`.
4. Rebuild the title bar and grid sizing using docked layouts.
5. Reduce typography and row/header heights to match the compact reference direction.
6. Remove the committed runtime position.
7. Correct settings commit and rollback behavior.
8. Enforce whole-file config rejection.
9. Test direct PS1, CMD, and VBS launches from the actual network location.
10. Test at 100% and 125% Windows display scaling with success, timeout, and mixed ping results.

**Overall assessment:** the monitoring core is salvageable, but the main UI should be treated as a failed presentation-layer implementation rather than patched cosmetically. The self-clearing `CellPainting` handler is the most probable direct cause of the black box and yellow stripes; the excessive custom painting, row recreation, impossible sizing, and silent error handling are why the result is also structurally far from the intended dashboard.

The GitHub connector exposed the PNG’s file metadata but not its raster bytes, so I could not perform a literal pixel-coordinate comparison against the image. The contract and Q&A do, however, encode the mockup’s authoritative layout and visual decisions closely enough to identify the implementation failures above.

[1]: https://learn.microsoft.com/en-us/dotnet/api/system.drawing.graphics.clear?view=windowsdesktop-9.0 "Graphics.Clear(Color) Method (System.Drawing) | Microsoft Learn"
