# 09_WPF_IMPLEMENTATION_PATTERNS Check Report

Source document checked:

- `09_WPF_IMPLEMENTATION_PATTERNS.md`

Source material checked against:

- `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`
- `Scripts\Network_Monitor\Scripts\Presentation.ps1`
- `Scripts\Network_Monitor\Scripts\MainForm.ps1`
- `Scripts\Network_Monitor\Scripts\SettingsForm.ps1`
- `Scripts\Network_Monitor\Scripts\PingEngine.ps1`
- `Scripts\Network_Monitor\config\NetworkMonitor.config.json`
- `12_RESOLVED_WPF_DECISIONS.md`

## Verification Notes

- Resolved implementation choices match `12_RESOLVED_WPF_DECISIONS.md`.
- Assembly loading, XAML loading, `DispatcherTimer`, async ping polling, settings commit, feedback, and exception-handler patterns are methodologically consistent with the current WinForms implementation boundaries.
- Status template dimensions match current status-cell paint geometry in `MainForm.ps1` lines 416-439.
- History template intent matches current history paint behavior in `MainForm.ps1` lines 446-481 and `Presentation.ps1` lines 45-56.
- Title button pattern matches current icon-only title button behavior in `UiHelpers.ps1` lines 239-315 and 467-545.

## ISSUE-09-001 - Sample Row Model Hard-Codes A Brush Name Not Present In The Source Theme

Status: `RESOLVED`

Document location:

- `09_WPF_IMPLEMENTATION_PATTERNS.md`, View Model Fallback Ladder, lines 149-160

Current sample:

- `NodeForeground = $script:NMBrushes.Magenta`

Source verification:

- The current theme in `UiHelpers.ps1` lines 66-87 does not define `Magenta`.
- Target colors are stored in config per target:
  - SMS: `#ff40e6`
  - MPS: `#ff40e6`
  - MPG: `#27d9e6`
- Current node presentation derives the node foreground from the target's configured `Color` value through `ConvertTo-NMDrawingColor -HtmlColor ([string]$Target.Color)` in `Presentation.ps1` line 68.

Why this matters:

- A fresh WPF implementation could incorrectly add fixed named brushes for target colors instead of preserving per-target configurable colors.

Recommended correction:

- Replace the sample with a target-derived brush, for example:

```powershell
NodeForeground = ConvertTo-NMWpfBrush -Hex ([string]$target.Color)
```

- If brush caching is added, cache by target color hex value rather than hard-coding `Magenta`/`Cyan` as theme colors.

Resolution:

- Updated `09_WPF_IMPLEMENTATION_PATTERNS.md` so the sample row model derives `Name`, `Address`, and `NodeForeground` from a target object.
- Replaced the nonexistent `$script:NMBrushes.Magenta` example with `New-NMWpfBrush -Hex ([string]$target.Color)`, matching the WPF brush helper already defined in the same document.
- Added guidance that target node foregrounds must come from each target's configured `Color` value and that any brush cache should be keyed by normalized color hex.
