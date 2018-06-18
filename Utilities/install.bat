@echo off

set ShellFolders=HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
for /f "usebackq tokens=*" %%i in (`reg query "%ShellFolders%" /v Personal`) do set RESULT=%%i
set RESULT=%RESULT:Personal	REG_SZ	=%
set RESULT=%RESULT:Personal    REG_SZ    =%

if not exist %RESULT% (
echo Failed to find "My Documents"
goto :EOF
)

set IGOR=%RESULT%\WaveMetrics\Igor Pro 7 User Files
if not exist "%IGOR%" (
echo Igor Pro folder was not found.
goto :EOF
)

echo Install SIDAM.
pause
robocopy "../Igor Procedures/" "%IGOR%/Igor Procedures/" /NJH /NJS /NP
robocopy "../User Procedures/SIDAM" "%IGOR%/User Procedures/SIDAM" /E /NJH /NJS /NP
pause