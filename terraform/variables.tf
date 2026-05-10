variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
  default     = "devsecops-prod"
}

variable "environment" {
  description = "Environment tag (staging | production)"
  type        = string
  default     = "production"
}
