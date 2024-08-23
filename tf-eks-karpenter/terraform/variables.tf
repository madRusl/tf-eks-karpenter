#################################################################
# Global
#################################################################

variable "region" {
  default = "us-east-2"
}
variable "application" {
  default = "tech"
}
variable "environment" {
  default = "dev"
}

#################################################################
# Sensetive variables
#################################################################

variable "aws_profile" {}
variable "custom_public_access_cidr" {}
variable "cluster_admin_arn" {}

#################################################################
# Network
#################################################################

variable "vpc_id" {}

#################################################################
# EKS
#################################################################

variable "create_eks" {
  description = "Whether to create EKS"
  type        = bool
  default     = true
}

variable "cluster_version" {
  description = "Kubernetes <major>.<minor> version to use for the EKS cluster (i.e.: 1.21)"
  type        = string
  default     = 1.30
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "Number of days to retain log events. Default retention - 90 days"
  type        = number
  default     = 1
}

variable "cluster_enabled_log_types" {
  description = "List of default logs to capture from EKS (generic list)"
  type        = list(any)
  default = [
    "audit",
    "api",
    "authenticator"
  ]
}

variable "cluster_security_group_additional_rules" {
  description = "List of additional security group rules to add to the node security group created. Set `source_cluster_security_group = true` inside rules to set the `cluster_security_group` as source"
  type        = any
  default     = {}
}

variable "node_security_group_additional_rules" {
  description = "List of additional security group rules to add to the node security group created. Set `source_cluster_security_group = true` inside rules to set the `cluster_security_group` as source"
  type        = any
  default     = {}
}

variable "worker_instance_type" {
  description = "EKS node instance types for ON-DEMAND (generic map)"
  type        = map(any)
  default = {
    karpenter = "t4g.medium"
  }
}

#########################
# Tags
#########################

variable "tags_default" {
  description = "Default tags in generic format (generic map)"
  type        = map(string)
  default = {
    application = "tech"
    environment = "dev"
    managed_by  = "Terraform"
  }
}

variable "tags_additional" {
  description = "An additional map of tags to add to resources (generic map)"
  type        = map(string)
  default     = {}
}
