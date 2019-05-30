@echo off
echo Wait a moment...

rem Make sure if Igor Pro User Files folder exists
set ShellFolders=HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
for /f "usebackq tokens=1,2*" %%i in (`reg query "%ShellFolders%" /v Personal`) do ( if "%%i" == "Personal" ( @set DOCUMENT=%%k) )
set IGOR8=%DOCUMENT%\WaveMetrics\Igor Pro 8 User Files
if not exist "%IGOR8%" (
	echo The directory of Igor Pro User Files is not found.
	goto end
)

rem Install SIDAM files if not yet installed.
if not exist "%IGOR8%\Igor Procedures\SIDAM.ipf" (
	powershell start-process script/_installSIDAM.bat -ArgumentList \"%DOCUMENT%\" -verb runas
	exit /b
) else if "%1"=="/f" (
	powershell start-process script/_installSIDAM.bat -ArgumentList \"%DOCUMENT%\" -verb runas
	exit /b
) else if "%1"=="/test" (
	powershell start-process script/_installTest.bat -ArgumentList \"%DOCUMENT%\" -verb runas
	exit /b
)

rem Update SIDAM with Git in WSL if installed.
set WSLGIT=1
where /q wsl
if %errorlevel% equ 0 (
	for /f %%a in ('wsl bash -c "[ \$(which git) ] && echo 0 || echo 1"') do set WSLGIT=%%a
)
if %WSLGIT% equ 0 (
	wsl script/_update.sh
	goto end
)

rem Update SIDAM with Git for Windows if installed.
where /q git
if %errorlevel% equ 0 (
	call script/_update.bat
	goto end
)

rem Can not update if no git is installed.
echo Git is not found.

:end
echo Press any key to finish.
pause > nul
exit /b
