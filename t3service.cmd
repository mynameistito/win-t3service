@echo off
set "_T3SERVICE_SCRIPT=%USERPROFILE%\.t3service\t3service.ps1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%_T3SERVICE_SCRIPT%" %*
exit /b %ERRORLEVEL%
