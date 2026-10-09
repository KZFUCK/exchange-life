#!/bin/zsh
set -eu
project_root="${0:A:h}"
exec "$project_root/tools/run_game.zsh" forward_plus metal "$@"
