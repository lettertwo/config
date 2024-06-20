function cancel_search
  if commandline -P; or commandline -S
    kitty @ set-user-vars IS_FISH_PAGER
    commandline -f cancel
  else
    set fish_bind_mode default
    commandline -f backward-char repaint-mode
  end
end

