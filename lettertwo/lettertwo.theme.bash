#!/usr/bin/env bash
PROMPT_ARROW="${bold_white} → "
PROMPT_CHAR="♥"
SCM_THEME_PROMPT_DIRTY="${bold_red}★"
SCM_THEME_PROMPT_CLEAN=""
SCM_THEME_PROMPT_PREFIX="${PROMPT_ARROW}${green}"
SCM_THEME_PROMPT_SUFFIX="${reset_color}"
VIRTUALENV_THEME_PROMPT_PREFIX="${PROMPT_ARROW}${yellow}"
VIRTUALENV_THEME_PROMPT_SUFFIX="${reset_color}"

function title_prompt() {
	echo -e "\[\033]0;\$TITLE\007\]"
}

function prompt_command() {
	history -a
	history -c
	history -r
	# PS1="$(title_prompt)\n${red}\h ${reset_color}in ${blue}\w\n${cyan}${PROMPT_CHAR}$(virtualenv_prompt)$(scm_prompt_info)${PROMPT_ARROW}${normal}"
	PS1="\n${red}\h ${reset_color}in ${blue}\w\n${cyan}${PROMPT_CHAR}$(virtualenv_prompt)$(scm_prompt_info)${PROMPT_ARROW}${normal}"
}

PROMPT_COMMAND=prompt_command;

# LSCOLORS describes what color to use for which attribute when colors are enabled for ls.
# This string is a concatenation of pairs of the format fb, where f is the foreground color and b is the background color.
#
# The color designators are as follows:
#
#    a     black
#    b     red
#    c     green
#    d     brown
#    e     blue
#    f     magenta
#    g     cyan
#    h     light grey
#    A     bold black, usually shows up as dark grey
#    B     bold red
#    C     bold green
#    D     bold brown, usually shows up as yellow
#    E     bold blue
#    F     bold magenta
#    G     bold cyan
#    H     bold light grey; looks like bright white
#    x     default foreground or background
#
# The order of the attributes are as follows:
#
#    1.   directory
#    2.   symbolic link
#    3.   socket
#    4.   pipe
#    5.   executable
#    6.   block special
#    7.   character special
#    8.   executable with setuid bit set
#    9.   executable with setgid bit set
#    10.  directory writable to others, with sticky bit
#    11.  directory writable to others, without sticky bit
#
# The default is "exfxcxdxbxegedabagacad", i.e. blue foreground and default background for regular
# directories, black foreground and red background for setuid executables, etc.
LSDARK=exfxcxdxbxegedabagacad
LSBRIGHT=Exdxfxgxcxegedacagabac
LSCOLORS=$LSBRIGHT
