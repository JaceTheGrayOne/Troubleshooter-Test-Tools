# Network Monitor Fresh Session Handoff

Generated: 2026-06-23

## Mission

Perform a full architecture remediation pass on the PowerShell WinForms Network Monitor app under:

`Scripts\Network_Monitor`

Do not continue one-off symptom patching. The purpose is to make the implementation structurally reliable, compact, modular, and practical to hand-transcribe into an airgapped machine terminal.

## Required Reading Order

Read these before editing code:

1. `References\Network_Monitor\NetMon_Remediation_Plan.md`
2. `References\Network_Monitor\Network_Monitor_Contract.md`
3. `References\Network_Monitor\Network_Monitor_Remediation.md`
4. `References\Network_Monitor\NetMon_Architecture_Contract.md`
5. `References\Network_Monitor\NetMon_Verification_Checklist.md`
6. `References\Network_Monitor\Network_Monitor_Mockup.png`
7. Current implementation under `Scripts\Network_Monitor`

The original contract remains authoritative for product behavior. The remediation plan and architecture contract are authoritative for repairing the failed implementation patterns.

## Hard Constraints

- Do not edit `References\Network_Monitor\Network_Monitor.ps1`.
- App code lives under `Scripts\Network_Monitor`.
- Main entry point remains `Scripts\Network_Monitor\Network_Monitor.ps1`.
- Keep the app standalone and directly launchable.
- All paths must resolve relative to the app root.
- No external dependencies.
- No internet access assumptions.
- No NuGet/module downloads.
- No WPF rewrite.
- No HTML/web frontend.
- No new icon/font/image packages.
- Use PowerShell plus .NET WinForms/Drawing APIs available to PowerShell 7.5.2.
- Prefer compact, reusable helper functions over duplicated blocks.
- Code should be understandable and practical to hand-enter on an airgapped system.

## Current Known Failure Pattern

The implementation failed because it accumulated one-off WinForms event handlers, script-scope globals, and split rendering logic.

Concrete defects that already occurred:

- Grid custom painting erased itself with `Graphics.Clear()`.
- Rows were recreated every cycle instead of updated in place.
- Ping results did not reach UI state because `BackgroundWorker` callbacks invoked PowerShell scriptblocks without a runspace.
- RTT/Loss text color differed by selected row because selection styling bypassed presentation color.
- Settings title-bar drag moved the main window because an event handler resolved the wrong `$Form`.
- Settings UI styling drifted from the main window because both windows were built separately.

These are symptoms of architecture problems. Do not assume fixing a visible bug is enough.

## Implementation Strategy

Work in this order:

1. Add or update the nonvisual test harness first:

`Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`

2. Stabilize all WinForms event handler capture.
3. Extract shared app-window and title-bar helpers.
4. Move column presentation into `Scripts\Presentation.ps1`.
5. Refactor main grid to consume the presentation object everywhere.
6. Refactor settings to use shared window/control helpers.
7. Verify ping-cycle behavior.
8. Run parser, construction, presentation, ping-state, and manual interaction checks.
9. Only then adjust visual polish.

## Files Expected To Change

Likely:

- `Scripts\Network_Monitor\Network_Monitor.ps1`
- `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`

Likely new:

- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`

Do not edit:

- `References\Network_Monitor\Network_Monitor.ps1`

Avoid changing unless needed:

- `Run_Network_Monitor.cmd`
- `Run_Network_Monitor.vbs`

## Implementation Stop Rules

Stop and reassess before continuing if:

- You need to duplicate a block of control construction.
- You need to add a new event handler inside a helper without `.GetNewClosure()`.
- You need to add column-specific display logic outside `Presentation.ps1`.
- You need to write to live config before validating and saving a clone.
- You need to call PowerShell UI/state functions from a worker thread.
- A manual interaction check fails.

## Minimum Verification Before Final Response

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1
```

Then manually verify against the visible app:

- main title bar drag moves main window only
- settings title bar drag moves settings only
- settings close closes settings only
- unreachable targets show timeout, 100.0% loss, red history, and DOWN after threshold
- selected/current grid cells do not alter health colors
- Health tab is readable
- settings edits commit on Enter/focus leave and invalid edits restore previous valid values

## Expected Final Report

A final implementation report should include:

- Files changed.
- Architecture changes made.
- Verification commands run.
- Manual interaction checks performed.
- Any checks not performed and why.

Do not claim completion based only on parser checks or form construction checks.
