#!/usr/bin/env bash
set -euo pipefail

# Create small reference CSV files used by the Spark/Hive analysis.
# These files define the analysis area mapping and representative exam periods.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FINAL_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"
DATASET_DIR="${DATASET_DIR:-${FINAL_DIR}/DataSet}"

AREA_MAPPING_FILE="${DATASET_DIR}/area_mapping.csv"
EXAM_PERIODS_FILE="${DATASET_DIR}/exam_periods.csv"
OVERWRITE="${OVERWRITE:-1}"

write_file() {
  local output_path="$1"
  local label="$2"

  if [[ -s "${output_path}" && "${OVERWRITE}" != "1" ]]; then
    echo "[skip] ${output_path}"
    return
  fi

  echo "[write] ${label}: ${output_path}"
  mkdir -p "$(dirname "${output_path}")"
  cat >"${output_path}"
}

echo "== Create reference data =="
echo "DATASET_DIR=${DATASET_DIR}"
echo "OVERWRITE=${OVERWRITE}"

write_file "${AREA_MAPPING_FILE}" "area mapping" <<'CSV'
area_id,area_name,area_type,dong_code,dong_name,station_name,line_name,notes
hongdae,hongdae_sangsu_hapjeong,nightlife,11440660,seogyo_dong,hongik_univ,line_2,main hongdae commercial area
hongdae,hongdae_sangsu_hapjeong,nightlife,11440680,hapjeong_dong,hapjeong,line_2,hapjeong station area
hongdae,hongdae_sangsu_hapjeong,nightlife,11440655,seogang_dong,sangsu,line_6,sangsu station area
shinchon,shinchon_ewha,university,11410585,shinchon_dong,shinchon,line_2,main shinchon university district
shinchon,shinchon_ewha,university,11410585,shinchon_dong,ewha_womans_univ,line_2,ewha station mapped to shinchon dong
konkuk,konkuk_univ,university_nightlife,11215710,hwayang_dong,konkuk_univ,line_2,konkuk university nightlife district
konkuk,konkuk_univ,university_nightlife,11215847,jayang4_dong,konkuk_univ,line_7,south side of konkuk university station
daehakro,daehakro_hyehwa,culture_university,11110650,hyehwa_dong,hyehwa,line_4,daehakro culture and university district
snu,seoul_nat_univ_syarosu,university,11620575,haengun_dong,seoul_nat_univ_gwanakgu_office,line_2,seoul national university station area
snu,seoul_nat_univ_syarosu,university,11620595,cheongnyong_dong,seoul_nat_univ_gwanakgu_office,line_2,syarosu-gil nearby area
gangnam,gangnam_yeoksam,nightlife_business,11680640,yeoksam1_dong,gangnam,line_2,gangnam station nightlife and business district
gangnam,gangnam_yeoksam,nightlife_business,11680650,yeoksam2_dong,yeoksam,line_2,yeoksam station business district
itaewon,itaewon,nightlife,11170650,itaewon1_dong,itaewon,line_6,main itaewon nightlife district
itaewon,itaewon,nightlife,11170660,itaewon2_dong,noksapyeong_yongsangu_office,line_6,noksapyeong station nearby area
CSV

write_file "${EXAM_PERIODS_FILE}" "exam periods" <<'CSV'
year,semester,exam_type,phase,start_date,end_date,notes
2025,1,midterm,before,2025-04-14,2025-04-20,7 days before exam
2025,1,midterm,during,2025-04-21,2025-04-30,midterm exam period
2025,1,midterm,after,2025-05-01,2025-05-07,7 days after exam
2025,1,final,before,2025-06-02,2025-06-08,7 days before exam
2025,1,final,during,2025-06-09,2025-06-16,final exam period
2025,1,final,after,2025-06-17,2025-06-23,7 days after exam
2025,2,midterm,before,2025-10-13,2025-10-19,7 days before exam
2025,2,midterm,during,2025-10-20,2025-10-27,midterm exam period
2025,2,midterm,after,2025-10-28,2025-11-03,7 days after exam
2025,2,final,before,2025-11-29,2025-12-05,7 days before exam
2025,2,final,during,2025-12-06,2025-12-12,final exam period
2025,2,final,after,2025-12-13,2025-12-19,7 days after exam
2026,1,midterm,before,2026-04-13,2026-04-19,7 days before exam
2026,1,midterm,during,2026-04-20,2026-04-27,midterm exam period
2026,1,midterm,after,2026-04-28,2026-04-30,partial after period because May 2026 data is not available
CSV

echo "== Done =="
echo "Area mapping: ${AREA_MAPPING_FILE}"
echo "Exam periods: ${EXAM_PERIODS_FILE}"
