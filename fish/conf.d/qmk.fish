type -q qmk || return 1
set -q QMK_HOME; or set -Ux QMK_HOME $XDG_DATA_HOME/qmk_firmware
set -q QMK_CONFIG_FILE; or set -Ux QMK_CONFIG_FILE $XDG_CONFIG_HOME/qmk/qmk.ini
