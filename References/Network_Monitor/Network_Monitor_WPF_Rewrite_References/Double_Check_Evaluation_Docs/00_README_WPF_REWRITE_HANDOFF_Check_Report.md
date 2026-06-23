# 00 README WPF Rewrite Handoff - Check Report

Started: 2026-06-23

## Source Material Checked

- Planning doc: `References\Network_Monitor\Network_Monitor_WPF_Rewrite_References\00_README_WPF_REWRITE_HANDOFF.md`
- Current WinForms entry point: `Scripts\Network_Monitor\Network_Monitor.ps1`
- Current WinForms main form: `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- Current WinForms config module: `Scripts\Network_Monitor\Scripts\Config.ps1`

## Verification Notes

- The baseline app path in the README is source-correct: current entry/module load is under `Scripts\Network_Monitor`; `Network_Monitor.ps1` loads app-local modules from that root.
- The stated default config semantics are source-correct: defaults are generated in `Get-NMDefaultConfig`, with default target/config values under `Config.ps1`.
- The stated current window title, size calculation, bottom-left placement, and main-window persistence are source-supported by `MainForm.ps1`.
- The statement that WPF should preserve current implemented behavior is methodologically sound because the current app has a passing nonvisual harness and the planning pack is a rewrite plan rather than a remediation of a broken current state.

## Issues Found

## ISSUE-00-001 - WPF runtime availability is not source-verified

Resolution status:

- `RESOLVED` for the target environment tested on 2026-06-23.

Planning doc location:

- `00_README_WPF_REWRITE_HANDOFF.md`, hard constraints section, especially the claim that the rewrite should have "No new runtime dependency that requires installation on the target machine."

Source verification:

- Current app loads WinForms/Drawing only in `Scripts\Network_Monitor\Network_Monitor.ps1` lines 50-52.
- Current source does not load or probe WPF assemblies.

Why this matters:

- The WPF rewrite necessarily adds a WPF assembly requirement (`PresentationFramework`, `PresentationCore`, `WindowsBase`, and possibly `System.Xaml`).
- The resolved plan mitigates this with a `pwsh.exe` WPF probe and `powershell.exe` fallback, but the current WinForms source cannot prove WPF availability on the target.

Recommended handling:

- Keep the constraint, but treat it as a target-environment requirement to verify during WPF skeleton work.
- The verification plan should retain the WPF assembly-load check and fallback-host check.

Status:

- Resolved by target-machine runtime probe.
- This remains an environmental fact, not something the current WinForms source can prove.

Target verification performed:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -STA -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.Window]::new() | Out-Null; 'WPF OK in pwsh'"
```

Observed result:

```text
WPF OK in pwsh
```

Conclusion:

- WPF is available under `pwsh.exe` on the tested target environment.
- The WPF rewrite can use the planned PowerShell 7 host path there.
- The `powershell.exe` fallback remains useful in the plan, but was not needed to prove WPF availability on this target.
