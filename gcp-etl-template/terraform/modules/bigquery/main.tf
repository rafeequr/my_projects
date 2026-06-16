# ---------------------------
# DATASET
# ---------------------------
resource "google_bigquery_dataset" "dataset" {
  dataset_id                 = var.dataset_id
  project                    = var.project_id
  location                   = var.location
  delete_contents_on_destroy = true

  labels = {
    env  = var.environment
    team = "data-eng"
  }
}

# ---------------------------
# STAGING TABLE
# ---------------------------
resource "google_bigquery_table" "stg_table" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "stg_purchase_data"
  project    = var.project_id

  deletion_protection = false

  schema = file("${path.module}/schema/stg_schema.json")

  # ❌ REMOVE partitioning (STRING column cannot be partitioned)

  clustering = ["customer_id", "city"]

  labels = {
    layer = "staging"
  }
}

# ---------------------------
# TARGET TABLE
# ---------------------------
resource "google_bigquery_table" "trg_table" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = "trg_purchase_data"
  project    = var.project_id

  deletion_protection = false

  schema = file("${path.module}/schema/trg_schema.json")

  # ✅ VALID (order_date is DATE in target schema)
  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  clustering = ["customer_id", "product"]

  labels = {
    layer = "target"
  }
}

# ---------------------------
# OUTPUTS
# ---------------------------
output "dataset_id" {
  value = google_bigquery_dataset.dataset.dataset_id
}

output "stg_table_id" {
  value = google_bigquery_table.stg_table.table_id
}

output "trg_table_id" {
  value = google_bigquery_table.trg_table.table_id
}