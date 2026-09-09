#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || "$1" != /* || ! -d "$1" ]]; then
  echo "usage: $0 /absolute/path/to/extracted/DATA <Apple-TV-device>" >&2
  exit 64
fi
source_root="$1"
device="$2"
bundle_identifier="${KARTPAD_TVOS_BUNDLE_IDENTIFIER:-dev.kartpad.tv}"
boot="${source_root}/sys/boot.bin"
dol="${source_root}/sys/main.dol"
for required in "${boot}" "${source_root}/sys/bi2.bin" \
                "${source_root}/sys/apploader.img" \
                "${source_root}/sys/fst.bin" "${dol}" \
                "${source_root}/files/rel/StaticR.rel"; do
  test -f "${required}" || { echo "ERROR: incomplete extracted data: ${required}" >&2; exit 66; }
done
test "$(dd if="${boot}" bs=1 count=6 2>/dev/null)" = "RMCP01" || {
  echo "ERROR: extracted data is not RMCP01" >&2; exit 65;
}
test "$(xxd -p -s 6 -l 2 "${boot}")" = "0000" || {
  echo "ERROR: extracted data is not disc 0 revision 0" >&2; exit 65;
}
test "$(xxd -p -s 24 -l 4 "${boot}")" = "5d1c9ea3" || {
  echo "ERROR: extracted data has an invalid Wii disc header" >&2; exit 65;
}
test "$(shasum -a 256 "${dol}" | awk '{print $1}')" = \
  "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05" || {
  echo "ERROR: sys/main.dol does not match the supported profile" >&2; exit 65;
}

xcrun devicectl device copy to --device "${device}" \
  --source "${source_root}" \
  --destination "Library/Caches/KartPad/GameData" \
  --domain-type appDataContainer \
  --domain-identifier "${bundle_identifier}" \
  --remove-existing-content true
echo "Staged validated RMCP01 game data for KartPad on ${device}."
