You are working in D:\Development\Troubleshooters_Test_Tools.

Implement the Remote Access client refactor described in:

docs\Remote_Access_Client_Refactor\Remote_Access_Client_Refactor_Plan.md

Goal:
Turn the current separate RMUP telnet console and Spectracom GPS serial auth tools into one launcher tool named Remote Access. The UI should have a Protocol dropdown with Telnet and Serial. Telnet should show Telnet settings. Serial should show Serial settings. The right side of the Remote Access UI should have preset buttons for RMUP Log and GPS Auth. RMUP Log should populate Telnet settings for 192.168.200.100:23. GPS Auth should populate Serial settings and run the existing Spectracom authentication logic.

Important constraints:
- Do not touch archive/. It is a local backup and should remain ignored.
- Keep the scope focused. This is not a full PuTTY clone.
- Preserve the existing behavior of RMUP telnet option negotiation and interactive input.
- Preserve the existing GPS Auth behavior: wake prompt, detect already-authenticated SecureSync prompt, send username/password only when needed, and never print the password.
- Prefer shared RemoteAccess code over duplicated one-off scripts.
- If old Scripts\RmupConsole.ps1 and Scripts\SpectracomGpsAuth.ps1 remain, make them tiny compatibility wrappers only.
- Update README.md to match the new single-tool model.

Expected implementation shape:
- Tools\tools.json contains one Remote Access tool entry instead of separate RMUP/GPS tool entries.
- Tools\remote-access.presets.json defines RMUP Log and GPS Auth presets.
- Scripts\RemoteAccess.ps1 dispatches Telnet, generic Serial, or GPS Auth action.
- Scripts\RemoteAccess.Telnet.ps1 contains the Telnet implementation.
- Scripts\RemoteAccess.Serial.ps1 contains the generic Serial implementation.
- Scripts\RemoteAccess.Actions.SpectracomGpsAuth.ps1 contains the GPS Auth action.
- ToolLauncher.ps1 supports hidden fields, conditional fields, and preset buttons for tools with presetsPath.

Before editing:
- Run git status --short.
- Read the plan document completely.
- Inspect ToolLauncher.ps1, Scripts\ToolRuntime.ps1, Scripts\RmupConsole.ps1, Scripts\SpectracomGpsAuth.ps1, Scripts\ToolCommon.ps1, and Tools\tools.json.

Verification required before final response:
- Run a PowerShell parser check over all .ps1 files excluding archive/.
- Load the tool catalog through Scripts\ToolRuntime.ps1 and confirm Remote Access appears.
- If possible, launch the GUI with powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\ToolLauncher.ps1 and smoke-test the UI.
- If hardware is unavailable, state that RMUP/GPS hardware behavior was not live-tested.
- Run git status --short and report the changed files.

Finish by committing the completed refactor with a concise commit message.