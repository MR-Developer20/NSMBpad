#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}

translation_root="$(absolute_from_repo "${1:-private/builder/dual-pipeline-smoke/translation}")"
runtime_source="$(absolute_from_repo "${2:-build/tvos-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/tvos-game-runtime-build}")"

env KARTPAD_PREPARE_ONLY=1 \
  "${repo_root}/scripts/prepare-ios-game-runtime.sh" \
  "${translation_root}" "${runtime_source}" "${runtime_build}" dual
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-tvos-dawn-package.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-tvos-runtime.patch"

echo "Prepared independent KartPad tvOS runtime source: ${runtime_source}"
