#!/bin/zsh
set -eu
project_root="${0:A:h:h}"
rendering_method="$1"
rendering_driver="$2"
shift 2
godot_bin="${GODOT_BIN:-}"
if [[ -z "$godot_bin" ]]; then
  for candidate in "$project_root/downloads/Godot.app/Contents/MacOS/Godot" "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$candidate" ]]; then
      godot_bin="$candidate"
      break
    fi
  done
fi
if [[ -z "$godot_bin" ]]; then
  godot_bin="$(command -v godot || true)"
fi
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
  print -u2 "未找到 Godot。请安装 Godot 4.7.2，或将 GODOT_BIN 指向可执行文件。"
  exit 1
fi
exec "$godot_bin" --path "$project_root/bnb" --rendering-method "$rendering_method" --rendering-driver "$rendering_driver" "$@"
