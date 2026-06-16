variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "dataset_id" {
  description = "BigQuery dataset name"
  type        = string
}

variable "location" {
  description = "BigQuery location"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
