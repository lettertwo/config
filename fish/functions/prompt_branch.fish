function prompt_branch
  is_git; and set branch (command git branch --show-current 2>/dev/null); and [ -n "$branch" ]; and echo "$branch"
end
