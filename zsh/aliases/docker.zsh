#
# Docker aliases
#

# Image (i)
alias dimage='docker image'
for c (
  build
  history
  import
  inspect
  ls
  prune
  pull
  push
  rm
  save
  tag
) alias "di$c"="docker image $c"

# Volume (v)
alias dvolume='docker volume'
for c (
  inspect
  ls
  prune
  rm
) alias "dv$c"="docker volume $c"

# Network (n)
alias dnetwork='docker network'
for c (
  connect
  disconnect
  inspect
  ls
  prune
  rm
) alias "dn$c"="docker network $c"

# System (s)
alias dsystem='docker system'
for c (
  df
  prune
) alias "ds$c"="docker system $c"

# Docker Compose (c)
alias dcompose='docker-compose'
for c (
  build
  down
  exec
  kill
  logs
  ps
  pause
  unpause
  pull
  push
  ps
  run
  rm
  start
  scale
  restart
  up
  version
  stop
) alias "dc$c"="docker-compose $c"

# Docker (d)
for c (
  attach
  build
  diff
  exec
  history
  images
  inspect
  import
  kill
  logs
  login
  logout
  ps
  pause
  unpause
  pull
  push
  ps
  run
  rm
  rmi
  rename
  start
  restart
  stats
  save
  tag
  top
  update
  volume
  version
  wait
  stop
) alias "d$c"="docker $c"

# Container (d)
alias dcontainer='docker container'
# Most container commands are mirrored at the docker level,
# so we can just use the 'top level' aliases above.
# Here, we add aliases for the few that aren't.
for c (
  ls
  prune
) alias "d$c"="docker container $c"

# cleanup
unset c; unset s; unset i;
