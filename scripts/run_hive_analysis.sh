#!/usr/bin/env bash
set -euo pipefail

# Register Spark preprocessing outputs as Hive external tables and run analysis queries.
# Run this inside the HDP Sandbox / Hadoop VM after scripts/run_preprocess.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
HDFS_USER="${HDFS_USER:-${USER:-maria_dev}}"
HDFS_BASE_DIR="${HDFS_BASE_DIR:-/user/${HDFS_USER}/bdp}"
RESULTS_DIR="${RESULTS_DIR:-${HDFS_BASE_DIR}/results}"

require_command() {
  local command_name="$1"

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    echo "[error] Required command not found: ${command_name}" >&2
    exit 1
  fi
}

require_command hdfs
require_command hive

echo "== Hive analysis settings =="
echo "PROJECT_DIR=${PROJECT_DIR}"
echo "HDFS_BASE_DIR=${HDFS_BASE_DIR}"
echo "RESULTS_DIR=${RESULTS_DIR}"

echo "== Prepare results directory =="
hdfs dfs -mkdir -p "${RESULTS_DIR}"
hdfs dfs -chmod -R 777 "${HDFS_BASE_DIR}/processed" "${RESULTS_DIR}"

echo "== Create Hive external tables =="
hive \
  --hivevar hdfs_base_dir="${HDFS_BASE_DIR}" \
  --hivevar results_dir="${RESULTS_DIR}" \
  -f "${PROJECT_DIR}/sql/create_tables.hql"

echo "== Run Hive analysis queries =="
hive \
  --hivevar hdfs_base_dir="${HDFS_BASE_DIR}" \
  --hivevar results_dir="${RESULTS_DIR}" \
  -f "${PROJECT_DIR}/sql/analysis_queries.hql"

echo "== Analysis results =="
hdfs dfs -ls "${RESULTS_DIR}" || true

echo "== Done =="
echo "Hive database: bdp"
echo "Results directory: ${RESULTS_DIR}"
