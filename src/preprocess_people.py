import argparse
import os

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

from utils import add_date_columns, add_exam_phase, add_time_band, clean_columns


def parse_args():
    parser = argparse.ArgumentParser(description="Preprocess Seoul living population data.")
    hdfs_base_dir = os.environ.get("HDFS_BASE_DIR", "/user/{}/bdp".format(os.environ.get("USER", "maria_dev")))
    parser.add_argument("--input", default="{}/raw/people/*.csv".format(hdfs_base_dir))
    parser.add_argument("--mapping", default="{}/mapping/area_mapping.csv".format(hdfs_base_dir))
    parser.add_argument("--exam-periods", default="{}/mapping/exam_periods.csv".format(hdfs_base_dir))
    parser.add_argument("--output", default="{}/processed/area_population".format(hdfs_base_dir))
    return parser.parse_args()


def main():
    args = parse_args()
    spark = (
        SparkSession.builder.appName("BDPPreprocessPeople")
        .enableHiveSupport()
        .getOrCreate()
    )

    raw = (
        spark.read.option("header", "true")
        .option("inferSchema", "false")
        .option("encoding", "UTF-8")
        .csv(args.input)
    )
    raw = clean_columns(raw)

    people = (
        raw.select(
            F.col("기준일ID").cast("string").alias("date_id"),
            F.col("시간대구분").cast("int").alias("hour"),
            F.col("행정동코드").cast("string").alias("dong_code"),
            F.col("총생활인구수").cast("double").alias("total_population"),
            F.col("남자20세부터24세생활인구수").cast("double").alias("male_20_24"),
            F.col("남자25세부터29세생활인구수").cast("double").alias("male_25_29"),
            F.col("여자20세부터24세생활인구수").cast("double").alias("female_20_24"),
            F.col("여자25세부터29세생활인구수").cast("double").alias("female_25_29"),
        )
        .withColumn("date", F.to_date(F.col("date_id"), "yyyyMMdd"))
        .withColumn(
            "young_20s_population",
            F.coalesce(F.col("male_20_24"), F.lit(0.0))
            + F.coalesce(F.col("male_25_29"), F.lit(0.0))
            + F.coalesce(F.col("female_20_24"), F.lit(0.0))
            + F.coalesce(F.col("female_25_29"), F.lit(0.0)),
        )
        .filter(F.col("date").isNotNull())
        .filter(F.col("hour").isNotNull())
    )

    people = add_time_band(people)
    people = people.filter(F.col("time_band") != "other")

    area_mapping = (
        spark.read.option("header", "true")
        .option("inferSchema", "false")
        .csv(args.mapping)
        .select("area_id", "area_name", "area_type", F.col("dong_code").cast("string").alias("dong_code"))
        .dropDuplicates(["area_id", "dong_code"])
    )

    exam_periods = spark.read.option("header", "true").option("inferSchema", "false").csv(args.exam_periods)

    joined = people.join(F.broadcast(area_mapping), "dong_code", "inner")
    joined = add_date_columns(joined)
    joined = add_exam_phase(joined, exam_periods)

    result = (
        joined.groupBy(
            "date",
            "year",
            "month",
            "day_of_week",
            "day_of_week_num",
            "is_weekend",
            "hour",
            "time_band",
            "area_id",
            "area_name",
            "area_type",
            "phase",
            "exam_type",
            "semester",
        )
        .agg(
            F.sum("total_population").alias("total_population"),
            F.sum("young_20s_population").alias("young_20s_population"),
        )
        .withColumn(
            "young_20s_ratio",
            F.when(F.col("total_population") > 0, F.col("young_20s_population") / F.col("total_population")).otherwise(F.lit(None)),
        )
    )

    result.write.mode("overwrite").parquet(args.output)
    spark.stop()


if __name__ == "__main__":
    main()
