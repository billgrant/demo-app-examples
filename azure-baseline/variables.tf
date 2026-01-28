variable "region" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "demo-app-rg"
}

variable "container_name" {
  description = "Name of the container instance"
  type        = string
  default     = "demo-app-aci"
}

variable "dns_suffix" {
  description = "Suffix for DNS name label (override if deploying multiple instances)"
  type        = string
  default     = "001"
}
