@echo off

echo install SIDAM. Press Ctrl+c to abort.
pause

set WAVEMETRICS=%USERPROFILE%\Documents\WaveMetrics
set IGOR7="%WAVEMETRICS%\Igor Pro 7 User Files\"
set IGOR8="%WAVEMETRICS%\Igor Pro 8 User Files\"

if not exist %IGOR7% if not exist %IGOR8% (
	echo "Igor Pro is not installed."
	pause
)

cd %USERPROFILE%\Documents\
git clone -b master --depth 1 git@gitlab.com:ThnJYSZq/SIDAM.git

if exist %IGOR7% (
	mklink %IGOR7%"Igor Procedures/SIDAM.ipf" "%CD%/SIDAM/SIDAM.ipf"
	mklink /d %IGOR7%"User Procedures/SIDAM" "%CD%/SIDAM/SIDAM"

)

if exist %IGOR8% (
	mklink %IGOR8%"Igor Procedures/SIDAM.ipf" "%CD%/SIDAM/SIDAM.ipf"
	mklink /d %IGOR8%"User Procedures/SIDAM" "%CD%/SIDAM/SIDAM"
)

pause