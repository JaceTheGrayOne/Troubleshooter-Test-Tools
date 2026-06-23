# WPF Rewrite Implementation Plan

Generated: 2026-06-23

## Purpose

This document gives a fresh implementation session a practical sequence for rewriting the current Network Monitor in WPF without missing behavior.

## Guiding Principle

Port the behavior first, then polish visuals. The existing WinForms app has a passing nonvisual harness and a stable functional contract. The WPF rewrite should preserve that contract while replacing manual WinForms painting/layout with WPF resources, templates, and binding.

## Phase 0 - Apply Resolved Decisions

Before coding, review:

`08_WPF_DECISION_POINTS_UNDECIDED.md`

Then use the distilled directives in:

`12_RESOLVED_WPF_DECISIONS.md`

Treat `08_WPF_DECISION_POINTS_UNDECIDED.md` as the raw historical decision log. Its original `Status: UNDECIDED` labels are not open implementation questions after `12_RESOLVED_WPF_DECISIONS.md` has resolved them.

The implementation path is now resolved: PowerShell-hosted WPF, separate XAML files under `Views`, sibling folder `Scripts\Network_Monitor_WPF`, WPF `DataGrid`, direct WPF brush binding, PSCustomObject-first view models, TextBox numeric settings, and WindowChrome-first custom title bar.

## Phase 1 - Create WPF App Skeleton

Tasks:

1. Create target folder `Scripts\Network_Monitor_WPF`.
2. Add launch shims:
   - `Run_Network_Monitor_WPF.cmd`
   - `Run_Network_Monitor_WPF.vbs`
3. Add entry script:
   - `Network_Monitor_WPF.ps1`
4. Implement:
   - app-root detection
   - preferred PowerShell discovery
   - WPF assembly-load probe with fallback from `pwsh.exe` to `powershell.exe` when needed
   - STA self-relaunch
   - WPF assembly load
   - module load order
   - top-level startup error handling
5. Create empty `Views\MainWindow.xaml` and `Views\SettingsWindow.xaml`.
6. Verify an empty dark WPF window launches through:
   - direct PS1
   - CMD shim
   - VBS shim

Acceptance:

- No visible console remains from VBS launch.
- Window appears in taskbar.
- Fatal XAML/module load failure shows message box and writes startup log.

## Phase 2 - Port Nonvisual Core

Port or copy-adapt these current modules:

- `Logging.ps1`
- `Validation.ps1`
- `Config.ps1`
- `MonitorState.ps1`
- `Presentation.ps1`

Tasks:

1. Preserve default config exactly.
2. Preserve column definitions and min widths.
3. Preserve strict config load behavior.
4. Preserve invalid config backup behavior.
5. Preserve atomic save behavior.
6. Preserve transactional config edit helper.
7. Preserve target state model and health calculations.
8. Change presentation colors from `System.Drawing.Color` to WPF `SolidColorBrush` objects for direct binding.

Acceptance:

- Default config validates.
- Invalid config is rejected as a whole and backed up.
- Transactional edit failure leaves live config unchanged.
- Presentation scenarios match current app:
  - no sample
  - one failed sample
  - three failed samples
  - one success

## Phase 3 - Build WPF Theme And Main Window Shell

Tasks:

1. Define WPF resource dictionary values for all current theme colors.
2. Define font resources:
   - title
   - grid header
   - grid text
   - grid bold
   - settings text
   - settings bold
3. Build main `Window` with:
   - no standard title bar
   - dark border
   - 46 DIP title row
   - fill row for DataGrid
4. Create reusable title bar template/control pattern:
   - title text
   - icon buttons
   - tooltip support
   - active state support
5. Implement title bar commands:
   - settings
   - reset
   - pin
   - minimize
   - maximize/restore
   - close
6. Implement drag/double-click maximize/restore.
7. Implement resize support using `WindowChrome` first, with manual/native fallback only if needed.

Acceptance:

- Main WPF shell resembles the screenshot before data is added.
- Button order and active/hover/pressed states match the visual spec.
- Drag, minimize, maximize/restore, and close work.

## Phase 4 - Implement Window Placement Persistence

Tasks:

1. Calculate default size based on visible column widths and enabled target count.
2. Use `1040 x 270` as the generated config baseline and apply config window size with minimum constraints.
3. If X/Y are null, place bottom-left of primary working area.
4. If X/Y exist, validate against all screens.
5. If saved position is off-screen, fallback bottom-left.
6. Restore maximized state.
7. Save restore bounds on close.
8. Implement reset window position command.

Acceptance:

- First run is taskbar-flush bottom-left.
- Move/resize/close/relaunch restores bounds.
- Off-screen saved position falls back.
- Maximized state persists.

## Phase 5 - Build Main DataGrid

Tasks:

1. Create DataGrid with dark theme.
2. Disable adding/deleting rows.
3. Disable sorting.
4. Allow column resize.
5. Allow column reorder.
6. Hide row headers.
7. Set row height around `52`.
8. Set header height around `38`.
9. Build columns from config order:
   - text columns for Node, Address, RTT, Loss, TTL, Bytes
   - template columns for Status and History
10. Apply min widths and initial widths.
11. Bind rows to observable collection.
12. Preserve foreground colors under selection.

Acceptance:

- Default six columns display.
- TTL/Bytes exist and are hidden by default.
- Rows display enabled targets in order.
- Node colors match target colors.
- Selection does not corrupt health text colors.

## Phase 6 - Build Status And History Templates

Status template:

- Ellipse/dot, diameter about `16`.
- Dot color bound to status/health brush.
- Text bound to status text.
- Text color bound to same health brush.
- Bold grid font.

History template:

- Horizontal items list with exactly `HistoryLength` items.
- Each item renders as fixed-size vertical bar.
- Bar colors:
  - null = yellow
  - true = green
  - false = red
- Bars stay vertically centered.
- No layout shift as samples change.

Acceptance:

- With no samples, history bars are yellow.
- With failed samples, bars turn red.
- With successful samples, bars turn green.
- Three failed default targets visually match screenshot state after threshold.

## Phase 7 - Port Ping Engine To WPF

Tasks:

1. Use `SendPingAsync()` exactly as current app does.
2. Start one ping per enabled target per cycle.
3. Use `DispatcherTimer` for refresh ticks.
4. Use dispatcher-safe completion polling or dispatcher-marshaled task completion.
5. Skip refresh tick if cycle busy.
6. Dispose every `Ping`.
7. Preserve generation discard behavior.
8. On completed cycle:
   - apply ping results to state
   - update row view models in place

Acceptance:

- Loopback success produces one green sample and RTT.
- Unreachable target produces one failed sample, timeout text, red RTT/loss/history after attempted timeout.
- Busy cycle skip produces no sample.
- UI remains responsive during timeouts.

## Phase 8 - Build Settings Window Shell

Tasks:

1. Create settings XAML window.
2. Use same title bar visual language.
3. One close button only.
4. Set owner to main window.
5. Show non-modally.
6. Enforce single instance.
7. Focus existing settings window on repeated cog click.
8. Keep settings above main.
9. Mirror topmost when main is pinned.
10. Activate settings cog active blue state while open.
11. Clear active state when closed.

Acceptance:

- Settings opens/focuses correctly.
- Monitoring continues.
- Settings close does not close main.
- Settings stays above main.

## Phase 9 - Implement Settings Tabs

Targets tab:

- Editable target grid/list.
- Enabled checkbox.
- Name/address/color edit.
- Add/Delete/Move Up/Move Down.
- Color preview swatch.
- Validation and rollback.

Columns tab:

- Visible columns checkbox list.
- Column order list.
- Move Up/Move Down.
- Selected width editor.
- Persist and rebuild grid on committed changes.

Timing tab:

- Refresh interval.
- Ping timeout.
- History length.
- Auto-start checkbox.

Health tab:

- Health thresholds.
- RTT thresholds.
- Loss thresholds.
- Enforce ordering validation through full config validation.

General tab:

- Always on top.
- Debug logging.
- Reset window position.
- Reset to defaults with confirmation.

Acceptance:

- All settings from the WinForms app are present.
- Invalid edits restore previous values.
- Valid edits persist.
- Monitor state resets when required.

## Phase 10 - Implement Commit Semantics

Tasks:

1. Text/numeric settings commit on:
   - Enter
   - lost focus
2. Checkboxes commit on click.
3. Target text cells commit on edit completion/focus change/Enter.
4. No high-frequency config writes on every keystroke.
5. Column resize from main grid persists with debounce or on close.
6. All settings changes use transactional config edits.
7. Inline feedback is visible and color-coded.

Acceptance:

- Typing partial invalid numeric input does not immediately mutate config.
- Enter commits valid edits.
- Focus leave commits valid edits.
- Invalid edit restores active value.

## Phase 11 - Verification Harness

Create:

`Scripts\Network_Monitor_WPF\Tests\Invoke-NetMonWpfChecks.ps1`

Initial automated checks:

- Parser check.
- WPF assembly load check.
- XAML parse/load check.
- Module load check.
- Config validation check.
- Presentation check.
- Main window construction check.
- Settings window construction check.
- Ping state check.
- Ping engine check.
- Column config and view-model update check.

Acceptance:

- Harness exits `0` on pass.
- Harness exits nonzero on failure.
- Output clearly identifies failed check.

## Phase 12 - Manual Visual And Interaction Pass

Run the app visibly and verify:

- Main window matches screenshot closely.
- Title bar commands work.
- Grid colors and dimensions are close.
- Settings tabs are usable.
- Pinned/topmost behavior works.
- Reset clears state.
- Window placement persists.
- Unreachable default targets reach `DOWN` after threshold.
- Loopback or known reachable target shows green success.

Use `07_VERIFICATION_AND_ACCEPTANCE_PLAN.md` as the final gate.

## Phase 13 - Deferred Integration And Fallback

After WPF app passes standalone verification:

- Keep the existing WinForms app as fallback until WPF is verified on the target air-gapped machine.
- Defer ToolLauncher integration until standalone WPF target-PC testing passes.
- Only after that verification, decide whether the launcher should point to the WPF shim.

Do not remove the WinForms implementation until WPF is verified on the target machine.

## Implementation Stop Rules

Stop and reassess if:

- A WPF binding requires duplicating health logic in XAML triggers.
- A worker thread needs to call PowerShell UI/state functions directly.
- Settings changes mutate live config before validation.
- Main and settings windows start diverging in title bar/style behavior.
- You need to use external packages or downloaded assets.
- The WPF runtime fails under both `pwsh.exe` and the fallback `powershell.exe` host.

## Definition Of Done

- WPF app launches through direct PS1, CMD, and VBS.
- UI closely resembles current screenshot.
- All current functional requirements are present.
- Config schema and validation are preserved.
- Ping and state semantics are preserved.
- Settings behavior is preserved.
- Automated checks pass.
- Manual visible acceptance checks pass.
- All resolved decisions in `12_RESOLVED_WPF_DECISIONS.md` are followed.
