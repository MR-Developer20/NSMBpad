#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

./scripts/verify-patch-hunks.py patches/*.patch

check_reference() {
  local reference_path="$1"
  local expected_commit="$2"
  local expected_tree="$3"

  [[ -d "$reference_path/.git" ]] || {
    echo "ERROR: missing reference checkout: $reference_path" >&2
    return 1
  }

  local actual_commit actual_tree push_url
  actual_commit="$(git -C "$reference_path" rev-parse HEAD^{commit})"
  actual_tree="$(git -C "$reference_path" rev-parse HEAD^{tree})"
  push_url="$(git -C "$reference_path" remote get-url --push origin)"

  [[ "$actual_commit" == "$expected_commit" ]] || {
    echo "ERROR: $reference_path commit $actual_commit != $expected_commit" >&2
    return 1
  }
  [[ "$actual_tree" == "$expected_tree" ]] || {
    echo "ERROR: $reference_path tree $actual_tree != $expected_tree" >&2
    return 1
  }
  [[ "$push_url" == "DISABLED" ]] || {
    echo "ERROR: $reference_path push URL is not disabled" >&2
    return 1
  }
  [[ -z "$(git -C "$reference_path" status --porcelain)" ]] || {
    echo "ERROR: $reference_path is not a clean reference checkout" >&2
    return 1
  }

  echo "Verified $reference_path @ $actual_commit"
}

check_reference ref/upstream/WiiCompiled \
  1912292c804ff9b1b79938de89369ec4496f9fff \
  34f9deda094915e12f47316059911b28c6812964
check_reference ref/sunpad \
  e43f0ea6b797e5110787171957c9dc3c6213269c \
  9166b0109bc549c0ba3199ac0c42f5226ff4ed04
check_reference ref/upstream/WheelWizard \
  945ba734c60c492f97e2921f1284dbfd00a79132 \
  e51fe2fc48fbf67ccd64c350cc5e9a50f13fcdb2
check_reference ref/upstream/rr-pulsar \
  93ba8c8a486bd771c97ffc8b68fd504f47f742b5 \
  320825ec78da1eed8f82cc1abb0335c3d806d9fe
check_reference ref/upstream/wfc-server \
  fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b \
  a36a2ae07e9e86f8f199aa275caede19a118731f
check_reference ref/upstream/wfc-patcher-wii \
  9ee5c2dfdcbe97408786184566ab50c9bee0d1eb \
  3fac5511d0135a7fcce171c32d7cc2848ddb2303
check_reference ref/upstream/dolphin \
  4f8af23db516d8b6e9cd00e7b261a65b026514a8 \
  f44613fc11ba82c609e12b434e0d7bc80c11ac01
check_reference ref/upstream/wiimms-iso-tools \
  fc1c0b840cb3ac41ca6e4f1d5e16da12b47eab58 \
  c6ab6de655bc3b756c2c8b2719e8b111fdebb792

disc_path="${KARTPAD_DISC_PATH:-ref/Mario Kart Wii.wbfs}"
[[ -f "$disc_path" ]] || {
  echo "ERROR: missing supplied WBFS: $disc_path" >&2
  exit 1
}
[[ ! -w "$disc_path" ]] || {
  echo "ERROR: supplied WBFS must remain read-only" >&2
  exit 1
}
[[ "$(stat -f '%z' "$disc_path")" == "2778726400" ]] || {
  echo 'ERROR: supplied WBFS size changed' >&2
  exit 1
}

container_magic="$(xxd -p -l 4 "$disc_path")"
disc_id="$(dd if="$disc_path" bs=1 skip=2097152 count=6 2>/dev/null)"
disc_revision="$(xxd -p -s 2097159 -l 1 "$disc_path")"
[[ "$container_magic" == "57424653" ]] || { echo 'ERROR: WBFS magic changed' >&2; exit 1; }
[[ "$disc_id" == "RMCP01" ]] || { echo "ERROR: embedded disc ID is $disc_id" >&2; exit 1; }
[[ "$disc_revision" == "00" ]] || { echo "ERROR: embedded revision is $disc_revision" >&2; exit 1; }

if [[ "${KARTPAD_VERIFY_FULL_DISC:-0}" == "1" ]]; then
  expected_sha256='fc035e60610842da6860d23d4a30c1f1c0f019d492469deb8a2ac25ef5822331'
  actual_sha256="$(shasum -a 256 "$disc_path" | awk '{print $1}')"
  [[ "$actual_sha256" == "$expected_sha256" ]] || {
    echo "ERROR: supplied WBFS SHA-256 changed: $actual_sha256" >&2
    exit 1
  }
  echo "Verified full WBFS SHA-256: $actual_sha256"
else
  echo 'Verified WBFS size, read-only mode, container magic, RMCP01 ID, and revision 0 (full hash skipped).'
fi

echo 'Pinned source and input verification passed.'
