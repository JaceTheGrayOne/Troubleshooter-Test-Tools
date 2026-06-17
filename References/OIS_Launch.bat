if not "%GROUP%" == "" goto :USE_ENV_VAR_GROUP
set GROUP=Operator
:USE_ENV_VAR_GROUP

CD C:\GASNT_OIU
set OIS_HOME=%CD%
set JAVA_HOME=C:\AEHFPL_Java\jdk1.8.0_31\jre
set PATH=%JAVA_HOME%\bin;%JAVA_HOME%\lib;%PATH%
set SED_HOME=C:\cygwin\bin
set PATH=%SED_HOME%;%PATH%
REM copy in and fix the ior file
ftp -s:iorftp.txt
sed -i 's/800001020000000012736D732D6D616E6167656D656E742D766D00C351/7C000102000000000E3139322E3136382E35312E31300C351/' sacm.ior

start /REALTIME java -Dsun.java2d.d3d=false -jar ois.jar -NmtIpAddress 192.168.51.10 -NmtIpPortNumber 2809 -connect true -context sms -testmode -device ogds -XX: +HeapDumpOnOutOfMemoryError -project GASNT -testMode -GuiTargetPortNumber 1 -noClockChange -printerPresent false
