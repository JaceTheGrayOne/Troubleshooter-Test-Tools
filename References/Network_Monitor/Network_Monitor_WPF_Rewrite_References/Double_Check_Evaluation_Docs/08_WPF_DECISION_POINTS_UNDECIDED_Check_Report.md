# 08_WPF_DECISION_POINTS_UNDECIDED Check Report

Source document checked:

- `08_WPF_DECISION_POINTS_UNDECIDED.md`

Related planning document checked:

- `12_RESOLVED_WPF_DECISIONS.md`

Source material checked against:

- Current WinForms source where decisions depend on existing behavior:
  - `Network_Monitor.ps1`
  - `Run_Network_Monitor.vbs`
  - `Scripts\Config.ps1`
  - `Scripts\MainForm.ps1`
  - `Scripts\SettingsForm.ps1`
  - `Scripts\UiHelpers.ps1`

## Verification Notes

- All 16 user response answers in `08_WPF_DECISION_POINTS_UNDECIDED.md` are reflected in `12_RESOLVED_WPF_DECISIONS.md`.
- Current-source-based rationale is supported:
  - Current app is PowerShell-hosted and no-build.
  - Current launcher prefers `pwsh.exe` and falls back to `powershell.exe`.
  - Current config lives next to the script.
  - Current settings window is fixed-size.
  - Current app already uses small `Add-Type` C# in `UiHelpers.ps1` lines 1-64, so the C#-helper decision correctly treats runtime compilation as possible but optional.
- No source contradiction found in the resolved decision content.

## ISSUE-08-001 - Raw Decision Log Still Says Undecided Labels Should Be Removed

Status: `RESOLVED`

Document location:

- `08_WPF_DECISION_POINTS_UNDECIDED.md`, lines 7-9

Current wording:

- "Each item is marked `UNDECIDED` for user review."
- "After the user answers these, update the rewrite plan and remove or resolve the `UNDECIDED` labels."

Verification:

- The user responses have been added to every decision point.
- `12_RESOLVED_WPF_DECISIONS.md` now explicitly says it is the authoritative implementation directive and that any remaining `Status: UNDECIDED` labels in `08` are historical, not open implementation questions.
- Earlier instruction was to not modify `08_WPF_DECISION_POINTS_UNDECIDED.md` itself.

Why this matters:

- A fresh implementation session may see `Status: UNDECIDED` in `08` and think decisions are still open, even though `12` contains the resolved directives.

Recommended correction:

- Do not modify `08` unless the user explicitly allows it.
- If `08` remains raw, ensure handoff docs continue to direct implementers to use `12_RESOLVED_WPF_DECISIONS.md` as the authoritative implementation directive.

Resolution:

- Left `08_WPF_DECISION_POINTS_UNDECIDED.md` intact as the raw historical decision log.
- Updated `00_README_WPF_REWRITE_HANDOFF.md`, `05_IMPLEMENTATION_PLAN.md`, `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`, and `12_RESOLVED_WPF_DECISIONS.md` to state that `12_RESOLVED_WPF_DECISIONS.md` is authoritative for implementation.
- Added explicit guidance that `Status: UNDECIDED` labels in `08` are historical and must not be treated as open implementation questions.
