# Remote Access Client Refactor Plan

Date: 2026-06-12

## Goal

Refactor the current separate RMUP telnet console and Spectracom GPS serial auth tools into one left-nav tool named `Remote Access`.

The new tool should behave like a small PuTTY-style remote access client without trying to become a full terminal emulator. It should support:

- selectable protocol: `Telnet` or `Serial`
- protocol-specific settings shown only when relevant
- a generic Telnet client
- a generic Serial client
- preset buttons on the right side of the Remote Access UI:
  - `RMUP Log`
  - `GPS Auth`
- RMUP Log as a Telnet preset
- GPS Auth as a Serial preset plus its existing authentication automation

## Current Repo Context

Important files:

- `ToolLauncher.ps1`
  - Windows Forms launcher.
  - Loads tool definitions from `Tools\tools.json`.
  - Renders fields generically from each tool's `fields` array.
  - Starts tools via `Start-ConfiguredTool`.
  - Shows log output and optional console input.
- `Tools\tools.json`
  - Currently contains separate tools:
    - `spectracom-gps-auth`
    - `rmup-console`
- `Scripts\ToolRuntime.ps1`
  - Loads tool definitions.
  - Builds PowerShell worker commands.
  - Starts/stops worker processes.
  - Handles interactive input JSONL files.
- `Scripts\ToolCommon.ps1`
  - Shared filesystem/log helpers.
- `Scripts\RmupConsole.ps1`
  - Current native telnet/RMUP implementation.
  - Contains telnet option negotiation, TCP connect, log output, and input polling.
- `Scripts\SpectracomGpsAuth.ps1`
  - Current serial auth implementation.
  - Opens serial port, wakes prompt, detects authenticated prompt, sends credentials only when needed.

The `archive/` folder is a local backup and should be ignored. Do not use it as source material unless explicitly requested.

## Target File Shape

Recommended final shape:

```text
Tools/
  tools.json
  remote-access.presets.json

Scripts/
  RemoteAccess.ps1
  RemoteAccess.Telnet.ps1
  RemoteAccess.Serial.ps1
  RemoteAccess.Actions.SpectracomGpsAuth.ps1
  ToolCommon.ps1
  ToolRuntime.ps1
```

Optional compatibility wrappers may remain:

```text
Scripts/
  RmupConsole.ps1
  SpectracomGpsAuth.ps1
```

If wrappers are kept, make them tiny delegates to `RemoteAccess.ps1`. They should not contain duplicated protocol logic.

## Catalog Design

Replace the two left-nav tool entries in `Tools\tools.json` with one entry:

```json
{
  "id": "remote-access",
  "name": "Remote Access",
  "description": "Connects to remote equipment over Telnet or Serial, with presets for RMUP Log and GPS Auth.",
  "script": "Scripts/RemoteAccess.ps1",
  "interactiveInput": true,
  "presetsPath": "Tools/remote-access.presets.json",
  "fields": []
}
```

Recommended fields:

- hidden preset/action state:
  - `PresetId`
  - `Action`
- shared:
  - `Protocol`, choice: `Telnet`, `Serial`
  - `PollMilliseconds`
  - `ReceiveBufferBytes`
- Telnet-only:
  - `TargetHost`
  - `TcpPort`
  - `ConnectTimeoutMilliseconds`
- Serial-only:
  - `ComPort`
  - `BaudRate`
  - `Parity`
  - `DataBits`
  - `StopBits`
- GPS Auth action fields:
  - `Username`
  - `Password`
  - `WakePrompt`
  - `OpenDelayMilliseconds`
  - `PromptDelayMilliseconds`

Use field metadata for conditional display. Suggested shape:

```json
{
  "name": "TargetHost",
  "label": "Target Host / IP",
  "default": "",
  "visibleWhen": {
    "Protocol": "Telnet"
  }
}
```

For GPS Auth-only credential fields:

```json
{
  "name": "Username",
  "label": "Username",
  "default": "",
  "visibleWhen": {
    "Protocol": "Serial",
    "Action": "SpectracomGpsAuth"
  }
}
```

Use `type: "hidden"` for `PresetId` and `Action`, and update the launcher so hidden fields are passed to the worker but not rendered.

## Preset Design

Create `Tools\remote-access.presets.json`.

Recommended structure:

```json
{
  "presets": [
    {
      "id": "rmup-log",
      "label": "RMUP Log",
      "description": "RMUP telnet console at 192.168.200.100:23.",
      "protocol": "Telnet",
      "action": "",
      "values": {
        "PresetId": "rmup-log",
        "Action": "",
        "Protocol": "Telnet",
        "TargetHost": "192.168.200.100",
        "TcpPort": 23,
        "ConnectTimeoutMilliseconds": 10000,
        "PollMilliseconds": 75,
        "ReceiveBufferBytes": 4096
      }
    },
    {
      "id": "gps-auth",
      "label": "GPS Auth",
      "description": "Authenticate Spectracom SecureSync over serial.",
      "protocol": "Serial",
      "action": "SpectracomGpsAuth",
      "values": {
        "PresetId": "gps-auth",
        "Action": "SpectracomGpsAuth",
        "Protocol": "Serial",
        "ComPort": "COM1",
        "BaudRate": 9600,
        "Parity": "None",
        "DataBits": 8,
        "StopBits": "One",
        "Username": "spadmin",
        "Password": "admin123",
        "WakePrompt": true,
        "OpenDelayMilliseconds": 100,
        "PromptDelayMilliseconds": 300,
        "PollMilliseconds": 75,
        "ReceiveBufferBytes": 4096
      }
    }
  ]
}
```

Important behavior:

- Choosing `Protocol: Telnet` manually should show a blank/generic Telnet client, not silently apply the RMUP preset.
- Choosing `Protocol: Serial` manually should show a blank/generic Serial client, not silently apply the GPS Auth preset.
- Clicking `RMUP Log` should switch to Telnet and populate RMUP values.
- Clicking `GPS Auth` should switch to Serial, populate serial/auth values, and set `Action` to `SpectracomGpsAuth`.
- If the user manually changes protocol after applying a preset, clear `PresetId` and `Action` unless the current preset still applies.

## Launcher Changes

Modify `ToolLauncher.ps1` conservatively.

### Add Conditional Field Rendering

Add support for:

- `type: "hidden"` fields
- `visibleWhen` field metadata

The current field renderer builds controls in `Show-FieldControl`. Recommended approach:

1. Add a function like `Test-FieldVisible`.
2. Add a function like `Get-CurrentFieldValueOrDefault`.
3. In `Show-Tool`, render only non-hidden fields whose `visibleWhen` conditions match.
4. Keep hidden fields in state so they are still passed to the worker.
5. Attach a `SelectedIndexChanged` handler to the `Protocol` combo box.
6. When `Protocol` changes:
   - save current visible field state
   - clear preset/action state for manual protocol changes
   - re-render the current tool

Do not lose existing typed values when the user flips between Telnet and Serial. The existing `$script:toolValues` map can support this if values are saved before re-rendering.

### Add Preset Buttons

Add support for `presetsPath` on a tool definition.

Recommended launcher behavior:

1. Load presets for the current tool when `Show-Tool` runs.
2. Render preset buttons on the right side of the Remote Access content area.
3. Buttons should be visible only for tools that declare `presetsPath`.
4. Clicking a preset should:
   - save current field state
   - write all preset values into `$script:toolValues`
   - set `Protocol`, `PresetId`, and `Action`
   - re-render the tool so the right protocol-specific fields are shown
   - update status text to something like `Applied preset GPS Auth.`

Keep the UI simple. A small `Presets` label plus `RMUP Log` and `GPS Auth` buttons is enough.

### Keep Existing Run/Input Behavior

`Remote Access` should set `interactiveInput: true`.

The input row can remain visible for Remote Access even when GPS Auth is selected. The worker action may exit quickly after authentication, which will naturally disable input when the process finishes.

## Runtime Changes

`Scripts\ToolRuntime.ps1` likely needs only small changes:

- validate optional `presetsPath` if present
- make sure hidden fields are included in command generation
- make sure missing field values fall back to defaults

`New-PowerShellWorkerCommand` can continue passing fields as script parameters.

Make sure password fields are not logged by runtime. The existing command construction passes values to the worker process; do not print command lines containing credentials.

## RemoteAccess.ps1 Design

Create `Scripts\RemoteAccess.ps1`.

Recommended params:

```powershell
param(
    [ValidateSet('Telnet', 'Serial')]
    [string]$Protocol = 'Telnet',

    [string]$PresetId = '',
    [string]$Action = '',

    [string]$TargetHost = '',
    [ValidateRange(1, 65535)]
    [int]$TcpPort = 23,
    [ValidateRange(100, 60000)]
    [int]$ConnectTimeoutMilliseconds = 10000,

    [string]$ComPort = '',
    [ValidateRange(300, 921600)]
    [int]$BaudRate = 9600,
    [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')]
    [string]$Parity = 'None',
    [ValidateRange(5, 8)]
    [int]$DataBits = 8,
    [ValidateSet('One', 'Two', 'OnePointFive')]
    [string]$StopBits = 'One',

    [string]$Username = '',
    [string]$Password = '',
    [bool]$WakePrompt = $true,
    [ValidateRange(0, 10000)]
    [int]$OpenDelayMilliseconds = 100,
    [ValidateRange(0, 10000)]
    [int]$PromptDelayMilliseconds = 300,

    [ValidateRange(10, 5000)]
    [int]$PollMilliseconds = 75,
    [ValidateRange(128, 65536)]
    [int]$ReceiveBufferBytes = 4096,

    [string]$InputPath = '',
    [string]$LogPath = (Join-Path $PSScriptRoot '..\Logs\RemoteAccess.log')
)
```

Dispatch behavior:

- `Protocol = Telnet`
  - require `TargetHost`
  - call telnet session function
- `Protocol = Serial` and `Action = SpectracomGpsAuth`
  - require `ComPort`, `Username`
  - call GPS auth action
- `Protocol = Serial` and no action
  - require `ComPort`
  - call generic serial session function
- any unknown action should fail with a clear error

Logging:

- use `New-SharedLogWriter`
- write startup config without printing passwords
- use prefixes such as `[RemoteAccess]`, `[Telnet]`, `[Serial]`, `[GPS Auth]`
- preserve raw received remote output in the log and launcher output

## Telnet Module

Create `Scripts\RemoteAccess.Telnet.ps1`.

Extract and adapt from `Scripts\RmupConsole.ps1`:

- TCP connect with timeout
- telnet IAC negotiation
- receive loop
- `InputPath` JSONL polling
- line sending over telnet
- clean close detection

Recommended public function:

```powershell
function Start-RemoteTelnetSession {
    param(
        [string]$TargetHost,
        [int]$TcpPort,
        [int]$ConnectTimeoutMilliseconds,
        [int]$PollMilliseconds,
        [int]$ReceiveBufferBytes,
        [string]$InputPath,
        [scriptblock]$WriteStatus,
        [scriptblock]$WriteReceived
    )
}
```

Avoid leaving all state in global `$script:` variables if practical. A session-local state hashtable is cleaner:

```powershell
$telnetState = @{
    State = 'Data'
    Command = 0
    SubnegotiationIac = $false
    InputLineIndex = 0
    Encoding = [System.Text.Encoding]::ASCII
}
```

## Serial Module

Create `Scripts\RemoteAccess.Serial.ps1`.

Provide a generic serial terminal loop.

Recommended public function:

```powershell
function Start-RemoteSerialSession {
    param(
        [string]$ComPort,
        [int]$BaudRate,
        [string]$Parity,
        [int]$DataBits,
        [string]$StopBits,
        [int]$PollMilliseconds,
        [string]$InputPath,
        [scriptblock]$WriteStatus,
        [scriptblock]$WriteReceived
    )
}
```

Behavior:

- open `System.IO.Ports.SerialPort`
- log open/close
- poll `ReadExisting()`
- send queued input lines with `WriteLine`
- keep running until stopped from launcher or serial failure occurs
- close and dispose the port in `finally`

Share input JSONL polling logic with the telnet module if the duplication becomes meaningful. Keep the helper small.

## GPS Auth Action

Create `Scripts\RemoteAccess.Actions.SpectracomGpsAuth.ps1`.

Move the unique logic from `Scripts\SpectracomGpsAuth.ps1` into a function:

```powershell
function Invoke-SpectracomGpsAuth {
    param(
        [string]$ComPort,
        [int]$BaudRate,
        [string]$Parity,
        [int]$DataBits,
        [string]$StopBits,
        [string]$Username,
        [string]$Password,
        [bool]$WakePrompt,
        [int]$OpenDelayMilliseconds,
        [int]$PromptDelayMilliseconds,
        [scriptblock]$WriteStatus,
        [scriptblock]$WriteReceived
    )
}
```

Preserve current behavior:

- open serial port
- optionally send wake prompt
- read prompt
- if prompt matches authenticated SecureSync prompt, print `Authentication Valid`
- otherwise send username and password
- never print password
- close serial port

The existing prompt check is:

```powershell
$promptText -match '@SecureSync.*\$'
```

Keep it unless hardware testing proves it needs adjustment.

## Old Script Handling

After Remote Access is working, either:

1. remove old tool entries from `Tools\tools.json` and leave old scripts unused, or
2. convert old scripts into tiny compatibility wrappers.

Preferred wrapper behavior:

- `Scripts\RmupConsole.ps1` calls `Scripts\RemoteAccess.ps1 -Protocol Telnet ...`
- `Scripts\SpectracomGpsAuth.ps1` calls `Scripts\RemoteAccess.ps1 -Protocol Serial -Action SpectracomGpsAuth ...`

Do not keep duplicated transport implementations in the old scripts.

## README Update

Update `README.md` to describe:

- one `Remote Access` tool
- Telnet/Serial protocol selection
- RMUP Log and GPS Auth presets
- logs still written under `Logs`

Remove or adjust references that say RMUP Console and Spectracom GPS Auth are separate launcher tools.

## Verification

Run these checks before finishing:

```powershell
git status --short
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$files = Get-ChildItem -Path . -Filter *.ps1 -Recurse | Where-Object { $_.FullName -notmatch '\\archive\\' }; foreach ($file in $files) { $tokens = $null; $errors = $null; [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null; if ($errors) { Write-Error ($file.FullName + ': ' + ($errors | Out-String)); exit 1 } }; 'PowerShell parse OK'"
```

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ". .\Scripts\ToolRuntime.ps1; Get-ToolDefinitions -CatalogPath .\Tools\tools.json | Format-Table id,name,script"
```

Manual GUI smoke test:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\ToolLauncher.ps1
```

Verify in the GUI:

- left nav shows `Remote Access`
- `Protocol:` dropdown has `Telnet` and `Serial`
- selecting Telnet shows Telnet fields
- selecting Serial shows Serial fields
- `RMUP Log` button applies Telnet values
- `GPS Auth` button applies Serial/Auth values
- `Run` starts a worker and writes a log
- `Stop` stops long-running Telnet/Serial sessions
- input row sends lines to long-running sessions
- password field is masked
- logs do not print the password

Hardware-dependent verification:

- RMUP telnet connection works against `192.168.200.100:23`
- GPS Auth still reports `Authentication Valid` when already authenticated
- GPS Auth sends credentials only when needed

If hardware is unavailable, say that explicitly in the final response.

## Acceptance Criteria

- Only one left-nav entry exists for remote access: `Remote Access`.
- UI includes a `Protocol:` dropdown with `Telnet` and `Serial`.
- Telnet fields and Serial fields are conditionally displayed.
- `RMUP Log` preset button fills Telnet values for RMUP.
- `GPS Auth` preset button fills Serial values and enables the GPS auth action.
- RMUP telnet logic still supports telnet option negotiation and console input.
- Generic serial mode supports serial output and line input.
- GPS Auth preserves existing authentication behavior.
- Duplicated telnet/serial logic is removed from the old separate tool scripts, or old scripts are only wrappers.
- `README.md` matches the new tool model.
- PowerShell parse checks pass.
- Tool catalog loads successfully.
- No changes are made inside `archive/`.

## Suggested Implementation Order

1. Inspect current `git status` and read the files listed in this plan.
2. Update `Tools\tools.json` and add `Tools\remote-access.presets.json`.
3. Add launcher support for hidden fields, conditional fields, and preset buttons.
4. Add `Scripts\RemoteAccess.ps1`.
5. Extract Telnet implementation into `Scripts\RemoteAccess.Telnet.ps1`.
6. Add generic Serial implementation in `Scripts\RemoteAccess.Serial.ps1`.
7. Move GPS Auth automation into `Scripts\RemoteAccess.Actions.SpectracomGpsAuth.ps1`.
8. Convert or retire old `RmupConsole.ps1` and `SpectracomGpsAuth.ps1`.
9. Update `README.md`.
10. Run verification.
11. Commit the completed refactor.
