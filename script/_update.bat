@echo off
echo Checking the repository...
git fetch origin

for /f "DELIMS=" %%a in ('git status --porcelain --branch ^| find "##"') do set b=%%a
rem b is "## master...origin/master [behind 5]" if there is an update
set status=%b:## master...origin/master=%
if defined status (
	git merge origin master
) else (
	echo You are using the most up-to-date version of SIDAM.
)

exit /b
