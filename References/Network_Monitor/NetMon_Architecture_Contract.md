# Network Monitor Architecture Contract

Generated: 2026-06-23

## Purpose

This document defines the target implementation structure for the Network Monitor remediation. It is intentionally stricter than a general design note. A fresh implementation session should treat this as the local architecture contract.

## Global Design Rules

1. Ordinary status text rendering must use native `DataGridView` text rendering.
2. Custom paint is allowed only for:
   - `Status` dot plus status text
   - `History` tick bars
3. Column text/color/font/paint mode must come from one presentation API.
4. Main and settings windows must use shared app-window/title-bar helpers.
5. Helper-created event handlers must explicitly capture local variables with `.GetNewClosure()` or store target objects in control `Tag`.
6. Config edits must be transactional.
7. Ping completion must return to the UI runspace before updating state or controls.
8. Keep functions compact and reusable. If logic is repeated, extract a helper.

## Module Load Order

`Network_Monitor.ps1` should dot-source modules in this order unless there is a concrete reason to change it:

1. `Scripts\Logging.ps1`
2. `Scripts\Validation.ps1`
3. `Scripts\Config.ps1`
4. `Scripts\MonitorState.ps1`
5. `Scripts\PingEngine.ps1`
6. `Scripts\UiHelpers.ps1`
7. `Scripts\Presentation.ps1`
8. `Scripts\SettingsForm.ps1`
9. `Scripts\MainForm.ps1`

`Presentation.ps1` must be loaded before `MainForm.ps1`.

## `UiHelpers.ps1`

### Required Responsibilities

- Theme colors and fonts.
- Point/size/rectangle helpers.
- Borderless resizable form subclass.
- Shared icon drawing.
- Shared icon button construction.
- Shared app-window construction.
- Shared title-bar construction.
- Safe drag behavior.
- Safe event registration patterns.

### Required Functions

#### `Initialize-NMTheme`

Creates:

- `$script:NMColors`
- `$script:NMFonts`

All colors and fonts used by main/settings UI should come from these tables.

#### `New-NMAppWindow`

Recommended signature:

```powershell
New-NMAppWindow `
    -Name <string> `
    -Title <string> `
    -Size <System.Drawing.Size> `
    -MinimumSize <System.Drawing.Size> `
    -ShowInTaskbar <bool> `
    -TopMost <bool> `
    -Resizable <bool>
```

Returns a configured form.

Must handle:

- dark background
- borderless form style
- taskbar behavior
- resize behavior where appropriate
- common border painting

#### `New-NMTitleBar`

Recommended signature:

```powershell
New-NMTitleBar `
    -Form <System.Windows.Forms.Form> `
    -Title <string> `
    -Buttons <array> `
    -CanMaximize <bool>
```

Button definitions should include:

- `Kind`
- `ToolTip`
- `OnClick`
- optional `Active`

The helper must use the same visual styling for main and settings windows.

#### `Enable-NMWindowDrag`

Recommended signature:

```powershell
Enable-NMWindowDrag -Control <Control> -Form <Form> [-EnableDoubleClickMaximize]
```

Rules:

- Capture the target form into a local variable.
- Register event handlers using `.GetNewClosure()`.
- Never rely on a delayed event handler resolving `$Form` from outer scope.

Correct pattern:

```powershell
$targetForm = $Form
$Control.Add_MouseDown({
    param($sender, $eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        [NetworkMonitorNative]::ReleaseCapture() | Out-Null
        [NetworkMonitorNative]::SendMessage($targetForm.Handle, 0xA1, 0x2, 0) | Out-Null
    }
}.GetNewClosure())
```

#### `New-NMIconButton`

Must:

- Create an icon button with hover/pressed/active state.
- Use custom-drawn icons.
- Use `.GetNewClosure()` for callback handlers if local callback variables are referenced.
- Not depend on font glyph icons.

## `Presentation.ps1`

### Required Responsibilities

Own all grid display decisions:

- column text
- foreground color
- font
- custom paint mode
- history sample color

No other file should decide RTT/Loss/TTL/Bytes/Status display colors.

### Required Functions

#### `New-NMColumnPresentation`

Recommended signature:

```powershell
New-NMColumnPresentation `
    [-Text <string>] `
    [-ForeColor <System.Drawing.Color>] `
    [-Font <System.Drawing.Font>] `
    [-PaintKind <string>] `
    [-Align <DataGridViewContentAlignment>]
```

Returns an object with:

- `Text`
- `ForeColor`
- `Font`
- `PaintKind`
- `Align`

Allowed `PaintKind` values:

- `Text`
- `Status`
- `History`

#### `Get-NMColumnPresentation`

Recommended signature:

```powershell
Get-NMColumnPresentation `
    -State <hashtable> `
    -Target <object> `
    -ColumnId <string>
```

Must handle every supported column:

- `Node`
- `Address`
- `Status`
- `RTT`
- `Loss`
- `History`
- `TTL`
- `Bytes`

Expected behavior:

- `Node`: target color, bold font.
- `Address`: normal text.
- `Status`: status text, health color, bold font, `PaintKind = Status`.
- `RTT`: `NA`, `timeout`, or `<n> ms`; RTT health color.
- `Loss`: rolling loss text; loss health color.
- `History`: no text; `PaintKind = History`.
- `TTL`: latest success value or `--`; neutral muted color when unavailable.
- `Bytes`: latest success value or `--`; neutral muted color when unavailable.

#### `Get-NMHistorySampleColor`

Recommended signature:

```powershell
Get-NMHistorySampleColor -Sample <nullable bool>
```

Expected behavior:

- `$null`: yellow
- `$true`: green
- `$false`: red

## `MainForm.ps1`

### Required Responsibilities

- Build main form using shared window/title helpers.
- Build grid.
- Create persistent rows.
- Update cell values in place.
- Call presentation API for every displayed column.
- Start monitoring from form `Shown`.

### Grid Rules

- Rows are created once and mapped by target name.
- Do not clear/recreate all rows every ping cycle.
- Rebuild rows only when target set/order/enabled state changes.
- Rebuild columns only when column config changes.
- Use native rendering for ordinary text.
- Set both:
  - `CellStyle.ForeColor`
  - `CellStyle.SelectionForeColor`
  from presentation color.
- Avoid full-row selection unless explicitly required later.
- Custom painting must never call `Graphics.Clear()`.

## `SettingsForm.ps1`

### Required Responsibilities

- Build settings form using shared window/title helpers.
- Reuse themed label/numeric/text/button helpers.
- Use transactional config edits.
- Provide inline feedback.

### Commit Rules

- Text and numeric controls commit on Enter or focus leave.
- Checkboxes commit on click.
- Invalid edits restore the previous valid value.
- No live config mutation before validation/saving a clone.

### Required Tabs

- `Targets`
- `Columns`
- `Timing`
- `Health`
- `General`

The Health tab must use explicit visible labels and aligned numeric fields.

## `PingEngine.ps1`

### Required Responsibilities

- Concurrent `SendPingAsync()` pings.
- One ping per enabled target per cycle.
- Skip ticks while a cycle is busy.
- Every attempted ping produces one result.
- Skipped ticks produce no result.
- Dispose every `Ping` object.
- Update state/UI only from the UI runspace.

### Forbidden Pattern

Do not use a `BackgroundWorker` completion event that calls PowerShell script functions from a worker thread without explicitly providing a runspace. That caused ping results to disappear.

Acceptable patterns:

- Start async ping tasks and poll completion from a WinForms timer on the UI thread.
- Use a properly marshaled runspace design if implemented carefully.

Prefer the WinForms timer polling model for compactness.

## `Config.ps1`

### Required Responsibilities

- Generate default config.
- Strictly validate existing config as supplied.
- Reject invalid or incomplete config as a whole.
- Back up invalid config.
- Save atomically.
- Provide transactional edit helper.

### Required Transaction Helper

```powershell
Invoke-NMConfigEdit -Edit { param($config) ... }
```

Must:

1. Deep-clone current config.
2. Apply edit to clone.
3. Validate clone.
4. Save clone atomically.
5. Replace live config only after successful save.

## Event Handler Rule

Every `.Add_*` registration must be reviewed.

If the scriptblock references any of these, it must use `.GetNewClosure()` or equivalent stable storage:

- helper parameters
- local variables
- callback scriptblocks
- target forms
- target controls
- current target/column/row variables

Safe examples:

- handler references only `$sender`, `$eventArgs`, and durable `$script:` state
- handler calls a no-argument global function

Unsafe examples:

- handler references `$Form`
- handler references `$OnClick`
- handler references `$target`
- handler references `$column`
- handler references `$tabs`

## Completion Criteria

The architecture remediation is complete only when:

- all helper-created event handlers are capture-safe
- main/settings windows share window/title helpers
- all column display behavior is in `Presentation.ps1`
- ping completion is runspace-safe
- settings edits are transactional
- nonvisual test harness passes
- manual interaction checklist passes
