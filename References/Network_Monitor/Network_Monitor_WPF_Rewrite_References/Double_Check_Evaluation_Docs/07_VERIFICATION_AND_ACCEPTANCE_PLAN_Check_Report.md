# 07_VERIFICATION_AND_ACCEPTANCE_PLAN Check Report

Source document checked:

- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`

Source material checked against:

- `Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1`
- `Scripts\Network_Monitor\Scripts\Config.ps1`
- `Scripts\Network_Monitor\Scripts\Validation.ps1`
- `Scripts\Network_Monitor\Scripts\MonitorState.ps1`
- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`

## Verification Notes

- Automated harness structure is consistent with the current `Invoke-NetMonChecks.ps1` pattern: parser, module load, config, construction, presentation, selection color, ping state, ping engine, and event capture checks.
- Proposed config checks map to `Config.ps1` load/save/edit behavior and existing config harness checks.
- Proposed presentation and ping-state checks map to current `MonitorState.ps1` and `Presentation.ps1` behavior.
- Proposed ping-engine checks map to the current loopback/no-route harness pattern in `Invoke-NetMonChecks.ps1` lines 314-339.
- Manual settings checks cover the main visible controls and validation paths from `SettingsForm.ps1`.

## ISSUE-07-001 - Row Update Verification Omits Some Target Edit Paths

Status: `RESOLVED`

Resolution:

- Updated `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md` on 2026-06-23.
- The Row View Model Update Check now includes target rename, address edit, and color edit cases.
- The check now aligns with the deliberate WPF improvement:
  - Rename must update row identity/order and reset monitor state/history.
  - Address edit must update displayed address and reset monitor state/history.
  - Color edit must update node foreground/color presentation and reset monitor state/history.
  - If address/color are updated in place instead of rebuilding row objects, the test must verify the existing row remains valid and visible presentation updates immediately.

Document location:

- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, Row View Model Update Check, lines 219-230

Current wording:

- "Target add/delete/enable/order change rebuilds row collection."

Source verification:

- The current target cell edit path covers `Name`, `Address`, `Color`, and `Enabled` edits in `SettingsForm.ps1` lines 174-227.
- All of those edits call `Invoke-NMConfigEditAndApply -ResetMonitor -RebuildGrid` in `SettingsForm.ps1` line 229.
- `Apply-NMColumnsToGrid` rebuilds rows in `MainForm.ps1` lines 247-249.

Why this matters:

- The verification plan would not automatically catch a WPF implementation that handles add/delete/enable/reorder correctly but misses rename, address edit, or color edit reset/rebuild behavior.

Recommended correction:

- Add automated cases for:
  - Target rename: row identity/order updates and monitor state resets.
  - Target address edit: displayed address updates and monitor state resets.
  - Target color edit: node foreground/color preview updates and monitor state resets.
- If WPF intentionally updates address/color in place instead of rebuilding row objects, the test should still verify the visible update and reset semantics.

Resolution verification:

- Implemented.

## ISSUE-07-002 - Manual Monitoring Check Assumes Default Targets Are Unreachable

Status: `RESOLVED`

Resolution:

- Updated `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md` on 2026-06-23.
- The Manual Monitoring Checks now require a controlled unreachable target/config, for example `203.0.113.1` with a short timeout.
- The plan now states that default targets may also show the failure visuals if they are currently unreachable, but default targets are not required to be unreachable on every network.

Document location:

- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`, Manual Monitoring Checks, lines 382-392

Current wording:

- "With default unreachable test targets, after at least 3 attempted cycles:"

Source verification:

- Default targets are configured as `SMS`, `MPS`, and `MPG` with addresses `192.168.51.20`, `192.168.101.20`, and `192.168.200.100` in `Config.ps1` lines 55-59 and current config lines 2-20.
- The source does not define those defaults as guaranteed unreachable. They may be reachable or unreachable depending on the network where the app runs.
- The current automated harness uses a controlled no-route target `203.0.113.1` for failure behavior in `Invoke-NetMonChecks.ps1` lines 316-339.

Why this matters:

- A fresh rewrite session could fail or misinterpret manual verification on a network where one or more default targets are reachable.

Recommended correction:

- Reword the check to use a controlled unreachable target/config, for example `203.0.113.1` with a short timeout, or say "If the configured default targets are currently unreachable..." and separately require a controlled unreachable-target test.

Resolution verification:

- Implemented.
