@echo off
cd "C:\Hot Shortcuts\EPHEMERIS EPOCH TOOL\"
rem ephemeris.bin
ftp -s:Get_GASNT_Ephemeris.txt
pause
@java Read_Ephemeris ephemeris.bin Date
rename mil.bin ephemeris.bin
pause
ftp -s:Put_GASNT_Ephemeris.txt
pause