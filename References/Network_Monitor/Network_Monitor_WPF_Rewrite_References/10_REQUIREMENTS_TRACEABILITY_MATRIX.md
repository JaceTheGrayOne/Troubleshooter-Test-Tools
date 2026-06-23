# Requirements Traceability Matrix

Generated: 2026-06-23

## Purpose

This matrix ties current requirements to WPF rewrite implementation areas and verification checks. Use it as a final audit before claiming the rewrite is complete.

## Launch And Runtime

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Standalone app independent of ToolLauncher | entry script, shims under `Scripts\Network_Monitor_WPF` | manual direct/CMD/VBS launch |
| Hidden no-console shim launch | VBS/CMD shims | manual VBS launch |
| STA required | entry script | automated assembly/window construction |
| Prefer PowerShell 7 with WPF probe and Windows PowerShell fallback | entry/VBS | manual launch and fallback probe test |
| All paths relative to app root | entry/config/log modules | config tests from temp root |
| Fatal startup errors visible/logged | entry/logging/WPF exception handlers | forced startup failure test |

## Main Window

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Exact title text | MainWindow.xaml/script | construction/manual check |
| Appears in taskbar | window property | manual launch |
| Custom dark title bar | XAML/theme/window chrome | visual check |
| Resizable | window chrome | manual resize |
| Drag title bar | title event/window chrome | manual drag |
| Double-click maximize/restore | title event/window chrome | manual double-click |
| Minimize button | title command | manual click |
| Maximize/restore button and icon | title command/state | manual click |
| Close exits completely | close handler | manual process/window check |
| First run bottom-left | placement helper | config/first-run manual |
| Does not cover taskbar | placement helper | manual check |
| Saved bounds persist | placement/config | manual relaunch |
| Off-screen fallback | placement helper | config test/manual |
| Always on top persists | config/window topmost | manual relaunch |

## Main Title Buttons

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Settings cog opens settings | title command/settings manager | manual |
| Cog focuses existing settings | settings manager | manual |
| Cog active blue while settings open | title button state | manual |
| Reset clears state/history | reset command/state rows | automated/manual |
| Reset starts fresh cycle | reset command/ping engine | manual |
| Pin active blue when pinned | title button state | manual |
| Pin neutral when unpinned | title button state | manual |
| Minimize/maximize/close behavior | title commands | manual |

## Main Grid

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Grid-only content | MainWindow.xaml | visual |
| Default visible columns | column builder/config | automated/manual |
| TTL/Bytes hidden by default | column builder/config | automated/manual |
| Rows in target order | row collection builder | automated/manual |
| Disabled targets hidden | target edit/row rebuild | settings manual |
| No sorting | DataGrid column properties | manual |
| Column resize persists | column events/config debounce | automated/manual |
| Column reorder persists | column events/config debounce | automated/manual |
| Column min widths | column definitions | automated/manual |
| Horizontal scroll when needed | DataGrid | manual |
| Selection preserves health colors | styles/templates | automated/manual |

## Monitoring

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Auto-start on window show | MainWindow loaded handler | manual |
| SendPingAsync | ping engine | code/test |
| One ping per enabled target per cycle | ping engine | ping test |
| Concurrent pings | ping engine | code/test |
| UI remains responsive | dispatcher design | manual |
| Skip busy cycles | ping engine | automated/manual |
| Skipped cycles invisible | ping/state | automated/manual |
| Attempted timeout is failed sample | ping engine/state | automated/manual |
| Dispose Ping objects | ping engine | code audit |
| Generation discard on reset/config change | ping engine/state | automated |

## Health And Presentation

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Status UP until down threshold | MonitorState/Presentation | automated |
| DOWN after configured failures | MonitorState/Presentation | automated/manual |
| Green/yellow/orange/red precedence | MonitorState/Presentation | automated |
| RTT latest result text | MonitorState/Presentation | automated/manual |
| RTT thresholds configurable | config/settings/presentation | settings tests |
| Loss rolling history percent | MonitorState | automated |
| Loss thresholds configurable | config/settings/presentation | settings tests |
| History green/red/yellow bars | row view model/template | automated/manual |
| TTL/Bytes from latest success | MonitorState/Presentation | automated/manual |

## Settings

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Non-modal settings | SettingsWindow manager | manual |
| One settings instance | SettingsWindow manager | manual |
| Owned/above main | Window owner/topmost | manual |
| Monitoring continues | ping engine unaffected | manual |
| Settings topmost mirrors pinned main window | SettingsWindow manager/window state | manual settings window checks |
| Settings close button closes settings only | SettingsWindow.xaml/window close handler | manual settings window checks |
| Settings cog active state clears on settings close | main title button state/settings close handler | manual settings window checks |
| Fixed-size dark tabbed settings window | SettingsWindow.xaml/styles | visual/manual settings window checks |
| Required tabs: Targets, Columns, Timing, Health, General | SettingsWindow.xaml/script | automated construction check/manual settings checks |
| Inline success/error feedback | feedback helper | manual settings checks |
| Enter/lost-focus numeric commit | commit helpers | manual settings checks |
| Invalid numeric/text edit rollback | commit helpers/config validation | manual settings checks/config tests |
| Checkbox click commit with rollback on failure | commit helpers/settings handlers | manual settings checks |
| Transactional config edits through full validation | Config.ps1/settings handlers | automated config tests/manual settings checks |
| Target add creates unique enabled target using default address/color | target settings handlers | manual Targets tab checks |
| Target add resets monitor state and updates row collection/grid | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Target delete removes selected target | target settings handlers | manual Targets tab checks |
| Target delete blocks deleting the last enabled target | target settings handlers/validation feedback | manual Targets tab checks |
| Target delete resets monitor state and updates row collection/grid | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Target move up/down reorders selected target and preserves selection intent | target settings handlers | manual Targets tab checks |
| Target move resets monitor state and updates row order/grid | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Target enable/disable commits immediately | target settings handlers | manual Targets tab checks |
| Target disable blocks disabling the last enabled target | target settings handlers/validation feedback | manual Targets tab checks |
| Target name edit rejects blank names | target settings handlers/validation feedback | manual Targets tab checks |
| Target name edit rejects duplicate names case-insensitively | target settings handlers/validation feedback | manual Targets tab checks |
| Target name edit resets monitor state and updates row identity/order | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Target address edit rejects invalid IPv4/hostname values | target settings handlers/validation feedback | manual Targets tab checks |
| Target address edit resets monitor state and updates displayed address | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Target color edit rejects invalid non-`#RRGGBB` values | target settings handlers/validation feedback | manual Targets tab checks |
| Target color edit normalizes committed color and updates color preview | target settings handlers/color preview | manual Targets tab checks |
| Target color edit resets monitor state and updates node foreground | target settings handlers/WpfBindings | row update check/manual Targets tab checks |
| Column visibility toggles commit immediately | column settings handlers | column persistence check/manual Columns tab checks |
| Column visibility blocks hiding the final visible column | column settings handlers/validation feedback | column persistence check/manual Columns tab checks |
| Column visibility applies to main grid and persists | column settings handlers/WpfBindings | column persistence check/manual relaunch |
| Column order move up/down persists and applies to main grid | column settings handlers/WpfBindings | column persistence check/manual Columns tab checks |
| Selected column width editor follows selected column | column settings handlers | manual Columns tab checks |
| Selected column width respects per-column/min/max constraints | column settings handlers/column definitions | column persistence check/manual Columns tab checks |
| Selected column width persists and applies to main grid | column settings handlers/WpfBindings | column persistence check/manual relaunch |
| Refresh interval setting range and commit | timing settings handlers/config validation | manual Timing tab checks/config tests |
| Refresh interval change resets monitor state/timing | timing settings handlers/ping timer | manual Timing tab checks/ping cycle check |
| Ping timeout setting range and commit | timing settings handlers/config validation | manual Timing tab checks/config tests |
| Ping timeout change resets monitor state | timing settings handlers/ping engine | manual Timing tab checks/ping cycle check |
| History length setting range and commit | timing settings handlers/config validation | manual Timing tab checks/config tests |
| History length change resets monitor state/history display | timing settings handlers/WpfBindings | row update check/manual Timing tab checks |
| Auto-start toggle persists | timing settings handlers/config | manual Timing tab checks/manual relaunch |
| Enabling auto-start while stopped starts monitoring and triggers a fresh cycle | timing settings handlers/ping engine | manual Timing tab checks |
| Health failure/loss threshold fields commit and reset monitor state | health settings handlers/MonitorState | manual Health tab checks/config tests |
| RTT threshold fields commit and reset monitor state | health settings handlers/Presentation | manual Health tab checks/config tests |
| RTT threshold ordering rejects invalid green/yellow/orange order | Validation.ps1/settings rollback | manual Health tab checks/config tests |
| Loss threshold fields commit and reset monitor state | health settings handlers/Presentation | manual Health tab checks/config tests |
| Loss threshold ordering rejects invalid yellow/orange order | Validation.ps1/settings rollback | manual Health tab checks/config tests |
| Always-on-top toggle persists and applies immediately | general settings handlers/window state | manual General tab checks/manual relaunch |
| Debug logging toggle persists and affects routine diagnostics | general settings handlers/Logging.ps1 | manual General tab checks/debug logging checks |
| Reset Window Position moves main window to default bottom-left placement and persists bounds | general settings handlers/window placement | manual General tab checks/manual relaunch |
| Reset to Defaults prompts for confirmation | general settings handlers/message box | manual General tab checks |
| Reset to Defaults cancel leaves config unchanged | general settings handlers/config | manual General tab checks/config comparison |
| Reset to Defaults confirm restores defaults, resets monitor state, reapplies topmost/columns/location, restarts when auto-start, and closes settings | general settings handlers/config/state/window manager | manual General tab checks/manual relaunch |

## Config

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| JSON config next to script | Config.ps1 | automated |
| Auto-create on first run | Config.ps1 | automated/manual |
| Strict whole-file validation | Validation/Config | automated |
| Invalid backup timestamp | Config.ps1 | automated/manual |
| Atomic save | Config.ps1 | automated/code audit |
| No schema version | default config | config test |
| Default targets/thresholds | default config | automated |
| Debug off no routine logs | Logging.ps1 | manual |
| Startup error log exception | Logging/entry | forced failure |

## Visual Design

| Requirement | WPF Implementation Area | Verification |
|---|---|---|
| Matches dark screenshot | XAML resources/styles | visual |
| Title bar 46-ish height | XAML layout | visual |
| Header 38-ish height | DataGrid style | visual |
| Row 52-ish height | DataGrid style | visual |
| Same palette | resources | visual/code |
| Same fonts | resources/styles | visual/code |
| Status dot plus text | Status template | visual |
| 12 history bars default | History template/state | visual |
| Settings dark tabbed UI | Settings XAML/styles | visual |

## Decision Trace

Implementation must follow:

`12_RESOLVED_WPF_DECISIONS.md`

The raw user answers remain in `08_WPF_DECISION_POINTS_UNDECIDED.md`, but that file is intentionally left unmodified.

Do not treat `Status: UNDECIDED` labels in `08_WPF_DECISION_POINTS_UNDECIDED.md` as unresolved work. The resolved implementation choices are in `12_RESOLVED_WPF_DECISIONS.md`.
