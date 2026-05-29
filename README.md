# Troubleshooter Test Tools

No-install Windows 11 launcher for the troubleshooting scripts in this repo. It uses built-in Windows PowerShell and .NET Windows Forms.

## Run it

Double-click `Run_Tool_Launcher.cmd`, or run this from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\ToolLauncher.ps1
```

## What it does

- `ToolLauncher.ps1` opens a dark utility-style GUI with a left-side tool list and a right-side tool workspace.
- `Tools\tools.json` controls which tools appear, their fields, and which PowerShell script they run.
- `Scripts\ToolRuntime.ps1` contains catalog loading, process start/stop, console input, and log reads.
- `Scripts\SpectracomGpsAuth.ps1` handles Spectracom SecureSync serial authentication.
- `Scripts\RmupConsole.ps1` handles the RMUP telnet console.
- Each run writes a timestamped log under `Logs`.
