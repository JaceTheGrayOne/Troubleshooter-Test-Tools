REM run this file to set the IONA environment so that labVIEW can find the DLL

PATH=%PATH%;C:\Program Files (x86)\National Instruments\TestStant 2019\Bin

cd "C:\Program Files\Progress\Orbix\etc\domains\"
copy "raytheon-domain - GASNT.cfg" "raytheon-domain.cfg"

CALL "C:\Program Files\PRogress\ORbix\etc\bin\raytheon-domain_env.bat"

Start "" "C:\Program Files (x86)\National Instruments\TestStand 2019\Bin\SeqEdit.exe" "GASNT_Red_Functional_Tests_Sequence.seq" "C:\GASNT Production Red Test Software\GASNT_Red_Tests_Workspace.tsw"
