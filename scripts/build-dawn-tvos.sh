#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
dawn_commit="13abc3bc8ea2d3c2050f9e77a12d012108ceee24"
dawn_source_sha256="713bea5b92d4f6c5175752fd7cbf1c3c5ce36598ff5dd98685d8a1216614ebba"
source_archive="${repo_root}/build/dependency-cache/dawn-${dawn_commit}.tar.gz"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}

sdk="${1:-appletvos}"
case "${sdk}" in
  appletvos)
    platform="tvos"
    ;;
  appletvsimulator)
    platform="tvos-simulator"
    ;;
  *) echo "usage: $0 [appletvos|appletvsimulator] [source] [build] [install] [package]" >&2; exit 64 ;;
esac

source_dir="$(absolute_from_repo "${2:-build/dawn-tvos-source}")"
build_dir="$(absolute_from_repo "${3:-build/dawn-${platform}-build}")"
install_dir="$(absolute_from_repo "${4:-build/dawn-${platform}-install}")"
package_path="$(absolute_from_repo "${5:-build/dependency-cache/dawn-${platform}-arm64-v20260603.191052.tar.gz}")"
host_build_dir="${repo_root}/build/dawn-host-protoc-build"
path_map_flags="-ffile-prefix-map=${repo_root}=KartPad -fmacro-prefix-map=${repo_root}=KartPad"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: Dawn's tvOS package requires arm64 macOS" >&2
  exit 1
fi
if [[ ! -f "${source_archive}" ]] ||
   [[ "$(shasum -a 256 "${source_archive}" | awk '{print $1}')" != "${dawn_source_sha256}" ]]; then
  echo "ERROR: missing or mismatched pinned Dawn source archive" >&2
  exit 1
fi
if [[ ! -e "${source_dir}" ]]; then
  mkdir -p "${source_dir}"
  tar -xzf "${source_archive}" --strip-components=1 -C "${source_dir}"
fi
if [[ ! -x "${host_build_dir}/protoc" ]]; then
  echo "ERROR: missing Dawn host protoc; run scripts/build-dawn-ios-simulator.sh first" >&2
  exit 1
fi

cmake -S "${source_dir}" -B "${build_dir}" -G Ninja \
  -C "${source_dir}/.github/workflows/dawn-ci.cmake" \
  -C "${repo_root}/cmake/dawn-kartpad-ci.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=tvOS \
  -DCMAKE_OSX_SYSROOT="${sdk}" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_OBJC_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_OBJCXX_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DWITH_PROTOC="${host_build_dir}/protoc"
cmake --build "${build_dir}" --parallel 4
cmake --install "${build_dir}" --prefix "${install_dir}"

test -f "${install_dir}/lib/libwebgpu_dawn.a"
test -f "${install_dir}/lib/cmake/Dawn/DawnConfig.cmake"
ZERO_AR_DATE=1 ranlib "${install_dir}/lib/libwebgpu_dawn.a"
find "${install_dir}" -exec touch -h -t 198001010000 {} +
mkdir -p "$(dirname "${package_path}")"
(
  cd "${install_dir}"
  find . -print | LC_ALL=C sort |
    COPYFILE_DISABLE=1 tar -cf - --no-recursion --uid 0 --gid 0 \
      --uname root --gname root --format=ustar -T -
) | gzip -n -9 > "${package_path}"

echo "Dawn ${sdk} package: ${package_path}"
shasum -a 256 "${package_path}"
