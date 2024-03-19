if [[ $+commands[gh] ]]; then
  alias '??'='gh copilot suggest -t shell';
  alias 'g?'='gh copilot suggest -t git';
  alias 'gh?'='gh copilot suggest -t gh';
  alias 'wut'='gh copilot explain';
fi
