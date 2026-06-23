I asked ChatGPT Pro this:

"So I am building a tool on an Air-Gapped enterprise computer without access to the internet that has Powershell 7 and Powershell 5. Could I have built this tool: https://github.com/JaceTheGrayOne/Troubleshooter-Test-Tools in WPF instead of WinForms? What would the difference be in terms of total code size, UX usability, and feature set?"

and this was the response I got:
```
Yes. **You could have built that repo in WPF instead of WinForms**, assuming the air-gapped machine is Windows and WPF assemblies are available to the PowerShell version you run.

Your repo’s README currently describes it as a no-install Windows 11 launcher using Windows PowerShell and **.NET Windows Forms**, with `ToolLauncher.ps1` opening a dark GUI, `tools.json` controlling available tools, and `ToolRuntime.ps1` handling process/log behavior. ([GitHub][1]) The Network Monitor entry script also explicitly loads `System.Windows.Forms` and `System.Drawing`, then loads its own UI/config/ping modules. ([GitHub][2])

## Bottom line

For your specific air-gapped enterprise troubleshooting tools:

| Category                                   | WinForms version                                                      | WPF version                                                             |
| ------------------------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **Could it do the same job?**              | Yes                                                                   | Yes                                                                     |
| **Offline/no-install friendly?**           | Very good                                                             | Also good, but slightly more sensitive to WPF/.NET availability         |
| **Code size**                              | Usually shorter for simple forms; longer for custom-drawn/polished UI | Often cleaner for layout/styling, but not always fewer total lines      |
| **UX polish**                              | Functional, old-school, harder to make elegant                        | Better for dashboards, cards, resizing, styles, icons, visual hierarchy |
| **Ease of debugging on an air-gapped box** | Easier                                                                | Harder, especially with XAML/binding errors                             |
| **Best fit for your launcher**             | Good                                                                  | Probably better long-term                                               |
| **Best fit for your Network Monitor**      | Good enough and reliable                                              | Better-looking/cleaner UX, but more complex to author                   |

## Does WPF require compiling?

**No, not if you use it from PowerShell with runtime-loaded XAML.**

A PowerShell WPF script can do something like:

```powershell
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
```

Then load a `.xaml` file or XAML string at runtime.

That means you could still have:

```text
Run_Tool.cmd
ToolLauncher.ps1
ToolLauncher.xaml
Scripts\
Tools\
Logs\
```

No Visual Studio project, no `.exe`, no build step.

However, if you include custom C# helper classes with `Add-Type -TypeDefinition`, PowerShell does compile that C# into an in-memory assembly. Microsoft’s `Add-Type` docs describe loading existing assemblies as well as compiling supplied source code into an in-memory assembly. ([Microsoft Learn][3]) Your current Network Monitor already does a small version of this for `NetworkMonitorForm` and native window behavior. ([GitHub][4])

## Code size difference

For your **ToolLauncher**, WPF probably would have been cleaner.

The WinForms version has to manually create controls, set locations, sizes, colors, anchors, borders, fonts, and event handlers. That tends to produce a lot of repetitive code.

WPF would move much of that into XAML:

```xml
<Grid>
  <Grid.ColumnDefinitions>
    <ColumnDefinition Width="260"/>
    <ColumnDefinition Width="*"/>
  </Grid.ColumnDefinitions>

  <ListBox Grid.Column="0"/>
  <StackPanel Grid.Column="1"/>
</Grid>
```

For the launcher, I would expect WPF to produce:

| Area                          | Likely result                                 |
| ----------------------------- | --------------------------------------------- |
| Layout code                   | Smaller / cleaner                             |
| Styling code                  | Much smaller if centralized in XAML resources |
| Event logic                   | About the same                                |
| Dynamic tool-field generation | Similar complexity                            |
| Total size                    | Maybe slightly smaller, maybe similar         |

For the **Network Monitor**, the answer is less obvious. The current version uses a `DataGridView`, custom cell painting, custom icons, a borderless window, custom titlebar buttons, saved window placement, configurable columns, and live status rendering. ([GitHub][5])

In WPF, some of that would become cleaner because WPF has stronger layout, styling, templates, and data binding. Microsoft describes WPF as a Windows UI framework with XAML, controls, data binding, layout, graphics, animation, styles, templates, documents, media, text, and typography. ([Microsoft Learn][6]) But you would also add WPF-specific complexity: XAML structure, binding setup, data contexts, observable collections, converters, and event wiring from PowerShell.

So for the Network Monitor:

| Part               | WinForms                        | WPF                                                      |
| ------------------ | ------------------------------- | -------------------------------------------------------- |
| Grid/table         | `DataGridView`, straightforward | `DataGrid`, `ListView`, or `ItemsControl`; more flexible |
| Custom status dots | Manual GDI+ drawing             | Ellipse/style/template; cleaner                          |
| History bars       | Manual cell painting            | DataTemplate/ItemsControl; cleaner visually              |
| Theme colors       | Manually assign per control     | Central resource dictionary; much cleaner                |
| Resizing layout    | Anchors/docking/manual          | `Grid`, `DockPanel`, `StackPanel`; better                |
| Custom titlebar    | Manual native calls             | Still custom, but WPF has better styling options         |
| Total code         | Often similar                   | Could be cleaner, not guaranteed shorter                 |

## UX usability difference

WPF would probably give a better UX for the kind of tool you are building.

WinForms is good for this:

```text
[Tool List] [Parameters] [Run] [Stop] [Log Output]
```

WPF is better for this:

```text
┌ Network Monitor ───────────────────────────────┐
│  SMS   ● ONLINE   4 ms   ▁▁▁▁▁▁▁▁▁▁▁▁          │
│  MPS   ● ONLINE   3 ms   ▁▁▁▁▁▁▁▁▁▁▁▁          │
│  MPG   ● DOWN     ---    ▆▆▆▆▆▆▆▆▆▆▆▆          │
└────────────────────────────────────────────────┘
```

WPF would make it easier to build:

| UX feature                    | WinForms                      | WPF                                |
| ----------------------------- | ----------------------------- | ---------------------------------- |
| Card/cubby/dashboard layout   | Possible, but manual          | Much better                        |
| Dark theme consistency        | Manual per control            | Centralized styles                 |
| Resizable/adaptive layout     | Okay                          | Better                             |
| Custom icons                  | Manual drawing or image files | Vector paths, templates, resources |
| Visual status indicators      | Manual drawing                | Native shapes/templates            |
| DPI/high-res display behavior | Can be annoying               | Generally better                   |
| Data-driven UI                | Possible                      | More natural                       |

Microsoft describes XAML as declarative markup that separates the UI definition from runtime logic, with visible UI elements declared in XML-like markup. ([Microsoft Learn][7]) That separation is the main WPF advantage for your use case.

## Feature set difference

There is basically **no feature you used in WinForms that WPF could not also do**.

Your current tool does things like:

| Current feature           | WPF equivalent                                     |
| ------------------------- | -------------------------------------------------- |
| Tool launcher window      | WPF `Window`                                       |
| Left-side tool list       | `ListBox`, `TreeView`, or `ListView`               |
| Dynamic fields from JSON  | Generate controls dynamically or use DataTemplates |
| Run/Stop buttons          | WPF `Button`                                       |
| Log output box            | `TextBox`, `RichTextBox`, or custom log viewer     |
| Settings form             | Secondary WPF `Window`                             |
| Ping monitor table        | `DataGrid`, `ListView`, or custom `ItemsControl`   |
| Colored status indicators | `Ellipse`, `Border`, `TextBlock` styles            |
| Always-on-top             | `Window.Topmost`                                   |
| Borderless/custom window  | `WindowStyle=None`, custom titlebar                |
| Timed refresh             | `DispatcherTimer`                                  |
| Config file persistence   | Same PowerShell/JSON logic                         |

The main difference is not capability. It is **authoring style**.

WinForms is:

```text
Create object → set properties → add to parent → handle event
```

WPF is:

```text
Describe UI in XAML → bind data/state → style with resources → handle behavior in script
```

## My recommendation for your environment

For a **next-generation version**, especially if you want the Network Monitor to look like a polished dashboard with cards, status tiles, live history bars, cleaner resizing, and centralized themes, I would choose **WPF + XAML**.

[1]: https://github.com/JaceTheGrayOne/Troubleshooter-Test-Tools "GitHub - JaceTheGrayOne/Troubleshooter-Test-Tools: Test Tools for Electronics Troubleshooting · GitHub"
[2]: https://raw.githubusercontent.com/JaceTheGrayOne/Troubleshooter-Test-Tools/refs/heads/main/Scripts/Network_Monitor/Network_Monitor.ps1 "raw.githubusercontent.com"
[3]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/add-type?view=powershell-7.6 "Add-Type (Microsoft.PowerShell.Utility) - PowerShell | Microsoft Learn"
[4]: https://raw.githubusercontent.com/JaceTheGrayOne/Troubleshooter-Test-Tools/refs/heads/main/Scripts/Network_Monitor/Scripts/UiHelpers.ps1 "raw.githubusercontent.com"
[5]: https://raw.githubusercontent.com/JaceTheGrayOne/Troubleshooter-Test-Tools/refs/heads/main/Scripts/Network_Monitor/Scripts/MainForm.ps1 "raw.githubusercontent.com"
[6]: https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/ "What is Windows Presentation Foundation - WPF | Microsoft Learn"
[7]: https://learn.microsoft.com/en-us/dotnet/desktop/wpf/xaml/ "XAML language overview - WPF | Microsoft Learn"
```