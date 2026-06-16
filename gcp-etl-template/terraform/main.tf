module "bigquery" {
  source = "./modules/bigquery"

  project_id  = var.project_id
  dataset_id  = var.dataset_id
  location    = var.location
  environment = var.environment
}
