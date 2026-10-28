@echo off
set "_T3SERVICE_SCRIPT=%USERPROFILE%\.t3service\t3service.ps1"
if /I "%~1"=="--help" goto showhelp
if /I "%~1"=="-h" goto showhelp
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%_T3SERVICE_SCRIPT%" %*
exit /b %ERRORLEVEL%

:showhelp
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%_T3SERVICE_SCRIPT%" help
exit /b %ERRORLEVEL%
