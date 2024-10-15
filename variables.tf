variable "region" {
  description = "Region used to create the resources"
  type        = string
  default     = "us-east-1"
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Retention period, in days, of CloudWatch logs"
  type        = number
  default     = 14
}

variable "iam_role_http_lambda_name" {
  description = "Name of the IAM Role used by the No Surprise HTTP Lambda"
  type        = string
  default     = "nosurprise-http"
}

variable "nosurprise_http_lambda_name" {
  description = "Name of the Lambda used to process HTTP requests"
  type        = string
  default     = "nosurprise-http"
}

variable "nosurprise_http_lambda_timeout" {
  description = "The timeout in seconds of the Lambda used to process HTTP requests"
  type        = number
  default     = 10
}

variable "nosurprise_control_plane_version" {
  description = "Version of the No Surprise control plane"
  type        = string
  default     = "v0.0.5"
}

variable "nosurprise_api" {
  description = "Address to No Surprise API"
  type        = string
  default     = "https://api.nosurprisehq.com"
}

variable "nosurprise_api_token" {
  description = "Token used to communicate with the No Surprise API"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to be attached to AWS resources"
  type        = map(string)
  default     = {}
}

locals {
  tags = merge({
    Owner = "No Surprise"
  }, var.tags)
}
