#!/usr/bin/env bash

#
# Sets the title of the terminal window.
#
title() {
	if [ $1 ]; then
		export TITLE=$@
	fi
}


#
# Tails a log that matches a keyword.
#
# Supported keywords:
#
# flash
# apache
#
log() {
	if [ -z $1 ]; then
		echo "No log specified.";
	elif [ $1 == "flash" ]; then
		flashlog;
	elif [ $1 == "apache" ]; then
		apachelog;
	else
		echo "Don't know of a log for $1";
	fi
}


#
# tail the flash log.
#
flashlog() {
	clear;
	tail -f ~/Library/Preferences/Macromedia/Flash\ Player/Logs/flashlog.txt;
}


#
# Tail the apache log
#
apachelog() {
	clear;
	tail -f /var/log/apache2/error_log;
}


#
# A recursive, case-insensitive grep that excludes binary files
#
dgrep() {
	grep -iR "$@" * | grep -v "Binary"
}


#
# A recursive, case-insensitive grep that excludes binary files and returns only unique filenames
#
dfgrep() {
	grep -iR "$@" * | grep -v "Binary" | sed 's/:/ /g' | awk '{ print $1 }' | sort | uniq
}


#
# Grep running processes
#
psgrep() {
	if [ ! -z $1 ] ; then
		echo "Grepping for processes matching $1..."
		ps aux | grep $1 | grep -v grep
	else
		echo "!! Need name to grep for"
	fi
}

#
# List only directories
#
ldir () {
	ls -l $@ | egrep '^d'
}


#
# List only files
#
lf () {
	ls -l $@ | egrep -v '^d'
}


#
# Django functions
#
manage() {
	python ./manage.py $@
}

startproject() {
	if [ -z $1 ]; then
		echo "Please specify a project name."
		return 1
	else
		django-admin.py startproject $1
	fi
}

startapp() {
	if [ -z $1 ]; then
		echo "Please specify an app name."
		return 1
	else
		django-admin.py startapp $1
	fi
}

droptables() {
	if [ -z $1 ]; then
		echo "Please specify an app."
		return 1
	fi
	manage sqlclear $1 | manage dbshell
}

# Move the given file(s) to the Trash.
trash() {
	for path in "$@"; do
		# Make relative paths "absolutey".
		[ "${path:0:1}" = '/' ] || path="$PWD/$1";
 
		# Execute the AppleScript to nudge Finder.
		echo "$(cat <<-EOD
			tell application "Finder"
				delete POSIX file "${path//\"/\"}"
			end
		EOD)" | osascript;
	done;
}

#
# ALIASES
#

# Default top to organize by cpu usage
alias top='top -o cpu'

# Use trash instead of rm
alias rm='trash-put'

# Always highlight grep search term
alias grep='grep --color=auto'
# Pings with 5 packets, not unlimited
alias ping='ping -c 5'
# Disk free, in gigabytes, not bytes
alias df='df -h'
# Calculate total disk usage for a folder
alias du='du -h -c'
# Use hub as a wrapper for git.
alias git=hub

# Python aliases
# Show the current python path
alias pypath='python -c "import sys; print sys.path" | tr "," "\n" | grep -v "egg"'
# Remove pyc files
alias pycclean='find . -name "*.pyc" -exec rm {} \;'

# Virtualenv/Virtualenvwrapper aliases
alias setproject="setvirtualenvproject $VIRTUAL_ENV `pwd`"

# Django aliases
alias migrate="manage migrate"
alias runserver="manage runserver localhost:8000"
alias shell="python ./manage.py shell"
alias collectstatic="manage collectstatic"
alias dumpauth="manage dumpdata --indent=2 auth sessions"
alias syncdb="manage syncdb"
alias syncall="syncdb --noinput --all && manage migrate --fake"
