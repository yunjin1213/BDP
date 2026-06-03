from pyspark.sql import functions as F


def clean_column_name(name):
    return name.replace("\ufeff", "").replace('"', "").strip().lstrip("?")


def clean_columns(df):
    result = df
    for column_name in df.columns:
        cleaned = clean_column_name(column_name)
        if cleaned != column_name:
            result = result.withColumnRenamed(column_name, cleaned)
    return result


def add_date_columns(df, date_col="date"):
    return (
        df.withColumn("year", F.year(F.col(date_col)))
        .withColumn("month", F.month(F.col(date_col)))
        .withColumn("day_of_week", F.date_format(F.col(date_col), "E"))
        .withColumn("day_of_week_num", F.dayofweek(F.col(date_col)))
        .withColumn("is_weekend", F.col("day_of_week_num").isin(1, 7))
    )


def add_time_band(df, hour_col="hour"):
    return df.withColumn(
        "time_band",
        F.when((F.col(hour_col) >= 18) & (F.col(hour_col) < 21), F.lit("evening"))
        .when((F.col(hour_col) >= 21) & (F.col(hour_col) < 24), F.lit("night"))
        .when((F.col(hour_col) >= 0) & (F.col(hour_col) <= 2), F.lit("late_night"))
        .otherwise(F.lit("other")),
    )


def add_exam_phase(df, exam_periods, date_col="date"):
    periods = (
        exam_periods.withColumn("start_date", F.to_date(F.col("start_date")))
        .withColumn("end_date", F.to_date(F.col("end_date")))
        .select(
            F.col("year").cast("int").alias("exam_year"),
            F.col("semester").cast("int").alias("semester"),
            "exam_type",
            "phase",
            "start_date",
            "end_date",
        )
    )

    joined = df.join(
        F.broadcast(periods),
        (F.col(date_col) >= F.col("start_date")) & (F.col(date_col) <= F.col("end_date")),
        "left",
    )

    return (
        joined.withColumn("phase", F.coalesce(F.col("phase"), F.lit("normal")))
        .withColumn("exam_type", F.coalesce(F.col("exam_type"), F.lit("normal")))
        .withColumn("semester", F.col("semester").cast("int"))
        .drop("start_date", "end_date")
    )
