import os
from google.cloud import bigquery

client = bigquery.Client()

PROJECT_ID = "project-24a83cf8-3efa-4d50-afd"
DATASET = "purchase_etl_dataset"

def gcs_to_bq_etl(event, context):

    file_name = event["name"]
    bucket = event["bucket"]

    if not file_name.endswith(".csv"):
        print("Skipping non-CSV file")
        return

    print(f"Processing {file_name}")

    stg_table = f"{PROJECT_ID}.{DATASET}.stg_purchase_data"
    gcs_uri = f"gs://{bucket}/{file_name}"

    # ✅ LOAD TO STG
    load_job = client.load_table_from_uri(
        gcs_uri,
        stg_table,
        job_config=bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            write_disposition="WRITE_APPEND"
        )
    )
    load_job.result()
    print("Loaded to STG")

    # ✅ RUN SQL
    sql_path = os.path.join(os.path.dirname(__file__), "transformations.sql")

    with open(sql_path, "r") as f:
        query = f.read()

    client.query(query).result()
    print("STG → TRG completed")