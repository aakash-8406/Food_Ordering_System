variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "biterush"
}

variable "lambda_runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs20.x"
}

variable "jwt_secret" {
  description = "Secret key for signing JWT tokens"
  type        = string
  sensitive   = true
}

variable "master_key" {
  description = "Master admin key for managing all restaurants"
  type        = string
  sensitive   = true
}

# ── RDS (existing instance — Terraform does not create it) ────────────────────

variable "db_host" {
  description = "Existing RDS MySQL endpoint hostname (no port)"
  type        = string
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "biterush"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}
