Set shell = CreateObject("WScript.Shell")
Set filesystem = CreateObject("Scripting.FileSystemObject")

rootPath = filesystem.GetParentFolderName(WScript.ScriptFullName)
shell.CurrentDirectory = rootPath
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File """ & rootPath & "\ToolLauncher.ps1""", 0, False
