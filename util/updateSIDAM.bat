@echo off
set initfd=%cd%
cd %USERPROFILE%/Documents/SIDAM

echo Checking the repository...
git fetch origin

for /f "DELIMS=" %%a in ('git status --porcelain --branch ^| find "##"') do set b=%%a
rem b is "## master...origin/master [behind 5]" if there is an update
set status=%b:## master...origin/master=%
if not defined status (
	echo You are using the most up-to-date version of SIDAM.
	goto end
)

echo A newer version of SIDAM is available.
echo Press any key to see a change log.
pause > nul
echo ------------------------------------------------------
git log origin/master --oneline --decorate -%status:~9,-1%

:input
echo ------------------------------------------------------
set /p input="Press 1 to update SIDAM, 2 to see a detailed log, 3 to quit: "
if "%input%"=="1" (
	git merge origin master
	goto end
) else if "%input%"=="2" (
	git log origin/master --decorate -%status:~9,-1%
	goto input
) else if "%input%"=="3" (
	goto confirm
) else (
	goto input
)

:confirm
set /p input="Do you want to quit without updating? (y/n): "
if "%input%"=="n" (
	goto input
) else if "%input%"=="N" (
	goto input
)

:end
cd %initfd%
echo Press any key to finish.
pause > nul
