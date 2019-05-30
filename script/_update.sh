#!/bin/bash

echo Checking the repository...
git fetch origin

status=$(git status --porcelain --branch | grep "^##.*\[.*\]")
if [ $status ]; then
	git merge origin master
else
	echo You are using the most up-to-date version of SIDAM.
fi
