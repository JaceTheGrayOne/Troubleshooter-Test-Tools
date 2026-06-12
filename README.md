# Troubleshooter Test Tools

No-install Windows 11 launcher for the troubleshooting scripts in this repo. It uses built-in Windows PowerShell and .NET Windows Forms.

## Run it

Double-click `Run_Tool_Launcher.vbs` to launch only the GUI. `Run_Tool_Launcher.cmd` is kept as a compatibility wrapper.

You can also run this from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\ToolLauncher.ps1
```

## What it does

- `ToolLauncher.ps1` opens a dark utility-style GUI with a left-side tool list and a right-side tool workspace.
- `Tools\tools.json` controls which tools appear, their fields, and which PowerShell script they run.
- `Scripts\ToolRuntime.ps1` contains catalog loading, process start/stop, console input, and log reads.
- `Remote Access` is the single launcher tool for remote equipment access.
- The `Protocol` dropdown switches between Telnet settings and Serial settings.
- The `RMUP Log` preset fills Telnet settings for `192.168.200.100:23`.
- The `GPS Auth` preset fills Serial settings and runs the Spectracom SecureSync authentication flow.
- `Network Monitor` launches the batch file configured in its `launchPath` catalog entry.
- `Test Report Parser` launches the batch file configured in its `launchPath` catalog entry.
- Each run writes a timestamped log under `Logs`.
