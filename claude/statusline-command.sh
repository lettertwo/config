#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current directory
dir=$(echo "$input" | jq -r '.workspace.current_dir')
basename=$(basename "$dir")

# Change to directory
cd "$dir" 2>/dev/null || exit 1

# ANSI color codes (will be dimmed by terminal)
CYAN='\033[36m'
GREEN='\033[32m'
BLACK='\033[30m'
BRIGHT_BLACK='\033[90m'
YELLOW='\033[33m'
RESET='\033[0m'

# Unicode symbols
GIT_BRANCH_ICON="󰘬"
FOLDER_ICON="󰝰"

# Check if we're in a git repository
if git rev-parse --is-inside-work-tree &>/dev/null; then
  # Get current branch
  branch=$(git branch --show-current 2>/dev/null)
  
  # Check if this is a worktree
  if [ -f ".git" ]; then
    # This is a worktree - show parent/worktree
    parent=$(basename "$(dirname "$dir")")
    dir_display="$parent/$basename"
  else
    # Regular repo - show just basename
    dir_display="$basename"
  fi
  
  # Format output with colors and icons
  if [ -n "$branch" ]; then
    printf "${BLACK}${FOLDER_ICON} ${dir_display}${RESET} ${BRIGHT_BLACK}${GIT_BRANCH_ICON} ${branch}${RESET}"
  else
    printf "${BLACK}${FOLDER_ICON} ${dir_display}${RESET}"
  fi
else
  # Not a git repo - just show directory
  printf "${BLACK}${FOLDER_ICON} ${basename}${RESET}"
fi
