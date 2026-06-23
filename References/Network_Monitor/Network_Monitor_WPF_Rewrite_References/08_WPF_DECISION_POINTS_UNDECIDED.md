# WPF Decision Points - UNDECIDED

Generated: 2026-06-23

## Purpose

This document lists decisions introduced by moving from WinForms to WPF. Each item is marked `UNDECIDED` for user review.

After the user answers these, update the rewrite plan and remove or resolve the `UNDECIDED` labels.

## DP-001 - Hosting Model

Status: `UNDECIDED`

Question:

Should the WPF rewrite be a PowerShell-hosted WPF script with runtime-loaded XAML, or a compiled .NET WPF project/executable?

Recommended default:

- PowerShell-hosted WPF with runtime-loaded XAML.

Reason:

- Preserves the current no-build, no-install, air-gapped, hand-copyable workflow.
- Keeps the implementation close to the current PowerShell app.
- Avoids Visual Studio/MSBuild/project deployment questions.

Tradeoff:

- PowerShell-hosted WPF is less type-safe and binding errors can be harder to debug.
- Compiled WPF is cleaner long-term but adds build and deployment complexity.

USER RESPONSE ANSWER:

- PowerShell-hosted WPF with runtime-loaded XAML.

## DP-002 - PowerShell Runtime Fallback

Status: `UNDECIDED`

Question:

Should the WPF launcher continue to prefer `pwsh.exe` PowerShell 7.5.2, or should it probe WPF availability and fall back to Windows PowerShell 5.1 if WPF assemblies fail to load under PowerShell 7?

Recommended default:

- Prefer `pwsh.exe`, but add a WPF assembly-load probe and fallback to `powershell.exe` if PowerShell 7 cannot load WPF on the target machine.

Reason:

- The current app prefers PowerShell 7.
- WPF availability can be more sensitive than WinForms depending on installed desktop runtime.

Tradeoff:

- Fallback logic adds complexity.
- Windows PowerShell 5.1 has older language/runtime behavior.

USER RESPONSE ANSWER:

- Prefer `pwsh.exe`, but add a WPF assembly-load probe and fallback to `powershell.exe` if PowerShell 7 cannot load WPF on the target machine.

## DP-003 - Target Folder

Status: `UNDECIDED`

Question:

Should the WPF rewrite be built in a sibling folder (`Scripts\Network_Monitor_WPF`) first, or replace `Scripts\Network_Monitor` in place?

Recommended default:

- Build in `Scripts\Network_Monitor_WPF` first.

Reason:

- Keeps the passing WinForms app available for comparison and fallback.
- Avoids breaking current tool launcher integration while WPF is being tested.

Tradeoff:

- Later migration step needed to switch launcher path or replace old implementation.

USER RESPONSE ANSWER:

- Build in `Scripts\Network_Monitor_WPF` first.

## DP-004 - XAML File Strategy

Status: `UNDECIDED`

Question:

Should XAML live in separate `.xaml` files under `Views`, or be embedded as here-strings inside PowerShell scripts?

Recommended default:

- Separate XAML files under `Views`.

Reason:

- Cleaner layout editing.
- Better separation of UI and logic.
- Easier for a fresh session to inspect visual structure.

Tradeoff:

- More files to copy to the target machine.
- Runtime XAML loading needs robust relative path handling.

USER RESPONSE ANSWER:

- Separate XAML files under `Views`.

## DP-005 - Window Chrome Implementation

Status: `UNDECIDED`

Question:

Should the WPF custom title bar use `System.Windows.Shell.WindowChrome`, manual `Window.DragMove()` plus resize handling, or native `SendMessage` hit testing?

Recommended default:

- Try WPF `WindowChrome` first.
- Use manual/native fallback only if it does not behave correctly under the chosen PowerShell host.

Reason:

- `WindowChrome` preserves native-ish resize and maximize behavior while allowing custom title content.

Tradeoff:

- `WindowChrome` can be finicky with custom hit test regions and title-bar buttons.
- Manual native handling may be more predictable but more code.

USER RESPONSE ANSWER:

- Try WPF `WindowChrome` first.
- Use manual/native fallback only if it does not behave correctly under the chosen PowerShell host.

## DP-006 - WPF DataGrid Versus Custom ItemsControl

Status: `UNDECIDED`

Question:

Should the main monitor use WPF `DataGrid`, or a custom `ItemsControl`/Grid layout?

Recommended default:

- Use WPF `DataGrid`.

Reason:

- Current app needs column reorder, resize, visibility, headers, scrolling, and persisted widths.
- `DataGrid` provides those with less custom code.

Tradeoff:

- Styling WPF `DataGrid` can be verbose.
- Custom `ItemsControl` can look cleaner but would require hand-building column resize/reorder behavior.

USER RESPONSE ANSWER:

- Use WPF `DataGrid`.

## DP-007 - Presentation Values: Brushes Or Hex Strings

Status: `UNDECIDED`

Question:

Should PowerShell presentation objects expose WPF `SolidColorBrush` instances, hex strings, or resource keys?

Recommended default:

- Expose WPF brushes for direct binding.

Reason:

- Avoids writing converters.
- Keeps PowerShell-hosted WPF simpler.

Tradeoff:

- Brush objects must be created/frozen/accessed on the correct dispatcher where applicable.
- Hex/resource keys can be easier to serialize/debug but require converters or style lookup.

USER RESPONSE ANSWER:

- Expose WPF brushes for direct binding.

## DP-008 - View Model Type

Status: `UNDECIDED`

Question:

Should row/settings view models be plain `PSCustomObject` instances, PowerShell classes with `INotifyPropertyChanged`, or small compiled C# helper classes created with `Add-Type`?

Recommended default:

- Start with `PSCustomObject` plus explicit row refresh/rebinding if sufficient.
- Use small C# `INotifyPropertyChanged` helper only if WPF binding refresh becomes unreliable.

Reason:

- Keeps code compact and close to current PowerShell style.

Tradeoff:

- WPF bindings update more reliably with `INotifyPropertyChanged`.
- Adding C# helper classes introduces in-memory compilation and more complexity.

USER RESPONSE ANSWER:

- Start with `PSCustomObject` plus explicit row refresh/rebinding if sufficient.
- Use small C# `INotifyPropertyChanged` helper only if WPF binding refresh becomes unreliable.

## DP-009 - Settings Numeric Controls

Status: `UNDECIDED`

Question:

Should WPF settings numeric fields be plain `TextBox` controls with validation, or custom spinner controls?

Recommended default:

- Use plain dark-styled `TextBox` controls with numeric validation and Enter/lost-focus commit.

Reason:

- WPF has no built-in `NumericUpDown`.
- Plain text boxes keep dependencies at zero.

Tradeoff:

- Less convenient than spinner controls.
- Needs careful invalid partial input handling.

USER RESPONSE ANSWER:

- Use plain dark-styled `TextBox` controls with numeric validation and Enter/lost-focus commit.

## DP-010 - Main Window Default Size

Status: `UNDECIDED`

Question:

Should WPF keep the generated default config size of `1040 x 270`, the screenshot/runtime size of `1120 x 330`, or compute a fresh default from visible columns and target count?

Recommended default:

- Compute first-run default from visible columns and enabled target count, with minimum `820 x 260`.
- Use `1040 x 270` as generated config baseline.

Reason:

- Current app already calculates a default size to avoid clipping.
- Screenshot size may include a user-resized runtime window.

Tradeoff:

- Screenshot match is closer at `1120 x 330`.
- Compact first-run utility feel is closer at calculated/default size.

USER RESPONSE ANSWER:

- Compute first-run default from visible columns and enabled target count, with minimum `820 x 260`.
- Use `1040 x 270` as generated config baseline.

## DP-011 - Settings Window Resizability

Status: `UNDECIDED`

Question:

Should the WPF settings window remain fixed-size like the current WinForms settings window, or become resizable?

Recommended default:

- Keep fixed-size initially.

Reason:

- Current app fixed settings at `800 x 470`.
- Less layout work and less risk.

Tradeoff:

- A resizable settings window could be nicer for large target lists.

USER RESPONSE ANSWER:

- Keep fixed-size initially.

## DP-012 - Config Location For Multi-User Network Share

Status: `UNDECIDED`

Question:

Should the WPF app keep config next to the script, or move mutable config to a per-user location to avoid shared network-folder collisions?

Recommended default:

- Keep config next to the script.

Reason:

- This is the explicit current requirement and current app behavior.

Tradeoff:

- On shared network directories, different users/machines can overwrite each other's window placement/settings.
- Per-user config is more Windows-standard but changes expected behavior.

USER RESPONSE ANSWER:

- Keep config next to the script.

## DP-013 - Existing WinForms App Retirement

Status: `UNDECIDED`

Question:

After WPF is verified, should the WinForms implementation be deleted/replaced, kept as fallback, or archived?

Recommended default:

- Keep WinForms as fallback until WPF is verified on the target air-gapped machine.

Reason:

- Current WinForms app passes tests and is useful for comparison.

Tradeoff:

- Keeping both may create maintenance ambiguity.

USER RESPONSE ANSWER:

- Keep WinForms as fallback until WPF is verified on the target air-gapped machine.

## DP-014 - Launcher Catalog Integration Timing

Status: `UNDECIDED`

Question:

Should ToolLauncher integration be updated during the WPF rewrite, or only after standalone WPF target-PC testing?

Recommended default:

- Defer ToolLauncher integration until standalone WPF testing passes.

Reason:

- Original requirement was standalone first.

Tradeoff:

- The WPF app will not be launched from the main launcher until a later step.

USER RESPONSE ANSWER:

- Defer ToolLauncher integration until standalone WPF testing passes.

## DP-015 - Pixel Match Strictness

Status: `UNDECIDED`

Question:

How strict should visual matching be against `Network_Monitor_Winform_UI.png`?

Recommended default:

- Match layout, palette, typography, column widths, and visual hierarchy closely, but allow WPF-native rendering differences.

Reason:

- WPF text/grid rendering will not match WinForms exactly.
- Behavior and operator continuity matter more than exact pixels.

Tradeoff:

- If pixel match is strict, implementation time increases and may produce brittle styling.

USER RESPONSE ANSWER:

- Match layout, palette, typography, column widths, and visual hierarchy closely, but allow WPF-native rendering differences.

## DP-016 - Add-Type C# Helpers

Status: `UNDECIDED`

Question:

Is it acceptable to use small C# helper classes via `Add-Type -TypeDefinition` for `INotifyPropertyChanged`, observable row models, or window interop?

Recommended default:

- Avoid until needed.
- Allow only small, local helper classes if they reduce complexity materially.

Reason:

- Current app already uses small in-memory C# for WinForms resize/native behavior.
- But hand-copyability and debugging remain priorities.

Tradeoff:

- C# helpers improve WPF binding correctness.
- They increase code complexity and introduce in-memory compilation.

USER RESPONSE ANSWER:

- Avoid until needed.
- Allow only small, local helper classes if they reduce complexity materially.