# Troubleshooter Tool Launcher Proof of Concept

This is a no-install Windows 11 proof of concept that uses only built-in Windows PowerShell and .NET Windows Forms.

## Run it

Double-click `Run_Tool_Launcher.cmd`, or run this from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\ToolLauncher.ps1
```

## What it does

- `ToolLauncher.ps1` opens a dark utility-style GUI with a left-side tool list and a right-side tool workspace.
- `Tools\tools.json` controls which tools appear, their order, their fields, and which script/mode they run.
- `Scripts\ToolRuntime.ps1` contains the non-UI logic for catalog loading, process start/stop, and log reads.
- `Scripts\ExampleWorker.ps1` simulates a long-running tool.
- Each run writes a timestamped log under `Logs`.
- The GUI tails the active log so you can verify that launch, stop, and status updates work.

## Adapting it

Add, remove, rename, or reorder tools in `Tools\tools.json`. The launcher renders fields from the catalog instead of hard-coding each tool in the UI.

For a new PowerShell tool, add a catalog entry with:

- `id`: stable internal name
- `name`: label shown in the left navigation
- `order`: sort position
- `script`: path to the script relative to this folder
- `mode`: optional value passed as `-Mode`
- `fields`: input controls rendered on the right side

The same pattern can launch existing `.ps1`, `.bat`, or `.cmd` tools, then gradually move the logic into native PowerShell/.NET code.
