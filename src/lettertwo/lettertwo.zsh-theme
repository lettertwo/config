#!/usr/bin/env zsh

export VIRTUAL_ENV_DISABLE_PROMPT=true

prompt_arrow=" %{$fg_bold[white]%}→%{$reset_color%} "
prompt_char="%{$fg[cyan]%}♥%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_PREFIX="${prompt_arrow}%{$fg[blue]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg_bold[red]%}★%{$fg[yellow]%}"

VIRTUALENV_PROMPT_PREFIX="${prompt_arrow}%{$fg[yellow]%}"
VIRTUALENV_PROMPT_SUFFIX="%{$reset_color%}"

function virtualenv_prompt_info {
    [ $VIRTUAL_ENV ] && echo $VIRTUALENV_PROMPT_PREFIX`basename $VIRTUAL_ENV`$VIRTUALENV_PROMPT_SUFFIX
}

function cwd_prompt_info {
	echo "${PWD/#$HOME/~}"
}

PROMPT='%{$fg[black]%}$(cwd_prompt_info)%{$reset_color%}$(virtualenv_prompt_info)$(git_prompt_info)
${prompt_char}${prompt_arrow}'
RPROMPT='%{$fg[black]%}%n@%m%{$reset_color%}'

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
