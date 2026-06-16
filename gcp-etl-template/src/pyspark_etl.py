import yaml
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *

def load_config(config_path):
    with open(config_path, "r") as f:
        return yaml.safe_load(f)

def apply_schema(df, schema_config):
    for col_def in schema_config:
        if col_def["type"] == "integer":
            df = df.withColumn(col_def["name"], col(col_def["name"]).cast(IntegerType()))
        elif col_def["type"] == "double":
            df = df.withColumn(col_def["name"], col(col_def["name"]).cast(DoubleType()))
        elif col_def["type"] == "date":
            df = df.withColumn(col_def["name"], to_date(col(col_def["name"])))
        else:
            df = df.withColumn(col_def["name"], col(col_def["name"]).cast(StringType()))
    return df

def apply_transformations(df, config):
    tf = config["transformations"]

    # Drop duplicates
    if tf.get("drop_duplicates"):
        df = df.dropDuplicates()

    # Fill nulls
    if "fill_nulls" in tf:
        df = df.fillna(tf["fill_nulls"])

    # Filters
    if "filters" in tf:
        for f in tf["filters"]:
            df = df.filter(f)

    # Rename columns
    if "rename_columns" in tf:
        for old, new in tf["rename_columns"].items():
            df = df.withColumnRenamed(old, new)

    # Derived columns
    if "derived_columns" in tf:
        for col_name, expr_str in tf["derived_columns"].items():
            df = df.withColumn(col_name, expr(expr_str))

    return df

def data_quality_checks(df):
    errors = []
    
    if df.count() == 0:
        errors.append("Empty dataset")
    
    # Null check example
    null_counts = df.select([count(when(col(c).isNull(), c)).alias(c) for c in df.columns])
    null_dict = null_counts.collect()[0].asDict()
    
    for k, v in null_dict.items():
        if v > 0:
            errors.append(f"Null found in {k}: {v}")
    
    if errors:
        raise Exception(f"Data Quality Failed: {errors}")

def main(config_path):
    spark = SparkSession.builder.appName("GenericETL").getOrCreate()

    config = load_config(config_path)

    # Read
    df = spark.read.option("header", True).csv(config["gcs"]["input_path"])

    # Apply schema
    df = apply_schema(df, config["schema"])

    # Transform
    df = apply_transformations(df, config)

    # Data Quality
    data_quality_checks(df)

    # Write to BigQuery
    df.write \
      .format("bigquery") \
      .option("table", f"{config['project_id']}.{config['bigquery']['dataset']}.{config['bigquery']['table']}") \
      .mode(config["bigquery"]["write_mode"]) \
      .save()

    spark.stop()

if __name__ == "__main__":
    import sys
    main(sys.argv[1])
    