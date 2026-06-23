Set shell = CreateObject("WScript.Shell")
Set filesystem = CreateObject("Scripting.FileSystemObject")

rootPath = filesystem.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = rootPath

Function Quote(value)
    Quote = """" & value & """"
End Function

Function ResolveCommand(name)
    On Error Resume Next
    Set exec = shell.Exec("cmd.exe /c where " & name)
    If Err.Number <> 0 Then
        Err.Clear
        ResolveCommand = ""
        Exit Function
    End If

    output = Trim(exec.StdOut.ReadAll)
    If output = "" Then
        ResolveCommand = ""
    Else
        lines = Split(output, vbCrLf)
        ResolveCommand = Trim(lines(0))
    End If
    On Error GoTo 0
End Function

Function ProbeWpfHost(path)
    probe = "try { Add-Type -AssemblyName PresentationFramework; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName WindowsBase; Add-Type -AssemblyName System.Xaml; [System.Windows.Window]::new() | Out-Null; exit 0 } catch { exit 42 }"
    commandLine = Quote(path) & " -NoProfile -ExecutionPolicy Bypass -STA -Command " & Quote(probe)
    exitCode = shell.Run(commandLine, 0, True)
    ProbeWpfHost = (exitCode = 0)
End Function

powerShellPath = ""
pwshPath = ResolveCommand("pwsh.exe")
If pwshPath <> "" Then
    If ProbeWpfHost(pwshPath) Then
        powerShellPath = pwshPath
    End If
End If

If powerShellPath = "" Then
    windowsPowerShellPath = ResolveCommand("powershell.exe")
    If windowsPowerShellPath <> "" Then
        If ProbeWpfHost(windowsPowerShellPath) Then
            powerShellPath = windowsPowerShellPath
        End If
    End If
End If

If powerShellPath = "" Then
    powerShellPath = "powershell.exe"
End If

scriptPath = filesystem.BuildPath(rootPath, "Network_Monitor_WPF.ps1")
commandLine = Quote(powerShellPath) & " -NoProfile -ExecutionPolicy Bypass -STA -File " & Quote(scriptPath)
shell.Run commandLine, 0, False
