#!/usr/bin/env bash
set -euo pipefail

# Reproducible data collection script for the BDP final project.
# It downloads public datasets used in the analysis and places them
# under the project DataSet directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FINAL_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
DATASET_DIR="${DATASET_DIR:-${FINAL_DIR}/DataSet}"

PEOPLE_DIR="${DATASET_DIR}/People"
SUBWAY_DIR="${DATASET_DIR}/Subway"
DOWNLOAD_DIR="${DATASET_DIR}/_downloads"
PEOPLE_ZIP_DIR="${DOWNLOAD_DIR}/people_zips"
SUBWAY_DOWNLOAD_DIR="${DOWNLOAD_DIR}/subway"

FORCE="${FORCE:-0}"

mkdir -p "${PEOPLE_DIR}" "${SUBWAY_DIR}" "${PEOPLE_ZIP_DIR}" "${SUBWAY_DOWNLOAD_DIR}"

download_if_needed() {
  local output_path="$1"
  shift

  if [[ -s "${output_path}" && "${FORCE}" != "1" ]]; then
    echo "[skip] ${output_path}"
    return
  fi

  echo "[download] ${output_path}"
  curl --fail --location --retry 3 --retry-delay 3 --user-agent "Mozilla/5.0" "$@" --output "${output_path}"
}

unzip_if_needed() {
  local zip_path="$1"
  local target_dir="$2"
  local expected_file="$3"

  if [[ -s "${target_dir}/${expected_file}" && "${FORCE}" != "1" ]]; then
    echo "[skip] ${target_dir}/${expected_file}"
    return
  fi

  echo "[unzip] ${zip_path}"
  unzip -o "${zip_path}" -d "${target_dir}" >/dev/null
}

download_people_month() {
  local yyyymm="$1"
  local seq="$2"
  local zip_name="LOCAL_PEOPLE_DONG_${yyyymm}.zip"
  local csv_name="LOCAL_PEOPLE_DONG_${yyyymm}.csv"
  local zip_path="${PEOPLE_ZIP_DIR}/${zip_name}"

  if [[ -s "${PEOPLE_DIR}/${csv_name}" && "${FORCE}" != "1" ]]; then
    echo "[skip] ${PEOPLE_DIR}/${csv_name}"
    return
  fi

  download_if_needed "${zip_path}" \
    --request POST \
    --data "infId=OA-14991" \
    --data "seq=${seq}" \
    --data "infSeq=3" \
    "https://datafile.seoul.go.kr/bigfile/iot/inf/nio_download.do?&useCache=false"

  unzip_if_needed "${zip_path}" "${PEOPLE_DIR}" "${csv_name}"
}

download_subway_file() {
  local output_name="$1"
  local url="$2"
  local output_path="${SUBWAY_DOWNLOAD_DIR}/${output_name}"

  download_if_needed "${output_path}" "${url}"

  case "${output_name}" in
    *.zip)
      unzip_if_needed "${output_path}" "${SUBWAY_DIR}" "서울교통공사_일별통행통계_20251231.csv"
      ;;
    *.csv)
      local target_path="${SUBWAY_DIR}/${output_name}"
      if [[ -s "${target_path}" && "${FORCE}" != "1" ]]; then
        echo "[skip] ${target_path}"
      else
        echo "[copy] ${target_path}"
        cp "${output_path}" "${target_path}"
      fi
      ;;
  esac
}

echo "== Download Seoul living population data =="
for month in 01 02 03 04 05 06 07 08 09 10 11 12; do
  download_people_month "2025${month}" "25${month}"
done
download_people_month "202604" "2604"

echo "== Download Seoul Metro daily ridership data =="
download_subway_file \
  "seoul_metro_daily_20250630.csv" \
  "https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003205898&fileDetailSn=1"

download_subway_file \
  "seoul_metro_daily_20251231.zip" \
  "https://www.data.go.kr/cmm/cmm/fileDownload.do?atchFileId=FILE_000000003599825&fileDetailSn=1&insertDataPrcus=N"

echo "== Validate collected data size =="
total_bytes="$(find "${DATASET_DIR}" -type f \( -name '*.csv' -o -name '*.zip' \) -exec wc -c {} + | awk '$2 != "total" {sum += $1} END {print sum + 0}')"
total_mb="$(awk "BEGIN {printf \"%.2f\", ${total_bytes} / 1024 / 1024}")"

echo "Collected data size: ${total_mb} MB"

if awk "BEGIN {exit !(${total_bytes} >= 100 * 1024 * 1024)}"; then
  echo "[ok] Data size requirement satisfied: >= 100 MB"
else
  echo "[error] Data size requirement not satisfied: < 100 MB" >&2
  exit 1
fi

echo "== Done =="
echo "People data: ${PEOPLE_DIR}"
echo "Subway data: ${SUBWAY_DIR}"
