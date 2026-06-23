# Network Monitor WPF Rewrite Handoff

Generated: 2026-06-23

## Purpose

This folder is the self-contained planning pack for rewriting the current PowerShell WinForms Network Monitor as a WPF application while preserving the current application's behavior, settings, monitoring semantics, and visual direction.

The WPF app does not need to be an identical pixel-for-pixel clone, but it must carry forward every user-facing capability and every important edge case from the existing app.

## Current Baseline

Authoritative existing application:

`Scripts\Network_Monitor`

Current main UI screenshot:

`References\Network_Monitor\Network_Monitor_WPF_Rewrite_References\Network_Monitor_Winform_UI.png`

Screenshot metadata:

- Width: `1120`
- Height: `330`
- Pixel format: `Format32bppArgb`
- Approximate DPI: `96`

Current nonvisual verification status on 2026-06-23:

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

The passing WinForms test harness means the rewrite should preserve the current implemented behavior, not older broken intermediate behavior described in remediation notes.

## Required Reading Order For A Fresh Rewrite Session

Read these files in this folder first:

1. `Network_Monitor_WPF_Rewrite_Phased_Implementation_Plan.md`
2. `00_README_WPF_REWRITE_HANDOFF.md`
3. `01_EXISTING_APP_FUNCTIONAL_SPEC.md`
4. `02_EXISTING_UI_VISUAL_SPEC.md`
5. `03_CONFIG_STATE_AND_VALIDATION_SPEC.md`
6. `04_WPF_TARGET_ARCHITECTURE.md`
7. `05_IMPLEMENTATION_PLAN.md`
8. `06_WINFORMS_TO_WPF_MIGRATION_MAP.md`
9. `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md`
10. `08_WPF_DECISION_POINTS_UNDECIDED.md`
11. `12_RESOLVED_WPF_DECISIONS.md`
12. `09_WPF_IMPLEMENTATION_PATTERNS.md`
13. `10_REQUIREMENTS_TRACEABILITY_MATRIX.md`
14. `11_SOURCE_AUDIT_AND_PRIOR_CONVERSATION_ANALYSIS.md`

Then inspect the current implementation under `Scripts\Network_Monitor` only when a code-level detail is needed.

Decision handling note:

- `08_WPF_DECISION_POINTS_UNDECIDED.md` is the raw decision-question log and still contains the original `Status: UNDECIDED` labels for traceability.
- `12_RESOLVED_WPF_DECISIONS.md` is the authoritative implementation directive for those decisions.
- Do not treat `UNDECIDED` labels in `08` as open questions when `12` contains the resolved directive.

## Existing Reference Context

The original WPF discussion is stored at:

`References\Network_Monitor\WinForms_vs_WPF_Convo.md`

Important takeaways from that conversation:

- WPF can reproduce the current feature set.
- Runtime-loaded XAML can keep the no-build, no-install workflow.
- WPF should improve layout, styling, data templates, DPI behavior, and visual consistency.
- WPF introduces complexity around XAML loading, binding, converters, and event wiring.
- On the target air-gapped Windows machines, the implementation must not assume internet, NuGet, package downloads, or external icon/font/image assets.

## Rewrite Objective

Build a WPF Network Monitor that:

- Launches as a standalone app from `Scripts\Network_Monitor_WPF`.
- Can be started without the main Tool Launcher remaining open.
- Uses the same JSON config semantics and default target/config values.
- Uses the same ping engine semantics: concurrent async pings, one ping per enabled target per cycle, skipped overlapping ticks, no queued cycles.
- Uses the same health/status/RTT/loss/history rules.
- Provides the same settings capabilities.
- Persists window bounds, pin state, target settings, column layout, thresholds, timing, auto-start, and debug mode.
- Looks close to `Network_Monitor_Winform_UI.png`: dark bespoke utility window, custom title bar, grid-only main content, compact rows, bright health colors.

## Hard Constraints

- No internet access assumptions.
- No NuGet downloads.
- No external PowerShell modules.
- No web frontend.
- No tray app behavior.
- No new runtime dependency that requires installation on the target machine.
- Prefer `pwsh.exe` PowerShell 7.5.2, probe WPF assembly availability, and fall back to `powershell.exe` Windows PowerShell 5.1 if WPF cannot load under PowerShell 7.
- All paths must resolve relative to the app root or script location.
- Keep code modular and practical to debug or hand-transcribe on an air-gapped machine.
- Do not edit `References\Network_Monitor\Network_Monitor.ps1`; that is the legacy console reference script.

## Target File Layout

Resolved rewrite location:

```text
Scripts\Network_Monitor_WPF\
  Network_Monitor_WPF.ps1
  Run_Network_Monitor_WPF.cmd
  Run_Network_Monitor_WPF.vbs
  config\
    NetworkMonitor.config.json
  logs\
  Scripts\
    Logging.ps1
    Validation.ps1
    Config.ps1
    MonitorState.ps1
    PingEngine.ps1
    Presentation.ps1
    WpfTheme.ps1
    WpfBindings.ps1
    WpfXaml.ps1
    WpfWindowChrome.ps1
    SettingsWindow.ps1
    MainWindow.ps1
  Views\
    MainWindow.xaml
    SettingsWindow.xaml
  Tests\
    Invoke-NetMonWpfChecks.ps1
```

Do not overwrite the current WinForms implementation. Keep it as a fallback until the WPF app is verified on the target air-gapped machine.

## Product Non-Goals

Do not add these unless separately requested:

- Average RTT, min RTT, max RTT, last seen, or last success columns.
- Cumulative packet loss metric.
- Warning banner when all nodes are down.
- Color picker dialog.
- Tray icon or background minimize-to-tray behavior.
- Column sorting.
- Import parser for partial invalid config salvage.
- External icon font.
- Network maps or topology visualizations.
- Start/pause controls in the main window.

## Legacy Console Script Boundary

`References\Network_Monitor\Network_Monitor.ps1` is not the target UI. It is useful only as historical context. It includes console-only features such as ASCII/Unicode dashboard rendering, EMA RTT, console title updates, and error/debug log trimming. The current WinForms app intentionally replaced or deferred several of those behaviors. Do not reintroduce legacy console behavior unless it is also present in the current WinForms app or explicitly requested.

## Completion Standard

The rewrite is complete only when:

- The WPF app launches standalone.
- The WPF app visually matches the current dark dashboard closely enough for operator continuity.
- Every behavior in `01_EXISTING_APP_FUNCTIONAL_SPEC.md` is implemented or explicitly marked not applicable with a reason.
- Every config/state rule in `03_CONFIG_STATE_AND_VALIDATION_SPEC.md` is implemented.
- Every resolved decision in `12_RESOLVED_WPF_DECISIONS.md` is followed.
- Every manual and automated check in `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md` passes or is documented.
