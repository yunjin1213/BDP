import argparse

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

from utils import add_date_columns, add_exam_phase, add_time_band, clean_columns


TIME_COLUMNS = [
    ("18-19시간대", 18),
    ("19-20시간대", 19),
    ("20-21시간대", 20),
    ("21-22시간대", 21),
    ("22-23시간대", 22),
    ("23-24시간대", 23),
    ("24시간대이후", 0),
]

STATION_NAME_ROWS = [
    ("홍대입구", "hongik_univ"),
    ("합정", "hapjeong"),
    ("상수", "sangsu"),
    ("신촌", "shinchon"),
    ("이대", "ewha_womans_univ"),
    ("건대입구", "konkuk_univ"),
    ("혜화", "hyehwa"),
    ("서울대입구(관악구청)", "seoul_nat_univ_gwanakgu_office"),
    ("강남", "gangnam"),
    ("역삼", "yeoksam"),
    ("이태원", "itaewon"),
    ("녹사평(용산구청)", "noksapyeong_yongsangu_office"),
]


def parse_args():
    parser = argparse.ArgumentParser(description="Preprocess Seoul subway ridership data.")
    parser.add_argument("--input", default="/bdp/raw/subway/*.csv")
    parser.add_argument("--mapping", default="/bdp/mapping/area_mapping.csv")
    parser.add_argument("--exam-periods", default="/bdp/mapping/exam_periods.csv")
    parser.add_argument("--output", default="/bdp/processed/area_subway")
    return parser.parse_args()


def main():
    args = parse_args()
    spark = (
        SparkSession.builder.appName("BDPPreprocessSubway")
        .enableHiveSupport()
        .getOrCreate()
    )

    raw = (
        spark.read.option("header", "true")
        .option("inferSchema", "false")
        .option("encoding", "CP949")
        .csv(args.input)
    )
    raw = clean_columns(raw)

    value_structs = []
    for column_name, hour in TIME_COLUMNS:
        value_structs.append(
            F.struct(
                F.lit(hour).alias("hour"),
                F.regexp_replace(F.col(column_name), ",", "").cast("long").alias("passenger_count"),
            )
        )

    subway = (
        raw.filter(F.col("승하차구분") == "하차")
        .select(
            F.col("수송일자").cast("string").alias("date_id"),
            F.col("호선명").alias("raw_line_name"),
            F.col("역명").alias("raw_station_name"),
            F.col("승객유형").alias("passenger_type"),
            F.explode(F.array(*value_structs)).alias("time_value"),
        )
        .select(
            "date_id",
            "raw_line_name",
            "raw_station_name",
            "passenger_type",
            F.col("time_value.hour").alias("hour"),
            F.col("time_value.passenger_count").alias("passenger_count"),
        )
        .withColumn("date", F.to_date(F.col("date_id"), "yyyyMMdd"))
        .filter(F.col("date").isNotNull())
        .filter(F.col("passenger_count").isNotNull())
    )

    subway = add_time_band(subway)
    subway = subway.filter(F.col("time_band") != "other")

    station_names = spark.createDataFrame(STATION_NAME_ROWS, ["raw_station_name", "station_name"])

    area_mapping = (
        spark.read.option("header", "true")
        .option("inferSchema", "false")
        .csv(args.mapping)
        .select("area_id", "area_name", "area_type", "station_name")
        .dropDuplicates(["area_id", "station_name"])
    )

    exam_periods = spark.read.option("header", "true").option("inferSchema", "false").csv(args.exam_periods)

    joined = subway.join(F.broadcast(station_names), "raw_station_name", "inner")
    joined = joined.join(F.broadcast(area_mapping), "station_name", "inner")
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
        .agg(F.sum("passenger_count").alias("alighting_count"))
    )

    result.write.mode("overwrite").parquet(args.output)
    spark.stop()


if __name__ == "__main__":
    main()
