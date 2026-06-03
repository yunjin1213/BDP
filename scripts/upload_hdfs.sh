#!/usr/bin/env bash
set -euo pipefail

# Upload collected raw datasets and small mapping files to HDFS.
# Run this inside the HDP Sandbox / Hadoop VM after data collection.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FINAL_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
DATASET_DIR="${DATASET_DIR:-${FINAL_DIR}/DataSet}"

HDFS_USER="${HDFS_USER:-${USER:-maria_dev}}"
HDFS_BASE_DIR="${HDFS_BASE_DIR:-/user/${HDFS_USER}/bdp}"
HDFS_RAW_DIR="${HDFS_BASE_DIR}/raw"
HDFS_MAPPING_DIR="${HDFS_BASE_DIR}/mapping"
HDFS_PROCESSED_DIR="${HDFS_BASE_DIR}/processed"
HDFS_RESULTS_DIR="${HDFS_BASE_DIR}/results"

PEOPLE_DIR="${DATASET_DIR}/People"
SUBWAY_DIR="${DATASET_DIR}/Subway"
AREA_MAPPING_FILE="${DATASET_DIR}/area_mapping.csv"
EXAM_PERIODS_FILE="${DATASET_DIR}/exam_periods.csv"

OVERWRITE="${OVERWRITE:-1}"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[error] Required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_path() {
  local path="$1"

  if [[ ! -e "${path}" ]]; then
    echo "[error] Required path not found: ${path}" >&2
    echo "[hint] Run: bash scripts/create_reference_data.sh" >&2
    exit 1
  fi
}

hdfs_put() {
  local local_path="$1"
  local hdfs_path="$2"

  if [[ "${OVERWRITE}" == "1" ]]; then
    echo "[overwrite] ${hdfs_path}"
    hdfs dfs -rm -r -f "${hdfs_path}" >/dev/null 2>&1 || true
  elif hdfs dfs -test -e "${hdfs_path}"; then
    echo "[skip] ${hdfs_path}"
    return
  fi

  echo "[put] ${local_path} -> ${hdfs_path}"
  hdfs dfs -put "${local_path}" "${hdfs_path}"
}

hdfs_put_csv_dir() {
  local local_dir="$1"
  local hdfs_dir="$2"
  local file_prefix="$3"
  local index=1
  local staging_dir
  staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/bdp_hdfs_upload.XXXXXX")"

  if [[ "${OVERWRITE}" == "1" ]]; then
    echo "[overwrite] ${hdfs_dir}"
    hdfs dfs -rm -r -f "${hdfs_dir}" >/dev/null 2>&1 || true
  fi

  echo "[mkdir] ${hdfs_dir}"
  hdfs dfs -mkdir -p "${hdfs_dir}"

  echo "[put csv] ${local_dir}/*.csv -> ${hdfs_dir}"
  while IFS= read -r -d '' csv_file; do
    local hdfs_file
    local staged_file
    staged_file="$(printf "%s/%s_%03d.csv" "${staging_dir}" "${file_prefix}" "${index}")"
    hdfs_file="$(printf "%s/%s_%03d.csv" "${hdfs_dir}" "${file_prefix}" "${index}")"
    cp "${csv_file}" "${staged_file}"
    echo "[put] ${csv_file} -> ${hdfs_file}"
    hdfs dfs -put -f "${staged_file}" "${hdfs_file}"
    index=$((index + 1))
  done < <(find "${local_dir}" -maxdepth 1 -type f -name '*.csv' -print0)

  rm -rf "${staging_dir}"
}

require_command hdfs
require_path "${PEOPLE_DIR}"
require_path "${SUBWAY_DIR}"
require_path "${AREA_MAPPING_FILE}"
require_path "${EXAM_PERIODS_FILE}"

echo "== HDFS upload settings =="
echo "DATASET_DIR=${DATASET_DIR}"
echo "HDFS_BASE_DIR=${HDFS_BASE_DIR}"
echo "OVERWRITE=${OVERWRITE}"

echo "== Create HDFS directories =="
hdfs dfs -mkdir -p \
  "${HDFS_RAW_DIR}/people" \
  "${HDFS_RAW_DIR}/subway" \
  "${HDFS_MAPPING_DIR}" \
  "${HDFS_PROCESSED_DIR}" \
  "${HDFS_RESULTS_DIR}"

echo "== Upload raw datasets =="
hdfs_put_csv_dir "${PEOPLE_DIR}" "${HDFS_RAW_DIR}/people" "people"
hdfs_put_csv_dir "${SUBWAY_DIR}" "${HDFS_RAW_DIR}/subway" "subway"

echo "== Upload mapping files =="
hdfs_put "${AREA_MAPPING_FILE}" "${HDFS_MAPPING_DIR}/area_mapping.csv"
hdfs_put "${EXAM_PERIODS_FILE}" "${HDFS_MAPPING_DIR}/exam_periods.csv"

echo "== Uploaded files =="
hdfs dfs -du -h -s "${HDFS_BASE_DIR}" || true
hdfs dfs -ls "${HDFS_BASE_DIR}"
hdfs dfs -ls "${HDFS_RAW_DIR}"
hdfs dfs -ls "${HDFS_MAPPING_DIR}"

echo "== Done =="
