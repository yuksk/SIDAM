@echo off

echo Press any key to install SIDAM.
pause > nul

set IGOR8=%1\WaveMetrics\Igor Pro 8 User Files
set FILE=%IGOR8%\Igor Procedures\SIDAM.ipf
set FOLDER=%IGOR8%\User Procedures\SIDAM

cd /d %~dp0..\src

if exist "%FILE%" (del "%FILE%")
if exist "%FILE%.lnk" (del "%FILE%.lnk")
mklink "%IGOR8%\Igor Procedures\SIDAM.ipf" "%CD%\SIDAM.ipf"
if %errorlevel% neq 0 (
	echo An error occurred in making a symbolic link of SIDAM.ipf.
	exit 1
)

if exist "%FOLDER%" (rmdir "%FOLDER%")
if exist "%FOLDER%.lnk" (del "%FOLDER%.lnk")
mklink /d "%IGOR8%\User Procedures\SIDAM" "%CD%\SIDAM"
if %errorlevel% neq 0 (
	echo An error occurred in making a symbolic link of SIDAM.
	exit 1
)

echo SIDAM has been successfully installed.
echo Press any key to finish.
pause > nul
