#!/usr/bin/env bash
# Convenience launcher for Octarine Engine Showcase (stock Lua or native C++ module build).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE_DIR="${OCTARINE_ENGINE_DIR:-$(cd "$SCRIPT_DIR/../octarine-engine" 2>/dev/null && pwd || true)}"

if [[ -z "$ENGINE_DIR" || ! -d "$ENGINE_DIR" ]]; then
  echo "error: could not locate octarine-engine directory. Set OCTARINE_ENGINE_DIR=/path/to/octarine-engine" >&2
  exit 1
fi

usage() {
  cat <<'EOF'
Usage: ./run.sh [mode]

Modes:
  (default)   Launch showcase in dev mode on stock OctarineEngine
  --native    Configure/build octarine-engine/build/example-debug with -DOCTARINE_GAME_MODULE_DIR and launch --dev
  --bake      Run headless asset & UI validation bake (-m bake)
  --verify    Run headless automated showcase verification (--headless --startup-mode verify)
  --stress    Run headless stress benchmark scene (--headless --startup-mode stress)
  -h, --help  Show this help
EOF
}

find_stock_bin() {
  for candidate in \
    "$ENGINE_DIR/build/player-debug/bin/debug/OctarineEngine" \
    "$ENGINE_DIR/build/player-release/bin/release/OctarineEngine" \
    "$ENGINE_DIR/build/player-debug/bin/OctarineEngine"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

build_native() {
  local build_dir="$ENGINE_DIR/build/example-debug"
  local vcpkg_dir="$ENGINE_DIR/build/player-debug/vcpkg_installed"
  local cmake_args=(
    -S "$ENGINE_DIR"
    -B "$build_dir"
    -G Ninja
    -DCMAKE_TOOLCHAIN_FILE="$ENGINE_DIR/cmake/vcpkg-toolchain.cmake"
    -DCMAKE_BUILD_TYPE=Debug
    -DOCTARINE_WITH_IMGUI=ON
    -DOCTARINE_ENABLE_TESTS=ON
    -DOCTARINE_GAME_MODULE_DIR="$SCRIPT_DIR/native"
  )
  if [[ -d "$vcpkg_dir" ]]; then
    cmake_args+=("-DVCPKG_INSTALLED_DIR=$vcpkg_dir")
  fi
  cmake "${cmake_args[@]}" >&2
  cmake --build "$build_dir" --target OctarineEngine OctarineShowcaseModuleTest >&2
  echo "$build_dir/bin/debug/OctarineEngine"
}

mode="${1:-play}"
case "$mode" in
  -h|--help)
    usage
    exit 0
    ;;
  --native)
    shift
    BIN="$(build_native)"
    exec "$BIN" "$SCRIPT_DIR" --dev "$@"
    ;;
  --bake)
    BIN="$(find_stock_bin)"
    exec env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$BIN" "$SCRIPT_DIR" -m bake
    ;;
  --verify)
    BIN="$(find_stock_bin)"
    exec env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$BIN" "$SCRIPT_DIR" --headless --startup-mode verify
    ;;
  --stress)
    BIN="$(find_stock_bin)"
    exec env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$BIN" "$SCRIPT_DIR" --headless --startup-mode stress
    ;;
  play|"")
    BIN="$(find_stock_bin)"
    exec "$BIN" "$SCRIPT_DIR" --dev
    ;;
  *)
    echo "Unknown option: $mode" >&2
    usage >&2
    exit 2
    ;;
esac
