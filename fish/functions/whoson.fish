# Find process listening on a port
function whoson
  sudo lsof -nP -i:$argv[1] | grep LISTEN
end
