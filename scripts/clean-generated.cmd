@echo off
setlocal

rem Remove build outputs while preserving Vivado and Vitis projects.
rem Published artifacts require explicit -IncludePublished opt-in.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean-generated.ps1" %*
exit /b %ERRORLEVEL%
