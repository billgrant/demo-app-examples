terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    demoapp = {
      source  = "billgrant/demoapp"
      version = "~> 0.1"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals - Construct predictable FQDN
# -----------------------------------------------------------------------------

locals {
  dns_name = "${var.container_name}-${var.dns_suffix}"
  fqdn     = "${local.dns_name}.${var.region}.azurecontainer.io"
}

# -----------------------------------------------------------------------------
# Azure Provider - Creates the container instance
# -----------------------------------------------------------------------------

provider "azurerm" {
  features {}
}

# Resource group to hold the container
resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.region
}

# Container instance running demo-app
resource "azurerm_container_group" "demo_app" {
  name                = var.container_name
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  os_type             = "Linux"
  dns_name_label      = local.dns_name
  ip_address_type     = "Public"

  container {
    name   = "demo-app"
    image  = "ghcr.io/billgrant/demo-app:latest"
    cpu    = "0.5"
    memory = "1.0"

    ports {
      port     = 8080
      protocol = "TCP"
    }

    # Liveness probe to check health
    liveness_probe {
      http_get {
        path   = "/health"
        port   = 8080
        scheme = "http"
      }
      initial_delay_seconds = 5
      period_seconds        = 10
    }
  }
}

# -----------------------------------------------------------------------------
# Wait for Health - Ensures the app is responding before proceeding
# -----------------------------------------------------------------------------

# Give the container a moment to fully start and pass health checks
resource "time_sleep" "wait_for_healthy" {
  depends_on = [azurerm_container_group.demo_app]

  create_duration = "60s"
}

# -----------------------------------------------------------------------------
# HTTP Provider - Fetches system info from the running app
# -----------------------------------------------------------------------------

data "http" "system_info" {
  url = "http://${local.fqdn}:8080/api/system"

  # Don't fetch until the container is healthy
  depends_on = [time_sleep.wait_for_healthy]
}

# -----------------------------------------------------------------------------
# DemoApp Provider - Posts data to the display panel
# -----------------------------------------------------------------------------

provider "demoapp" {
  # FQDN is predictable because we control the dns_name_label (with random suffix)
  # Format: {dns_name_label}.{region}.azurecontainer.io
  endpoint = "http://${local.fqdn}:8080"
}

# Post the system info to the display panel
# This shows: "Terraform fetched this data and posted it here"
resource "demoapp_display" "system_snapshot" {
  depends_on = [time_sleep.wait_for_healthy]

  data = jsonencode({
    source           = "terraform"
    cloud            = "azure"
    region           = var.region
    fetched_from     = "/api/system"
    captured_at      = timestamp()
    system_info      = jsondecode(data.http.system_info.response_body)
  })

  # Ignore changes to data after initial creation.
  # Why: Terraform is the persistence layer for this stateless app. If the app
  # crashes and restarts, we want `terraform apply` to restore the SAME data,
  # not fetch new data that might have changed or become unavailable.
  # Remove this block if you want the display to update on every apply.
  lifecycle {
    ignore_changes = [data]
  }
}

# Create some example items to show the app is functional
resource "demoapp_item" "terraform" {
  depends_on = [time_sleep.wait_for_healthy]

  name        = "Provisioned by Terraform"
  description = "This item was created by terraform apply in Azure"
}

resource "demoapp_item" "azure" {
  depends_on = [time_sleep.wait_for_healthy]

  name        = "Azure Container Instance"
  description = "Running in ${var.region} region"
}
