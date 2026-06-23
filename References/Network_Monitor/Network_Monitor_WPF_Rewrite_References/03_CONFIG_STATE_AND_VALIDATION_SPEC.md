# Config, State, And Validation Spec

Generated: 2026-06-23

## Purpose

This document defines the persisted configuration, runtime state, validation rules, and presentation calculations that the WPF rewrite must preserve.

The current WinForms app already has a clean enough config/state boundary. Reuse the semantics even if the WPF implementation changes class/function names.

## Config Path

Current path:

`Scripts\Network_Monitor\config\NetworkMonitor.config.json`

Resolved WPF path:

`Scripts\Network_Monitor_WPF\config\NetworkMonitor.config.json`

Path rule:

- Resolve config path relative to the WPF app root.
- Do not use absolute developer-machine paths.
- Do not depend on the current working directory except as a last fallback during script-root discovery.

## Full Default Config

The WPF rewrite must generate this logical default config on first run:

```json
{
  "Targets": [
    {
      "Name": "SMS",
      "Address": "192.168.51.20",
      "Color": "#ff40e6",
      "Enabled": true
    },
    {
      "Name": "MPS",
      "Address": "192.168.101.20",
      "Color": "#ff40e6",
      "Enabled": true
    },
    {
      "Name": "MPG",
      "Address": "192.168.200.100",
      "Color": "#27d9e6",
      "Enabled": true
    }
  ],
  "RefreshMilliseconds": 1000,
  "PingTimeoutMilliseconds": 1000,
  "HistoryLength": 12,
  "AlwaysOnTop": false,
  "AutoStart": true,
  "DebugMode": false,
  "Window": {
    "Width": 1040,
    "Height": 270,
    "X": null,
    "Y": null,
    "Maximized": false
  },
  "Columns": [
    {
      "Id": "Node",
      "Visible": true,
      "Width": 120
    },
    {
      "Id": "Address",
      "Visible": true,
      "Width": 250
    },
    {
      "Id": "Status",
      "Visible": true,
      "Width": 150
    },
    {
      "Id": "RTT",
      "Visible": true,
      "Width": 130
    },
    {
      "Id": "Loss",
      "Visible": true,
      "Width": 130
    },
    {
      "Id": "History",
      "Visible": true,
      "Width": 260
    },
    {
      "Id": "TTL",
      "Visible": false,
      "Width": 90
    },
    {
      "Id": "Bytes",
      "Visible": false,
      "Width": 95
    }
  ],
  "Health": {
    "DownFailures": 3,
    "OrangeFailures": 2,
    "OrangeLossPercent": 25
  },
  "RttThresholds": {
    "GreenMax": 50,
    "YellowMax": 100,
    "OrangeMax": 250
  },
  "LossThresholds": {
    "YellowMax": 10,
    "OrangeMax": 25
  }
}
```

## Schema Version

Resolved requirement:

- No schema/version field.
- Do not add a schema/version field in the WPF rewrite.

## Column Definitions

Supported column ids and defaults:

| Id | Header | Default Visible | Default Width | Min Width |
|---|---|---:|---:|---:|
| `Node` | `Node` | `true` | `120` | `100` |
| `Address` | `Address` | `true` | `250` | `190` |
| `Status` | `Status` | `true` | `150` | `130` |
| `RTT` | `RTT` | `true` | `130` | `105` |
| `Loss` | `Loss` | `true` | `130` | `105` |
| `History` | `History` | `true` | `260` | `180` |
| `TTL` | `TTL` | `false` | `90` | `70` |
| `Bytes` | `Bytes` | `false` | `95` | `80` |

Rules:

- Config must include exactly one entry for every supported column.
- Unsupported column ids are invalid.
- Duplicate column ids are invalid.
- At least one column must be visible.
- Width must be between the column min width and `2000`.
- `Columns` array order is the display order.

## Target Validation

Rules:

- `Targets` must exist and contain at least one target.
- Every target must be an object/map.
- `Name` must be nonblank.
- Names must be unique case-insensitively.
- `Address` must be valid IPv4 or valid hostname.
- `Color` must match `^#[0-9A-Fa-f]{6}$`.
- `Enabled` must be boolean.
- At least one target must be enabled.

IPv4:

- Must parse as an IP address.
- Address family must be IPv4.

Hostname:

- Must be nonblank.
- Max length `253`.
- Optional trailing dot is allowed for validation after trimming it.
- Each label length must be `1` to `63`.
- Each label must match:

```text
^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$
```

## Numeric Validation

Timing:

| Config Key | Minimum | Maximum | Default |
|---|---:|---:|---:|
| `RefreshMilliseconds` | `250` | `60000` | `1000` |
| `PingTimeoutMilliseconds` | `100` | `60000` | `1000` |
| `HistoryLength` | `4` | `60` | `12` |

Booleans:

- `AlwaysOnTop`
- `AutoStart`
- `DebugMode`

Each must be a boolean.

Window:

| Config Key | Rule |
|---|---|
| `Window.Width` | integer between `760` and `10000` |
| `Window.Height` | integer between `220` and `6000` |
| `Window.X` | `null` or integer |
| `Window.Y` | `null` or integer |
| `Window.Maximized` | boolean |

Health:

| Config Key | Minimum | Maximum | Default |
|---|---:|---:|---:|
| `Health.DownFailures` | `1` | `20` | `3` |
| `Health.OrangeFailures` | `1` | `20` | `2` |
| `Health.OrangeLossPercent` | `0` | `100` | `25` |

RTT thresholds:

| Config Key | Minimum | Maximum | Default |
|---|---:|---:|---:|
| `RttThresholds.GreenMax` | `0` | `60000` | `50` |
| `RttThresholds.YellowMax` | `1` | `60000` | `100` |
| `RttThresholds.OrangeMax` | `1` | `60000` | `250` |

RTT ordering rule:

```text
GreenMax < YellowMax < OrangeMax
```

Loss thresholds:

| Config Key | Minimum | Maximum | Default |
|---|---:|---:|---:|
| `LossThresholds.YellowMax` | `0` | `100` | `10` |
| `LossThresholds.OrangeMax` | `0` | `100` | `25` |

Loss ordering rule:

```text
YellowMax <= OrangeMax
```

## Config Load Rules

Current behavior to preserve:

1. Ensure config directory exists.
2. If config file is missing:
   - Generate defaults.
   - Save defaults atomically.
   - Use defaults.
3. If config file exists:
   - Read raw JSON.
   - Convert JSON objects to ordered dictionaries/maps.
   - Validate supplied structure as-is.
   - Do not merge defaults into an incomplete file before validation.
   - If valid, use it.
   - If invalid or malformed, back up whole file and generate defaults.

Invalid config backup name:

```text
NetworkMonitor.config.invalid-YYYYMMDD-HHMMSS.json
```

## Config Save Rules

Atomic save behavior:

1. Validate candidate config.
2. Ensure config directory exists.
3. Serialize JSON with enough depth for nested objects.
4. Write to a unique temp file in the same config directory.
5. If the real config exists, replace it using filesystem replace semantics when possible.
6. If the real config does not exist, move temp file into place.
7. Remove temporary replace backup after successful replace.
8. Clean temp file on failure.

JSON encoding:

- UTF-8 without BOM is preferred.

## Transactional Edit Rules

Every live settings edit must use this logical flow:

1. Deep clone current config.
2. Apply proposed edit to the clone.
3. Validate the clone.
4. Save the clone atomically.
5. Replace live config only after save succeeds.
6. If validation/save fails:
   - Leave live config unchanged.
   - Restore UI control to previous valid value.
   - Show inline error feedback.

Do not mutate the live config before validation.

## Runtime Target State

Each target has a runtime state object with these fields:

| Field | Type | Meaning |
|---|---|---|
| `Name` | string or map key | Target name associated with state |
| `HasSample` | bool | Whether any attempted ping sample exists |
| `LatestSuccess` | bool | Whether latest attempted ping succeeded |
| `LatestRttMs` | nullable int | Latest successful round-trip time |
| `LatestBytes` | nullable int | Latest successful reply buffer length |
| `LatestTtl` | nullable int | Latest successful reply TTL |
| `ConsecutiveFailures` | int | Current failed-attempt streak |
| `LossPercent` | double | Rolling loss over current history |
| `History` | list of bool | Rolling success/failure attempted samples |

State initialization:

- Create state for all configured targets.
- Enabled targets display in the grid.
- Disabled targets may still have state initialized, but are hidden.

State reset:

- Reinitialize all target states.
- Clear all histories and latest values.
- Reset consecutive failures and loss.

State update from ping results:

For each result:

- Ignore unknown target names.
- Set `HasSample = true`.
- Set `LatestSuccess` to result success.
- On success:
  - Set `LatestRttMs`.
  - Set `LatestBytes` if available.
  - Set `LatestTtl` if available.
  - Reset `ConsecutiveFailures` to `0`.
- On failure:
  - Set latest RTT/bytes/TTL to null.
  - Increment `ConsecutiveFailures`.
- Append success boolean to `History`.
- Trim history to `HistoryLength`.
- Recalculate `LossPercent` as failed samples divided by sample count, rounded to one decimal.

Empty result set:

- Must not mutate state. This represents skipped/no-op handling in tests.

## Ping Result Shape

Each attempted target ping should produce a result equivalent to:

```powershell
[pscustomobject]@{
    Name = 'SMS'
    Address = '192.168.51.20'
    Success = $true
    RttMs = 3
    Bytes = 32
    Ttl = 64
}
```

On failure:

```powershell
[pscustomobject]@{
    Name = 'SMS'
    Address = '192.168.51.20'
    Success = $false
    RttMs = $null
    Bytes = $null
    Ttl = $null
}
```

## Presentation Rules

Centralized presentation object should include:

- `Text`
- `Foreground`
- `FontWeight` or equivalent
- `TemplateKind` or equivalent (`Text`, `Status`, `History`)
- `Alignment`

Column presentation:

| Column | Text | Foreground | Template |
|---|---|---|---|
| `Node` | target name | target color | text, bold |
| `Address` | target address | primary text | text |
| `Status` | `UP` or `DOWN` | health color | status dot plus text |
| `RTT` | `NA`, `timeout`, or `<n> ms` | RTT health color | text |
| `Loss` | `<n.N>%` | loss health color | text |
| `History` | empty | not applicable | history bars |
| `TTL` | reply TTL or `--` | primary or muted | text |
| `Bytes` | reply bytes or `--` | primary or muted | text |

Status text:

```text
DOWN if ConsecutiveFailures >= Health.DownFailures
UP otherwise
```

Health color:

```text
Red if ConsecutiveFailures >= Health.DownFailures
Orange if LossPercent >= Health.OrangeLossPercent
Orange if ConsecutiveFailures >= Health.OrangeFailures
Yellow if HasSample and not LatestSuccess
Yellow if LossPercent > 0
Green otherwise
```

RTT text:

```text
NA if no sample
timeout if latest sample failed
<LatestRttMs> ms if latest sample succeeded
```

RTT health color:

```text
Red if no sample, latest failed, or LatestRttMs is null
Green if RTT <= GreenMax
Yellow if RTT <= YellowMax
Orange if RTT <= OrangeMax
Red otherwise
```

Loss text:

```text
{LossPercent:N1}%
```

Loss health color:

```text
Green if loss <= 0
Yellow if loss <= LossThresholds.YellowMax
Orange if loss <= LossThresholds.OrangeMax
Red otherwise
```

TTL/Bytes:

```text
value as string if latest ping succeeded and value is available
-- otherwise
```

TTL/Bytes color:

```text
primary text if available from latest success
muted otherwise
```

History display:

- Build a display list of length `HistoryLength`.
- Prepend `null` entries for missing/unfilled samples.
- Append current rolling history samples.
- Map colors:
  - `null` -> yellow
  - `true` -> green
  - `false` -> red

## Config Changes And Runtime Effects

These changes reset all monitor state/history:

- Add target.
- Delete target.
- Rename target.
- Edit address.
- Edit color.
- Enable/disable target.
- Reorder targets.
- Refresh interval.
- Ping timeout.
- History length.
- Health thresholds.
- RTT thresholds.
- Loss thresholds.
- Reset to defaults.

Current WinForms behavior rebuilds the grid for:

- Any target settings change, including add, delete, rename, address, color, enable/disable, and reorder.
- Column order change.
- Column visibility change.
- Column width change through settings.
- Reset to defaults.

WPF rewrite implementation note:

- The WPF rewrite may improve target address/color handling by updating bound row properties in place instead of rebuilding row objects.
- It must still reset monitor state/history for address/color changes and update visible address/node color presentation immediately.
- It must rebuild row identity/order for target add, delete, rename, enable/disable, and reorder.

These changes apply without monitor reset:

- Always on top toggle.
- Debug mode toggle.
- Auto-start toggle, except enabling auto-start may start monitoring if stopped.
- Window position reset.
- Window move/resize persistence.
- Main-grid column width/reorder persistence from direct user resizing/reordering.

## Window Placement State

Saved window fields:

- `Width`
- `Height`
- `X`
- `Y`
- `Maximized`

On first run:

- `X` and `Y` are null.
- Calculate default size.
- Place window at bottom-left of primary screen working area.

Default location formula:

```text
X = PrimaryScreen.WorkingArea.Left
Y = PrimaryScreen.WorkingArea.Bottom - Window.Height
```

Saved-position validation:

- Build rectangle from saved X/Y/Width/Height.
- If it intersects any screen working area, use it.
- Otherwise fallback to bottom-left.

On close:

- If normal, persist current bounds.
- If maximized, persist restore bounds and `Maximized = true`.

WPF equivalent:

- Use `System.Windows.SystemParameters.WorkArea` or `System.Windows.Forms.Screen` for multi-monitor compatibility.
- Save `RestoreBounds` equivalent when maximized.

## Logging Rules

Debug log:

- Only write normal diagnostic log messages when `DebugMode = true`.
- Path: `logs\NetworkMonitor-YYYYMMDD.log`.
- Timestamp format equivalent to `yyyy-MM-dd HH:mm:ss.fff`.

Startup error log:

- Can be written even when `DebugMode = false`.
- Path: `logs\NetworkMonitor.startup-error.log`.
- Used for fatal startup/runtime exceptions that would otherwise be hidden by the VBS launcher.
