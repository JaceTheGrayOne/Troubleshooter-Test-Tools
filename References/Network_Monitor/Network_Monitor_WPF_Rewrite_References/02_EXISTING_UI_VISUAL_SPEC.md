# Existing UI Visual Spec

Generated: 2026-06-23

## Purpose

This document captures the current WinForms UI design that the WPF rewrite should visually approximate.

Reference image:

`Network_Monitor_Winform_UI.png`

Image metadata:

- `1120 x 330`
- Approximate 96 DPI
- Format `32bpp ARGB`

## Overall Visual Direction

The app should feel like a compact bespoke Troubleshooter Test Tools utility:

- Dark, utilitarian, information-dense.
- No marketing/landing-page styling.
- No decorative cards.
- No gradient orbs or visual filler.
- Grid-first and operator-focused.
- High contrast status colors.
- Quiet title bar with clear icon commands.

The WPF rewrite should look close to the screenshot, but WPF should use native layout, templates, and styles rather than GDI painting.

## Current Main Window Composition

At `1120 x 330`, the screenshot shows:

- Full-width title bar at the top.
- Grid directly below title bar.
- Empty dark background below the grid because the configured window is taller than the three-row grid.
- No footer or bottom controls.
- No summary strip.
- No warning banner.

Main window background:

- Very dark near-black teal/charcoal.

Current app constants:

- Title bar height: `46`
- Grid header height: `38`
- Grid row height: `52`
- Main minimum size: `820 x 260`

The screenshot content height is:

- Title bar: about `46`
- Header: about `38`
- Rows: `3 x 52 = 156`
- Visible grid total: about `240`
- Remaining bottom area in screenshot: about `90`

## Main Theme Colors

Current WinForms theme colors from `Initialize-NMTheme` in `Scripts\Network_Monitor\Scripts\UiHelpers.ps1`:

| Name | Hex | Usage |
|---|---:|---|
| `Window` | `#080d10` | Main/settings window background |
| `TitleBar` | `#101619` | Custom title bar |
| `TitleBarHover` | `#1b2429` | Icon hover |
| `TitleBarPressed` | `#263239` | Icon pressed |
| `Surface` | `#0d1417` | Settings surfaces |
| `SurfaceAlt` | `#151d22` | Headers/alternate surface |
| `Grid` | `#0b1215` | Grid row background |
| `GridAlt` | `#0f171b` | Alternating row background |
| `GridLine` | `#333b42` | Grid lines |
| `Border` | `#4b5258` | Window border |
| `Text` | `#f3f5f7` | Primary text/icons |
| `Muted` | `#aeb7bf` | Muted labels/placeholders |
| `Accent` | `#5db8ff` | Active title icons |
| `AccentDark` | `#0078d4` | Primary settings buttons |
| `Green` | `#61e243` | Healthy ping/status/history |
| `Yellow` | `#f5cf4f` | Unfilled history/dropped health |
| `Orange` | `#ff9a3d` | Degraded health |
| `Red` | `#ff4438` | Down/failure/timeout |
| `Disabled` | `#777d82` | Disabled/muted state |

WPF rewrite:

- Use these exact hex values as a central resource dictionary unless a decision explicitly changes them.
- Use one source of truth for colors.

## Current Fonts

Current WinForms theme fonts:

| Name | Family | Size | Weight/Style | Usage |
|---|---|---:|---|---|
| `Title` | `Segoe UI` | `12` | Regular | Main/settings title bar |
| `GridHeader` | `Segoe UI` | `11` | Bold | Grid headers |
| `Grid` | `Consolas` | `11` | Regular | Main grid data |
| `GridBold` | `Consolas` | `11` | Bold | Node and status |
| `SettingsTitle` | `Segoe UI` | `11` | Bold | Settings title-ish labels |
| `Settings` | `Segoe UI` | `9` | Regular | Settings controls |
| `SettingsBold` | `Segoe UI` | `9` | Bold | Settings section labels |
| `Mono` | `Consolas` | `9` | Regular | Mono settings fields if needed |

WPF rewrite:

- Use `Segoe UI` and `Consolas`.
- Match visual size in WPF device-independent pixels as closely as reasonable.
- Do not scale font size with viewport width.
- Letter spacing should remain default/zero.

## Title Bar Visuals

Main title bar:

- Height about `46`.
- Background `#101619`.
- Left title text begins around `22px` from left.
- Title text: `Network Monitor - Troubleshooter Test Tools`.
- Title text color `#f3f5f7`.
- No app icon.
- Right-aligned icon button cluster.

Title button visuals:

- Icon-only.
- Approximate button box `38 x 38`.
- Margin around `3,4,3,4`.
- Hover background `#1b2429`.
- Pressed background `#263239`.
- Neutral icon color `#f3f5f7`.
- Active icon color `#5db8ff`.
- Separator before minimize/maximize/close.

Button order:

1. Cog/settings.
2. Refresh/reset curled arrow.
3. Pin.
4. Vertical separator.
5. Minimize dash.
6. Maximize square or restore overlapping squares.
7. Close X.

WPF icon recommendation:

- Use inline XAML `Path` geometries or small vector drawings.
- Do not use external icon packages.
- Do not depend on emoji/font glyph icons.
- Tooltips should name each icon.

## Main Grid Visuals

Grid position:

- Directly below title bar.
- Starts at left edge.
- Ends around x=`1040` in the 1120 px screenshot because current visible column widths sum to about 1040.
- Does not force columns to stretch to fill the full window width.

Current default visible column widths:

| Column | Width | Min Width |
|---|---:|---:|
| `Node` | `120` | `100` |
| `Address` | `250` | `190` |
| `Status` | `150` | `130` |
| `RTT` | `130` | `105` |
| `Loss` | `130` | `105` |
| `History` | `260` | `180` |

Optional hidden column widths:

| Column | Width | Min Width |
|---|---:|---:|
| `TTL` | `90` | `70` |
| `Bytes` | `95` | `80` |

Header:

- Background `#151d22`.
- Header text `#f3f5f7`.
- Font `Segoe UI` bold around 11 pt.
- Left padding about `14`.
- Vertical grid lines visible.

Rows:

- Alternating backgrounds:
  - Even: `#0b1215`
  - Odd: `#0f171b`
- Row height about `52`.
- Data font `Consolas` around 11 pt.
- Cell text left padding about `14`.
- Thin grid lines `#333b42`.
- No row headers.
- No visible selected-row color shift in normal operation.

## Main Grid Cell Visuals

Node:

- Text is target name.
- Text uses target color:
  - SMS: magenta `#ff40e6`
  - MPS: magenta `#ff40e6`
  - MPG: cyan `#27d9e6`
- Bold monospaced.

Address:

- Text is configured address as entered.
- Primary text color.
- Monospaced.

Status:

- Custom visual: colored circular dot plus bold status text.
- Dot size currently about `16`.
- Dot left offset currently about `18`.
- Text begins after dot plus about `12`.
- Dot and text use health color.
- Screenshot shows red dot and red `DOWN` text.

RTT:

- Text examples: `NA`, `timeout`, `3 ms`.
- Uses RTT health color.
- Screenshot shows red `timeout`.

Loss:

- Text examples: `0.0%`, `100.0%`.
- Uses loss health color.
- Screenshot shows red `100.0%`.

History:

- Visual sample bars, not text.
- Default length `12`.
- Bars are narrow vertical rectangles.
- Failed samples red.
- Successful samples green.
- Missing/unfilled samples yellow.
- In screenshot, each row shows 12 red bars.

WPF template guidance:

- `Status` should use a `DataTemplate` with an `Ellipse` and `TextBlock`.
- `History` should use an `ItemsControl` with a horizontal items panel and rectangular bars.
- Use fixed/stable dimensions for dots and bars to prevent layout shift.

## Settings Window Visuals

Current settings window:

- Size `800 x 470`.
- Minimum `760 x 430`.
- Fixed/not resizable.
- Borderless custom dark window.
- Title: `Network Monitor Settings`.
- One close icon in title bar.
- Same dark title-bar visual language as main window.
- Content starts below title bar.
- Tab control at approximately `12,58` with size `772 x 342`.
- Feedback label at approximately bottom `14,412`.

Settings tabs:

- `Targets`
- `Columns`
- `Timing`
- `Health`
- `General`

Tab visuals:

- Owner-drawn in WinForms.
- Fixed tab width about `153`.
- Tab height about `28`.
- Active tab background `#0d1417`.
- Inactive tab background `#101619`.
- Active text `#f3f5f7`.
- Inactive text `#aeb7bf`.
- Tab borders `#333b42`.

WPF rewrite:

- Use styled `TabControl` with the same tab names/order.
- Keep compact fixed-height tabs.
- Avoid nested cards.

## Settings - Targets Visuals

Current layout:

- Grid at left, about `570 x 272`.
- Buttons stacked at right:
  - `Add`
  - `Delete`
  - `Move Up`
  - `Move Down`
- Color preview label and preview box under buttons.

Target grid columns:

- `Enabled`, width `70`, checkbox.
- `Node`, width `120`.
- `Address`, width `180`.
- `Color`, width `110`.

Color preview:

- Small bordered rectangle.
- Shows selected target color.

WPF rewrite:

- Preserve same controls and approximate layout.
- Use WPF `DataGrid` or list editor with checkbox/text columns.
- Provide clear row selection and color preview.

## Settings - Columns Visuals

Current layout:

- Left: `Visible Columns` checked list.
- Middle: `Column Order` list.
- Right: Move Up/Move Down buttons.
- Bottom/middle: selected width numeric field.

WPF rewrite:

- Use checkboxes/listbox for visibility.
- Use listbox for order.
- Use numeric textbox/spinner equivalent for selected width.
- Keep one-column-at-a-time width editing unless a later decision changes it.

## Settings - Timing Visuals

Current controls:

- Label plus numeric control rows:
  - `Refresh interval (ms)`
  - `Ping timeout (ms)`
  - `History length`
- Checkbox:
  - `Auto-start monitoring on launch`

WPF rewrite:

- Use aligned label/input rows.
- Keep compact vertical spacing.
- Commit on Enter/lost focus, not every keystroke.

## Settings - Health Visuals

Current layout:

- Left column: Health section.
- Right column top: RTT section.
- Right column lower: Loss section.
- Explicit visible labels and aligned numeric fields.

WPF rewrite:

- Preserve two-column layout.
- Keep labels visible and aligned.
- Do not hide threshold meanings behind tooltips only.

## Settings - General Visuals

Current controls:

- Checkbox `Always on top`.
- Checkbox `Debug logging`.
- Button `Reset Window Position`.
- Primary button `Reset to Defaults`.

WPF rewrite:

- Preserve controls and ordering.
- Reset to Defaults must use confirmation dialog.

## Interaction Visual States

Main/settings title icon buttons:

- Neutral = white.
- Hover = darker title hover background.
- Pressed = title pressed background.
- Active = blue icon.

Grid selection:

- Must not turn RTT/Loss/Status health text white merely because the cell or row is selected.
- Selected/current cell should preserve presentation foreground colors.

Validation feedback:

- Error feedback should be red.
- Non-error saved feedback should be muted.

## Pixel Matching Expectations

The WPF rewrite should match these as close as reasonable while allowing WPF-native rendering differences:

- Overall dark palette.
- Title bar height.
- Grid-only main layout.
- Column widths.
- Row/header heights.
- Text families and approximate sizes.
- Title button order and icon intent.
- Status dot plus text.
- History bars count, spacing, and colors.

The WPF rewrite may improve:

- DPI scaling consistency.
- Text rendering quality.
- Layout behavior during resize.
- Template cleanliness.
- Settings control alignment.

Do not sacrifice required behavior for pixel-perfect reproduction.
