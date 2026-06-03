SET hive.execution.engine=mr;

CREATE DATABASE IF NOT EXISTS bdp;
USE bdp;

DROP TABLE IF EXISTS area_population;
CREATE EXTERNAL TABLE area_population (
  `date` DATE,
  `year` INT,
  `month` INT,
  day_of_week STRING,
  day_of_week_num INT,
  is_weekend BOOLEAN,
  `hour` INT,
  time_band STRING,
  area_id STRING,
  area_name STRING,
  area_type STRING,
  phase STRING,
  exam_type STRING,
  semester INT,
  total_population DOUBLE,
  young_20s_population DOUBLE,
  young_20s_ratio DOUBLE
)
STORED AS PARQUET
LOCATION '${hivevar:hdfs_base_dir}/processed/area_population';

DROP TABLE IF EXISTS area_subway;
CREATE EXTERNAL TABLE area_subway (
  `date` DATE,
  `year` INT,
  `month` INT,
  day_of_week STRING,
  day_of_week_num INT,
  is_weekend BOOLEAN,
  `hour` INT,
  time_band STRING,
  area_id STRING,
  area_name STRING,
  area_type STRING,
  phase STRING,
  exam_type STRING,
  semester INT,
  alighting_count BIGINT
)
STORED AS PARQUET
LOCATION '${hivevar:hdfs_base_dir}/processed/area_subway';

DROP TABLE IF EXISTS result_population_phase_change;
DROP TABLE IF EXISTS result_young_population_lift;
DROP TABLE IF EXISTS result_subway_alighting_lift;
DROP TABLE IF EXISTS result_hotplace_rank_compare;
DROP TABLE IF EXISTS result_area_type_change;
