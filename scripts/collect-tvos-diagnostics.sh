#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || "$2" != /* ]]; then
  echo "usage: $0 <Apple-TV-device> /absolute/path/to/new-diagnostics-directory" >&2
  exit 64
fi
device="$1"
destination="$2"
bundle_identifier="${KARTPAD_TVOS_BUNDLE_IDENTIFIER:-dev.kartpad.tv}"
if [[ -e "${destination}" ]]; then
  echo "ERROR: diagnostics destination already exists: ${destination}" >&2
  exit 73
fi
mkdir -p "${destination}/KartPad" "${destination}/Controller"

copy_logs() {
  local source="$1"
  local output="$2"
  xcrun devicectl device copy from --device "${device}" \
    --source "${source}" \
    --destination "${output}" \
    --domain-type appDataContainer \
    --domain-identifier "${bundle_identifier}"
}

copied=0
if copy_logs "Library/Caches/KartPad/Logs" "${destination}/KartPad" ||
   copy_logs "Library/Application Support/KartPad/Logs" "${destination}/KartPad"; then
  copied=1
fi
if copy_logs "Library/Caches/SunPad/Logs" "${destination}/Controller" ||
   copy_logs "Library/Application Support/SunPad/Logs" "${destination}/Controller"; then
  copied=1
fi
if [[ "${copied}" == 0 ]]; then
  echo "ERROR: no KartPad diagnostic logs were available on ${device}" >&2
  exit 66
fi

while IFS= read -r -d '' log; do
  perl -pi -e \
    's#/(?:private/)?var/mobile/Containers/Data/Application/[0-9A-Fa-f-]+#<app-container>#g; s#/Users/[^/\r\n]+/#<user-home>/#g' \
    "${log}"
done < <(find "${destination}" -type f -print0)

echo "Collected and path-redacted KartPad tvOS diagnostics: ${destination}"
echo "Review the files before sharing them publicly."
