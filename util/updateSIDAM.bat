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

echo ------------------------------------------------------
echo Press any key to update SIDAM. (Press ctrl+c to quit.)
pause > nul
git merge origin master

:end
cd %initfd%
echo Press any key to finish.
pause > nul
