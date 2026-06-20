variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCE machine type for all nodes"
  type        = string
  default     = "e2-small"
}

variable "os_image" {
  description = "OS image for the VMs"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "service_account_email" {
  description = "Service account email for the VMs"
  type        = string
}

variable "state_bucket" {
  description = "GCS bucket name for Terraform remote state"
  type        = string
}

variable "domain" {
  description = "Domain name for the LLM service (e.g. llm.example.com)"
  type        = string
}
