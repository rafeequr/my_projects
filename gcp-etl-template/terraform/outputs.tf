output "dataset_id" {
  value = module.bigquery.dataset_id
}

output "stg_table" {
  value = module.bigquery.stg_table_id
}

output "trg_table" {
  value = module.bigquery.trg_table_id
}