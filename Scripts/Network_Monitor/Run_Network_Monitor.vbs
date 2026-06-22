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

powerShellPath = ResolveCommand("pwsh.exe")
If powerShellPath = "" Then
    powerShellPath = ResolveCommand("powershell.exe")
End If
If powerShellPath = "" Then
    powerShellPath = "powershell.exe"
End If

scriptPath = filesystem.BuildPath(rootPath, "Network_Monitor.ps1")
commandLine = Quote(powerShellPath) & " -NoProfile -ExecutionPolicy Bypass -STA -File " & Quote(scriptPath)
shell.Run commandLine, 0, False
