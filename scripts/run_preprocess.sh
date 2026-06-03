#!/usr/bin/env bash
set -euo pipefail

# Run Spark preprocessing jobs after raw data has been uploaded to HDFS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HDFS_BASE_DIR="${HDFS_BASE_DIR:-/bdp}"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[error] Required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_command spark-submit

echo "== Spark preprocessing settings =="
echo "PROJECT_DIR=${PROJECT_DIR}"
echo "HDFS_BASE_DIR=${HDFS_BASE_DIR}"

echo "== Preprocess living population =="
spark-submit "${PROJECT_DIR}/src/preprocess_people.py" \
  --input "${HDFS_BASE_DIR}/raw/people/*.csv" \
  --mapping "${HDFS_BASE_DIR}/mapping/area_mapping.csv" \
  --exam-periods "${HDFS_BASE_DIR}/mapping/exam_periods.csv" \
  --output "${HDFS_BASE_DIR}/processed/area_population"

echo "== Preprocess subway ridership =="
spark-submit "${PROJECT_DIR}/src/preprocess_subway.py" \
  --input "${HDFS_BASE_DIR}/raw/subway/*.csv" \
  --mapping "${HDFS_BASE_DIR}/mapping/area_mapping.csv" \
  --exam-periods "${HDFS_BASE_DIR}/mapping/exam_periods.csv" \
  --output "${HDFS_BASE_DIR}/processed/area_subway"

echo "== Done =="
echo "Population output: ${HDFS_BASE_DIR}/processed/area_population"
echo "Subway output: ${HDFS_BASE_DIR}/processed/area_subway"
