# Source Audit And Prior Conversation Analysis

Generated: 2026-06-23

## Purpose

This document records what was inspected while creating the WPF rewrite plan and how to interpret the prior ChatGPT Pro WPF discussion.

## Prior Conversation Reviewed

Reviewed file:

`References\Network_Monitor\WinForms_vs_WPF_Convo.md`

Key conclusions from that conversation:

- WPF can implement the same app feature set as WinForms.
- A WPF rewrite does not require compiling if PowerShell loads XAML at runtime.
- WPF can improve layout, styling, templates, DPI behavior, and visual polish.
- WPF may not reduce total lines of code because it introduces XAML, bindings, converters, and view-model wiring.
- WPF is more complex to debug on an air-gapped machine than WinForms.
- No feature currently used by the app is inherently unavailable in WPF.
- WPF is a reasonable long-term choice for the Network Monitor because the UI is dashboard-like and benefits from data templates and central styling.

How this plan applies those conclusions:

- It uses PowerShell-hosted WPF with runtime-loaded XAML as the resolved path.
- It keeps no-install/no-NuGet/no-internet constraints.
- It preserves the current modular PowerShell architecture.
- It replaces WinForms custom painting with WPF templates.
- It requires a WPF assembly-load probe under `pwsh.exe` and fallback to `powershell.exe` if that probe fails.

## Current App Source Reviewed

Reviewed current implementation root:

`Scripts\Network_Monitor`

Reviewed files:

- `Network_Monitor.ps1`
- `Run_Network_Monitor.cmd`
- `Run_Network_Monitor.vbs`
- `Scripts\Logging.ps1`
- `Scripts\Validation.ps1`
- `Scripts\Config.ps1`
- `Scripts\MonitorState.ps1`
- `Scripts\PingEngine.ps1`
- `Scripts\UiHelpers.ps1`
- `Scripts\Presentation.ps1`
- `Scripts\MainForm.ps1`
- `Scripts\SettingsForm.ps1`
- `Tests\Invoke-NetMonChecks.ps1`
- `config\NetworkMonitor.config.json`

Reviewed current UI screenshot:

`References\Network_Monitor\Network_Monitor_WPF_Rewrite_References\Network_Monitor_Winform_UI.png`

Screenshot metadata:

- Width `1120`
- Height `330`
- Pixel format `Format32bppArgb`
- Approximately `96` DPI

## Current Test Harness Result

Command run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -STA -File Scripts\Network_Monitor\Tests\Invoke-NetMonChecks.ps1
```

Observed result:

```text
PASS Parser
PASS Module Load
PASS Config
PASS Form Construction
PASS Presentation
PASS Grid Selection Colors
PASS Ping State
PASS Ping Engine
PASS Event Capture Audit
All Network Monitor checks passed.
```

Interpretation:

- The current WinForms implementation is a valid behavior baseline.
- The WPF rewrite should preserve the current implementation's behavior.
- Older remediation documents remain useful as lessons learned, but they describe prior implementation failures rather than the final target state.

## Existing Reference Documents Reviewed

Reviewed existing Network Monitor references:

- `References\Network_Monitor\Network_Monitor_Contract.md`
- `References\Network_Monitor\Network_Monitor_QA_Conversation.md`
- `References\Network_Monitor\Network_Monitor_Remediation.md`
- `References\Network_Monitor\Network_Monitor_Remediation_Implementation.md`
- `References\Network_Monitor\NetMon_Fresh_Session_Handoff.md`
- `References\Network_Monitor\NetMon_Remediation_Plan.md`
- `References\Network_Monitor\NetMon_Architecture_Contract.md`
- `References\Network_Monitor\NetMon_Verification_Checklist.md`

How to interpret them:

- `Network_Monitor_QA_Conversation.md` captures authoritative product decisions.
- `Network_Monitor_Contract.md` captures the original WinForms product contract and remains authoritative for behavior where it still matches the current app.
- Remediation documents capture known pitfalls:
  - unsafe event closure capture
  - split presentation logic
  - worker-thread/runspace ping completion bugs
  - over-custom grid painting
  - settings commit semantics
  - strict config validation
- WPF rewrite docs in this folder supersede WinForms-specific architecture directions.

## Legacy Console Script Reviewed

Reviewed file:

`References\Network_Monitor\Network_Monitor.ps1`

Relevant legacy facts:

- Default targets were SMS/MPS/MPG with the same addresses.
- It used `SendPingAsync`.
- It tracked bytes, TTL, RTT, loss, and state.
- It used a console dashboard, ANSI/unicode formatting, cursor positioning, and console title updates.
- It used EMA average RTT in the legacy console model.
- It had debug/error logging helpers.

Rewrite interpretation:

- The legacy console script is not the WPF target.
- Its default targets and general ping-monitoring purpose are historical sources.
- Do not reintroduce console-only behavior.
- Do not switch RTT back to EMA average. Current product decision is latest RTT.
- Do not add unsupported columns from legacy state unless separately requested.

## Worktree Note

At planning time, the worktree already showed:

```text
 M Scripts/Network_Monitor/config/NetworkMonitor.config.json
?? References/Network_Monitor/Network_Monitor_WPF_Rewrite_References/
?? References/Network_Monitor/WinForms_vs_WPF_Convo.md
```

The planning work intentionally did not modify current app code or the runtime config file.

## Planning Documents Generated

Generated in this folder:

- `00_README_WPF_REWRITE_HANDOFF.md`
- `01_EXISTING_APP_FUNCTIONAL_SPEC.md`
- `02_EXISTING_UI_VISUAL_SPEC.md`
- `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`
- `04_WPF_TARGET_ARCHITECTURE.md`
- `05_IMPLEMENTATION_PLAN.md`
- `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`
- `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`
- `08_WPF_DECISION_POINTS_UNDECIDED.md`
- `09_WPF_IMPLEMENTATION_PATTERNS.md`
- `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`
- `11_SOURCE_AUDIT_AND_PRIOR_CONVERSATION_ANALYSIS.md`
- `12_RESOLVED_WPF_DECISIONS.md`

Together, these documents are intended to let a fresh session execute the WPF rewrite without needing the prior chat context.
