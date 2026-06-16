from airflow import DAG
from airflow.utils.dates import days_ago
from airflow.providers.google.cloud.operators.dataproc import DataprocCreateBatchOperator
from airflow.providers.google.cloud.sensors.gcs import GCSObjectsWithPrefixExistenceSensor
from airflow.operators.python import PythonOperator
from datetime import timedelta

PROJECT_ID = "your-gcp-project"
REGION = "asia-south1"
GCS_BUCKET = "your-bucket"

PYSPARK_URI = f"gs://{GCS_BUCKET}/code/pyspark_etl.py"
CONFIG_URI = f"gs://{GCS_BUCKET}/config/pipeline_config.yaml"

default_args = {
    "owner": "airflow",
    "retries": 2,
    "retry_delay": timedelta(minutes=5)
}

with DAG(
    dag_id="generic_gcp_etl_pipeline",
    default_args=default_args,
    schedule_interval="@daily",
    start_date=days_ago(1),
    catchup=False
) as dag:

    # 1. Wait for File
    wait_for_file = GCSObjectsWithPrefixExistenceSensor(
        task_id="wait_for_input_file",
        bucket=GCS_BUCKET,
        prefix="raw/",
        timeout=600
    )

    # 2. Run Spark Job (Serverless Dataproc)
    run_spark = DataprocCreateBatchOperator(
        task_id="run_pyspark_etl",
        project_id=PROJECT_ID,
        region=REGION,
        batch={
            "pyspark_batch": {
                "main_python_file_uri": PYSPARK_URI,
                "args": [CONFIG_URI],
            },
        },
    )

    def audit_log():
        print("Pipeline executed successfully")

    audit_task = PythonOperator(
        task_id="audit_log",
        python_callable=audit_log
    )

    wait_for_file >> run_spark >> audit_task