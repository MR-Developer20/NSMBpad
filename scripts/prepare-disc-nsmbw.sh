#!/usr/bin/env bash
set -euo pipefail

# DRAFT, UNTESTED. Written against plan §2.1/§P1 hashes only; no NSMBW disc
# image has been supplied or run through this script in this environment.
# Added alongside scripts/prepare-disc.sh (MKWii) rather than replacing it
# in place, since the in-place edit the plan describes would remove a
# working script before this one has ever extracted a real image.
#
# Unlike scripts/prepare-disc.sh, which pins a whole-image SHA-256 plus
# SHA-256 of each extracted executable, the plan only supplies MD5s for the
# five NSMBW files (§2.1) and no whole-image hash at all. This script
# verifies what is actually pinned (per-file MD5) and does not invent a
# whole-image hash. Once a real PALv1 image is extracted here, compute and
# record its SHA-256 in this script and in builder/profiles/smnp01-rev0.json.

repo_root="$(git rev-parse --show-toplevel)"
image="${1:-${repo_root}/ref/New Super Mario Bros. Wii.wbfs}"
output="${2:-${repo_root}/private/self-build/disc-nsmbw}"

expected_dol_md5="ddab9e5dca53d8c18bf4051b927e822e"
expected_rel_bases_md5="17096d0ed441d44a0c31039138a8d7f8"
expected_rel_en_boss_md5="f8cffd634edbec6c1bc210dab02c1e32"
expected_rel_enemies_md5="458f1aa94706dde1a8f2f9d97ff1f35c"
expected_rel_profile_md5="393bf12ef4254dd1ea1366d5b06fbebb"

image_lower="$(printf '%s' "${image}" | tr '[:upper:]' '[:lower:]')"
case "${image_lower}" in
  *.iso|*.gcm|*.gcz|*.ciso|*.wbfs|*.wia|*.rvz) ;;
  *) echo "ERROR: unsupported disc-image extension: ${image}" >&2; exit 64 ;;
esac
[[ -f "${image}" ]] || { echo "ERROR: missing disc image: ${image}" >&2; exit 66; }
[[ "${output}" == "${repo_root}/private/"* ]] || {
  echo "ERROR: extracted output must stay under ${repo_root}/private" >&2
  exit 64
}

nodtool="$(command -v nodtool || true)"
if [[ -z "${nodtool}" && -x "${CARGO_HOME:-${HOME}/.cargo}/bin/nodtool" ]]; then
  nodtool="${CARGO_HOME:-${HOME}/.cargo}/bin/nodtool"
fi
[[ -n "${nodtool}" ]] || {
  echo "ERROR: nodtool 2.0.0-alpha.9 is required (cargo install nodtool --version 2.0.0-alpha.9 --locked)" >&2
  exit 69
}
[[ "$(${nodtool} --version)" == "nodtool 2.0.0-alpha.9 " ||
   "$(${nodtool} --version)" == "nodtool 2.0.0-alpha.9" ]] || {
  echo "ERROR: expected nodtool 2.0.0-alpha.9" >&2
  exit 65
}

md5_of() {
  # macOS/BSD `md5` vs GNU `md5sum`; the rest of the fork's scripts target
  # macOS, so prefer md5sum where present (Linux dev/test) and fall back.
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" | awk '{print $1}'
  else
    md5 -q "$1"
  fi
}

validate_output() {
  local root="$1"
  for relative in sys/boot.bin sys/bi2.bin sys/apploader.img sys/fst.bin \
      files/wiimj2d.dol \
      files/rel/d_basesNP.rel files/rel/d_en_bossNP.rel \
      files/rel/d_enemiesNP.rel files/rel/d_profileNP.rel; do
    [[ -f "${root}/${relative}" ]] || {
      echo "ERROR: extracted data is missing ${relative}" >&2
      return 1
    }
  done
  [[ "$(xxd -p -s 24 -l 4 "${root}/sys/boot.bin")" == "5d1c9ea3" ]] || {
    echo "ERROR: extracted data has an invalid Wii disc magic" >&2
    return 1
  }
  local dol_md5
  dol_md5="$(md5_of "${root}/files/wiimj2d.dol")"
  [[ "${dol_md5}" == "${expected_dol_md5}" ]] || {
    echo "ERROR: extracted wiimj2d.dol MD5 (${dol_md5}) does not match SMNP01 rev 0 (${expected_dol_md5})" >&2
    return 1
  }
  local rel_bases_md5 rel_en_boss_md5 rel_enemies_md5 rel_profile_md5
  rel_bases_md5="$(md5_of "${root}/files/rel/d_basesNP.rel")"
  rel_en_boss_md5="$(md5_of "${root}/files/rel/d_en_bossNP.rel")"
  rel_enemies_md5="$(md5_of "${root}/files/rel/d_enemiesNP.rel")"
  rel_profile_md5="$(md5_of "${root}/files/rel/d_profileNP.rel")"
  [[ "${rel_bases_md5}" == "${expected_rel_bases_md5}" ]] || {
    echo "ERROR: extracted d_basesNP.rel MD5 (${rel_bases_md5}) does not match (${expected_rel_bases_md5})" >&2
    return 1
  }
  [[ "${rel_en_boss_md5}" == "${expected_rel_en_boss_md5}" ]] || {
    echo "ERROR: extracted d_en_bossNP.rel MD5 (${rel_en_boss_md5}) does not match (${expected_rel_en_boss_md5})" >&2
    return 1
  }
  [[ "${rel_enemies_md5}" == "${expected_rel_enemies_md5}" ]] || {
    echo "ERROR: extracted d_enemiesNP.rel MD5 (${rel_enemies_md5}) does not match (${expected_rel_enemies_md5})" >&2
    return 1
  }
  [[ "${rel_profile_md5}" == "${expected_rel_profile_md5}" ]] || {
    echo "ERROR: extracted d_profileNP.rel MD5 (${rel_profile_md5}) does not match (${expected_rel_profile_md5})" >&2
    return 1
  }
}

if [[ -d "${output}" ]]; then
  validate_output "${output}"
  echo "Reused validated private SMNP01 extraction: ${output}"
  exit 0
fi
[[ ! -e "${output}" ]] || { echo "ERROR: output exists and is not a directory: ${output}" >&2; exit 73; }

mkdir -p "$(dirname "${output}")"
stage="${output}.partial.$RANDOM.$RANDOM"
[[ "${stage}" == "${repo_root}/private/"* ]]
cleanup() {
  if [[ -d "${stage}" && "${stage}" == "${repo_root}/private/"* ]]; then
    rm -rf -- "${stage}"
  fi
}
trap cleanup EXIT

"${nodtool}" extract --quiet "${image}" "${stage}"

# Decompress the four LZ-compressed RELs in place (port of NSMBW-Decomp's
# tools/uncompress_lz.py). NOT YET IMPLEMENTED — nodtool's raw extraction
# output layout (whether RELs land pre- or post-decompression, and their
# exact path under files/rel/) has not been observed against a real image.
# Fill this in once a real SMNP01 dump is available, then re-verify the
# `requiredFiles` paths in validate_output() above against what nodtool
# actually produces.
echo "ERROR: LZ decompression step is not implemented — see comment above" >&2
exit 1

# shellcheck disable=SC2317
validate_output "${stage}"
# shellcheck disable=SC2317
mv "${stage}" "${output}"
# shellcheck disable=SC2317
printf '{\n  "schema": 1,\n  "discId": "SMNP01",\n  "revision": 0,\n  "wiimj2dDolMD5": "%s",\n  "extractor": "nodtool 2.0.0-alpha.9"\n}\n' \
  "${expected_dol_md5}" \
  > "${output}/kartpad-disc-manifest.json"
# shellcheck disable=SC2317
echo "Prepared validated private SMNP01 extraction: ${output}"
