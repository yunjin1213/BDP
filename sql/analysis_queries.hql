SET hive.mapred.mode=nonstrict;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

USE bdp;

DROP TABLE IF EXISTS result_population_phase_change;
CREATE TABLE result_population_phase_change
STORED AS PARQUET
AS
SELECT
  semester,
  exam_type,
  area_id,
  area_name,
  area_type,
  before_population,
  during_population,
  after_population,
  CASE
    WHEN before_population > 0 THEN (during_population - before_population) / before_population
    ELSE NULL
  END AS during_lift,
  CASE
    WHEN before_population > 0 THEN (after_population - before_population) / before_population
    ELSE NULL
  END AS after_lift
FROM (
  SELECT
    semester,
    exam_type,
    area_id,
    area_name,
    area_type,
    AVG(CASE WHEN phase = 'before' THEN total_population ELSE NULL END) AS before_population,
    AVG(CASE WHEN phase = 'during' THEN total_population ELSE NULL END) AS during_population,
    AVG(CASE WHEN phase = 'after' THEN total_population ELSE NULL END) AS after_population
  FROM area_population
  WHERE phase IN ('before', 'during', 'after')
    AND semester IS NOT NULL
  GROUP BY semester, exam_type, area_id, area_name, area_type
) phase_summary;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/population_phase_change'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  area_id,
  area_name,
  area_type,
  before_population,
  during_population,
  after_population,
  during_lift,
  after_lift
FROM result_population_phase_change
ORDER BY semester, exam_type, after_lift DESC;

DROP TABLE IF EXISTS result_young_population_lift;
CREATE TABLE result_young_population_lift
STORED AS PARQUET
AS
SELECT
  ranked.semester,
  ranked.exam_type,
  ranked.area_id,
  ranked.area_name,
  ranked.area_type,
  ranked.before_young_population,
  ranked.after_young_population,
  ranked.young_after_lift,
  ranked.rank_no
FROM (
  SELECT
    lifted.*,
    ROW_NUMBER() OVER (
      PARTITION BY lifted.semester, lifted.exam_type
      ORDER BY lifted.young_after_lift DESC
    ) AS rank_no
  FROM (
    SELECT
      phase_summary.semester,
      phase_summary.exam_type,
      phase_summary.area_id,
      phase_summary.area_name,
      phase_summary.area_type,
      phase_summary.before_young_population,
      phase_summary.after_young_population,
      CASE
        WHEN phase_summary.before_young_population > 0
        THEN (phase_summary.after_young_population - phase_summary.before_young_population)
          / phase_summary.before_young_population
        ELSE NULL
      END AS young_after_lift
    FROM (
      SELECT
        semester,
        exam_type,
        area_id,
        area_name,
        area_type,
        AVG(CASE WHEN phase = 'before' THEN young_20s_population ELSE NULL END) AS before_young_population,
        AVG(CASE WHEN phase = 'after' THEN young_20s_population ELSE NULL END) AS after_young_population
      FROM area_population
      WHERE phase IN ('before', 'after')
        AND semester IS NOT NULL
      GROUP BY semester, exam_type, area_id, area_name, area_type
    ) phase_summary
  ) lifted
) ranked;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/young_population_lift'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  rank_no,
  area_id,
  area_name,
  area_type,
  before_young_population,
  after_young_population,
  young_after_lift
FROM result_young_population_lift
ORDER BY semester, exam_type, rank_no;

DROP TABLE IF EXISTS result_subway_alighting_lift;
CREATE TABLE result_subway_alighting_lift
STORED AS PARQUET
AS
SELECT
  ranked.semester,
  ranked.exam_type,
  ranked.area_id,
  ranked.area_name,
  ranked.area_type,
  ranked.before_alighting,
  ranked.after_alighting,
  ranked.alighting_after_lift,
  ranked.rank_no
FROM (
  SELECT
    lifted.*,
    ROW_NUMBER() OVER (
      PARTITION BY lifted.semester, lifted.exam_type
      ORDER BY lifted.alighting_after_lift DESC
    ) AS rank_no
  FROM (
    SELECT
      phase_summary.semester,
      phase_summary.exam_type,
      phase_summary.area_id,
      phase_summary.area_name,
      phase_summary.area_type,
      phase_summary.before_alighting,
      phase_summary.after_alighting,
      CASE
        WHEN phase_summary.before_alighting > 0
        THEN (phase_summary.after_alighting - phase_summary.before_alighting)
          / phase_summary.before_alighting
        ELSE NULL
      END AS alighting_after_lift
    FROM (
      SELECT
        semester,
        exam_type,
        area_id,
        area_name,
        area_type,
        AVG(CASE WHEN phase = 'before' THEN alighting_count ELSE NULL END) AS before_alighting,
        AVG(CASE WHEN phase = 'after' THEN alighting_count ELSE NULL END) AS after_alighting
      FROM area_subway
      WHERE phase IN ('before', 'after')
        AND semester IS NOT NULL
      GROUP BY semester, exam_type, area_id, area_name, area_type
    ) phase_summary
  ) lifted
) ranked;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/subway_alighting_lift'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  rank_no,
  area_id,
  area_name,
  area_type,
  before_alighting,
  after_alighting,
  alighting_after_lift
FROM result_subway_alighting_lift
ORDER BY semester, exam_type, rank_no;

DROP TABLE IF EXISTS result_hotplace_rank_compare;
CREATE TABLE result_hotplace_rank_compare
STORED AS PARQUET
AS
SELECT
  compared.semester,
  compared.exam_type,
  compared.area_id,
  compared.area_name,
  compared.area_type,
  compared.after_population,
  compared.after_alighting,
  compared.population_rank,
  compared.subway_rank,
  compared.population_rank - compared.subway_rank AS rank_gap
FROM (
  SELECT
    joined.*,
    ROW_NUMBER() OVER (
      PARTITION BY joined.semester, joined.exam_type
      ORDER BY joined.after_population DESC
    ) AS population_rank,
    ROW_NUMBER() OVER (
      PARTITION BY joined.semester, joined.exam_type
      ORDER BY joined.after_alighting DESC
    ) AS subway_rank
  FROM (
    SELECT
      pop.semester,
      pop.exam_type,
      pop.area_id,
      pop.area_name,
      pop.area_type,
      pop.after_population,
      sub.after_alighting
    FROM (
      SELECT
        semester,
        exam_type,
        area_id,
        area_name,
        area_type,
        AVG(total_population) AS after_population
      FROM area_population
      WHERE phase = 'after'
        AND semester IS NOT NULL
      GROUP BY semester, exam_type, area_id, area_name, area_type
    ) pop
    JOIN (
      SELECT
        semester,
        exam_type,
        area_id,
        AVG(alighting_count) AS after_alighting
      FROM area_subway
      WHERE phase = 'after'
        AND semester IS NOT NULL
      GROUP BY semester, exam_type, area_id
    ) sub
      ON pop.semester = sub.semester
     AND pop.exam_type = sub.exam_type
     AND pop.area_id = sub.area_id
  ) joined
) compared;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/hotplace_rank_compare'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  area_id,
  area_name,
  area_type,
  after_population,
  after_alighting,
  population_rank,
  subway_rank,
  rank_gap
FROM result_hotplace_rank_compare
ORDER BY semester, exam_type, population_rank;

DROP TABLE IF EXISTS result_area_type_change;
CREATE TABLE result_area_type_change
STORED AS PARQUET
AS
SELECT
  merged.semester,
  merged.exam_type,
  merged.area_type,
  merged.before_population,
  merged.after_population,
  CASE
    WHEN merged.before_population > 0
    THEN (merged.after_population - merged.before_population) / merged.before_population
    ELSE NULL
  END AS population_after_lift,
  merged.before_young_population,
  merged.after_young_population,
  CASE
    WHEN merged.before_young_population > 0
    THEN (merged.after_young_population - merged.before_young_population) / merged.before_young_population
    ELSE NULL
  END AS young_after_lift,
  merged.before_alighting,
  merged.after_alighting,
  CASE
    WHEN merged.before_alighting > 0
    THEN (merged.after_alighting - merged.before_alighting) / merged.before_alighting
    ELSE NULL
  END AS alighting_after_lift
FROM (
  SELECT
    pop.semester,
    pop.exam_type,
    pop.area_type,
    pop.before_population,
    pop.after_population,
    pop.before_young_population,
    pop.after_young_population,
    sub.before_alighting,
    sub.after_alighting
  FROM (
    SELECT
      semester,
      exam_type,
      area_type,
      AVG(CASE WHEN phase = 'before' THEN total_population ELSE NULL END) AS before_population,
      AVG(CASE WHEN phase = 'after' THEN total_population ELSE NULL END) AS after_population,
      AVG(CASE WHEN phase = 'before' THEN young_20s_population ELSE NULL END) AS before_young_population,
      AVG(CASE WHEN phase = 'after' THEN young_20s_population ELSE NULL END) AS after_young_population
    FROM area_population
    WHERE phase IN ('before', 'after')
      AND semester IS NOT NULL
    GROUP BY semester, exam_type, area_type
  ) pop
  JOIN (
    SELECT
      semester,
      exam_type,
      area_type,
      AVG(CASE WHEN phase = 'before' THEN alighting_count ELSE NULL END) AS before_alighting,
      AVG(CASE WHEN phase = 'after' THEN alighting_count ELSE NULL END) AS after_alighting
    FROM area_subway
    WHERE phase IN ('before', 'after')
      AND semester IS NOT NULL
    GROUP BY semester, exam_type, area_type
  ) sub
    ON pop.semester = sub.semester
   AND pop.exam_type = sub.exam_type
   AND pop.area_type = sub.area_type
) merged;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/area_type_change'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  area_type,
  before_population,
  after_population,
  population_after_lift,
  before_young_population,
  after_young_population,
  young_after_lift,
  before_alighting,
  after_alighting,
  alighting_after_lift
FROM result_area_type_change
ORDER BY semester, exam_type, area_type;

DROP TABLE IF EXISTS result_time_band_young_lift;
CREATE TABLE result_time_band_young_lift
STORED AS PARQUET
AS
SELECT
  ranked.semester,
  ranked.exam_type,
  ranked.area_id,
  ranked.area_name,
  ranked.area_type,
  ranked.time_band,
  ranked.before_young_population,
  ranked.after_young_population,
  ranked.young_after_lift,
  ranked.rank_no
FROM (
  SELECT
    lifted.*,
    ROW_NUMBER() OVER (
      PARTITION BY lifted.semester, lifted.exam_type, lifted.time_band
      ORDER BY lifted.young_after_lift DESC
    ) AS rank_no
  FROM (
    SELECT
      phase_summary.semester,
      phase_summary.exam_type,
      phase_summary.area_id,
      phase_summary.area_name,
      phase_summary.area_type,
      phase_summary.time_band,
      phase_summary.before_young_population,
      phase_summary.after_young_population,
      CASE
        WHEN phase_summary.before_young_population > 0
        THEN (phase_summary.after_young_population - phase_summary.before_young_population)
          / phase_summary.before_young_population
        ELSE NULL
      END AS young_after_lift
    FROM (
      SELECT
        semester,
        exam_type,
        area_id,
        area_name,
        area_type,
        time_band,
        AVG(CASE WHEN phase = 'before' THEN young_20s_population ELSE NULL END) AS before_young_population,
        AVG(CASE WHEN phase = 'after' THEN young_20s_population ELSE NULL END) AS after_young_population
      FROM area_population
      WHERE phase IN ('before', 'after')
        AND semester IS NOT NULL
      GROUP BY semester, exam_type, area_id, area_name, area_type, time_band
    ) phase_summary
  ) lifted
) ranked;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/time_band_young_lift'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  time_band,
  rank_no,
  area_id,
  area_name,
  area_type,
  before_young_population,
  after_young_population,
  young_after_lift
FROM result_time_band_young_lift
ORDER BY semester, exam_type, time_band, rank_no;

DROP TABLE IF EXISTS result_weekend_effect;
CREATE TABLE result_weekend_effect
STORED AS PARQUET
AS
SELECT
  merged.semester,
  merged.exam_type,
  merged.area_id,
  merged.area_name,
  merged.area_type,
  merged.is_weekend,
  merged.before_young_population,
  merged.after_young_population,
  CASE
    WHEN merged.before_young_population > 0
    THEN (merged.after_young_population - merged.before_young_population)
      / merged.before_young_population
    ELSE NULL
  END AS young_after_lift,
  merged.before_alighting,
  merged.after_alighting,
  CASE
    WHEN merged.before_alighting > 0
    THEN (merged.after_alighting - merged.before_alighting) / merged.before_alighting
    ELSE NULL
  END AS alighting_after_lift
FROM (
  SELECT
    pop.semester,
    pop.exam_type,
    pop.area_id,
    pop.area_name,
    pop.area_type,
    pop.is_weekend,
    pop.before_young_population,
    pop.after_young_population,
    sub.before_alighting,
    sub.after_alighting
  FROM (
    SELECT
      semester,
      exam_type,
      area_id,
      area_name,
      area_type,
      is_weekend,
      AVG(CASE WHEN phase = 'before' THEN young_20s_population ELSE NULL END) AS before_young_population,
      AVG(CASE WHEN phase = 'after' THEN young_20s_population ELSE NULL END) AS after_young_population
    FROM area_population
    WHERE phase IN ('before', 'after')
      AND semester IS NOT NULL
    GROUP BY semester, exam_type, area_id, area_name, area_type, is_weekend
  ) pop
  JOIN (
    SELECT
      semester,
      exam_type,
      area_id,
      is_weekend,
      AVG(CASE WHEN phase = 'before' THEN alighting_count ELSE NULL END) AS before_alighting,
      AVG(CASE WHEN phase = 'after' THEN alighting_count ELSE NULL END) AS after_alighting
    FROM area_subway
    WHERE phase IN ('before', 'after')
      AND semester IS NOT NULL
    GROUP BY semester, exam_type, area_id, is_weekend
  ) sub
    ON pop.semester = sub.semester
   AND pop.exam_type = sub.exam_type
   AND pop.area_id = sub.area_id
   AND pop.is_weekend = sub.is_weekend
) merged;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/weekend_effect'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  is_weekend,
  area_id,
  area_name,
  area_type,
  before_young_population,
  after_young_population,
  young_after_lift,
  before_alighting,
  after_alighting,
  alighting_after_lift
FROM result_weekend_effect
ORDER BY semester, exam_type, is_weekend, young_after_lift DESC;

DROP TABLE IF EXISTS result_after_vs_normal;
CREATE TABLE result_after_vs_normal
STORED AS PARQUET
AS
SELECT
  merged.area_id,
  merged.area_name,
  merged.area_type,
  merged.semester,
  merged.exam_type,
  merged.normal_young_population,
  merged.after_young_population,
  CASE
    WHEN merged.normal_young_population > 0
    THEN (merged.after_young_population - merged.normal_young_population)
      / merged.normal_young_population
    ELSE NULL
  END AS young_after_vs_normal_lift,
  merged.normal_total_population,
  merged.after_total_population,
  CASE
    WHEN merged.normal_total_population > 0
    THEN (merged.after_total_population - merged.normal_total_population)
      / merged.normal_total_population
    ELSE NULL
  END AS total_after_vs_normal_lift
FROM (
  SELECT
    after_summary.area_id,
    after_summary.area_name,
    after_summary.area_type,
    after_summary.semester,
    after_summary.exam_type,
    normal_summary.normal_young_population,
    after_summary.after_young_population,
    normal_summary.normal_total_population,
    after_summary.after_total_population
  FROM (
    SELECT
      area_id,
      area_name,
      area_type,
      AVG(young_20s_population) AS normal_young_population,
      AVG(total_population) AS normal_total_population
    FROM area_population
    WHERE phase = 'normal'
    GROUP BY area_id, area_name, area_type
  ) normal_summary
  JOIN (
    SELECT
      semester,
      exam_type,
      area_id,
      area_name,
      area_type,
      AVG(young_20s_population) AS after_young_population,
      AVG(total_population) AS after_total_population
    FROM area_population
    WHERE phase = 'after'
      AND semester IS NOT NULL
    GROUP BY semester, exam_type, area_id, area_name, area_type
  ) after_summary
    ON normal_summary.area_id = after_summary.area_id
) merged;

INSERT OVERWRITE DIRECTORY '${hivevar:results_dir}/after_vs_normal'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
SELECT
  semester,
  exam_type,
  area_id,
  area_name,
  area_type,
  normal_young_population,
  after_young_population,
  young_after_vs_normal_lift,
  normal_total_population,
  after_total_population,
  total_after_vs_normal_lift
FROM result_after_vs_normal
ORDER BY semester, exam_type, young_after_vs_normal_lift DESC;
