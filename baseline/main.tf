terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
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
      source = "billgrant/demoapp"
    }
  }
}

# -----------------------------------------------------------------------------
# Docker Provider - Creates and runs the demo-app container
# -----------------------------------------------------------------------------

provider "docker" {}

# Pull the demo-app image (assumes it's built locally or available)
# For local dev: docker build -t demo-app:latest ~/code/demo-app
resource "docker_image" "demo_app" {
  name         = "demo-app:latest"
  keep_locally = true
}

# Run the container
resource "docker_container" "demo_app" {
  name  = "demo-app-example"
  image = docker_image.demo_app.image_id

  ports {
    internal = 8080
    external = 8080
  }

  # Health check to know when the app is ready
  healthcheck {
    test     = ["CMD", "/demo-app", "healthcheck"]
    interval = "2s"
    timeout  = "2s"
    retries  = 10
    start_period = "5s"
  }

  # Wait for container to be running before marking as created
  wait = true
}

# -----------------------------------------------------------------------------
# Wait for Health - Ensures the app is responding before proceeding
# -----------------------------------------------------------------------------

# Give the container a moment to fully start and pass health checks
resource "time_sleep" "wait_for_healthy" {
  depends_on = [docker_container.demo_app]

  create_duration = "5s"
}

# -----------------------------------------------------------------------------
# HTTP Provider - Fetches system info from the running app
# -----------------------------------------------------------------------------

data "http" "system_info" {
  url = "http://localhost:8080/api/system"

  # Don't fetch until the container is healthy
  depends_on = [time_sleep.wait_for_healthy]
}

# -----------------------------------------------------------------------------
# DemoApp Provider - Posts data to the display panel
# -----------------------------------------------------------------------------

provider "demoapp" {
  endpoint = "http://localhost:8080"
}

# Post the system info to the display panel
# This shows: "Terraform fetched this data and posted it here"
resource "demoapp_display" "system_snapshot" {
  depends_on = [time_sleep.wait_for_healthy]

  data = jsonencode({
    source           = "terraform"
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
  description = "This item was created by terraform apply"
}

resource "demoapp_item" "demo" {
  depends_on = [time_sleep.wait_for_healthy]

  name        = "Demo Infrastructure"
  description = "Part of the baseline demo example"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "container_id" {
  description = "The Docker container ID"
  value       = docker_container.demo_app.id
}

output "app_url" {
  description = "URL to access the demo app"
  value       = "http://localhost:8080"
}

output "system_info" {
  description = "System info fetched from the app"
  value       = jsondecode(data.http.system_info.response_body)
}

output "items_created" {
  description = "IDs of the items created"
  value = {
    terraform = demoapp_item.terraform.id
    demo      = demoapp_item.demo.id
  }
}
