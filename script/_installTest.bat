@echo off

echo Press any key to install SIDAM test.
pause > nul

set IGOR8=%1\WaveMetrics\Igor Pro 8 User Files
set FOLDER=%IGOR8%\User Procedures\SIDAMTest

cd /d %~dp0..

if exist "%FOLDER%" (rmdir "%FOLDER%")
if exist "%FOLDER%.lnk" (del "%FOLDER%.lnk")
mklink /d "%IGOR8%\User Procedures\SIDAMTest" "%CD%\test"
if %errorlevel% neq 0 (
	echo An error occurred in making a symbolic link of SIDAM.
	exit 1
)

echo SIDAMTest has been successfully installed.
echo Press any key to finish.
pause > nul
