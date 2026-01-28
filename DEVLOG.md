# Demo App Examples — Development Log

> Session notes for blog posts and future reference.

---

## 2026-01-28 — Session 2: Azure Baseline Demo

**Development Environment Note:** This session used GitHub Copilot CLI (not Claude CLI) with Claude Sonnet 4.5 model. This is a learning experiment with Copilot — normal phase work uses Claude CLI with Opus 4.5.

### What We Built
- `azure-baseline/` demo using Azure Container Instances
- Same flow as baseline demo, but deployed to Azure cloud
- Structured with separate `variables.tf`, `outputs.tf`, `main.tf` files
- Single `terraform apply` provisions cloud infrastructure AND populates data

### Demo Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Azure          │     │  HTTP           │     │  DemoApp        │
│  Provider       │────►│  Provider       │────►│  Provider       │
│                 │     │  (data source)  │     │                 │
│  Creates ACI    │     │  Fetches from   │     │  Posts to       │
│  container      │     │  /api/system    │     │  /api/display   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Providers Used

| Provider | Source | Purpose |
|----------|--------|---------|
| azurerm | hashicorp/azurerm | Create resource group and container instance |
| http | hashicorp/http | Fetch data from running app |
| time | hashicorp/time | Wait for container health |
| demoapp | billgrant/demoapp | Post to display, create items |

### The Provider Configuration Challenge

**Problem:** Terraform providers are configured before any resources exist. The demoapp provider needs an endpoint URL, but ACI's FQDN (`demo-app-aci-001.eastus.azurecontainer.io`) doesn't exist until after the container is created.

**Why baseline works:** Docker uses `localhost:8080` — a known, static value we can hardcode.

**Why Azure is different:** FQDN is only known after resource creation.

**Solution:** Make the DNS predictable using variables:
- Azure ACI DNS format: `{dns_name_label}.{region}.azurecontainer.io`
- We control both `dns_name_label` (via `dns_suffix` variable) and `region`
- Construct the full FQDN using locals before any resources are created

```hcl
variable "dns_suffix" {
  default = "001"
}

locals {
  dns_name = "${var.container_name}-${var.dns_suffix}"
  fqdn     = "${local.dns_name}.${var.region}.azurecontainer.io"
}

provider "demoapp" {
  endpoint = "http://${local.fqdn}:8080"
}
```

**Limitation (to fix later):** Multiple deployments with default `dns_suffix="001"` will conflict. The DNS name must be globally unique within the Azure region. Users must override the suffix when deploying multiple instances.

### Issues Encountered & Resolved

#### 1. Container Crash Loop
**Symptom:** Provider reported success but no data persisted. Container restarting every ~30 seconds.

**Root cause:** Liveness probe checking `/api/health` (404) instead of `/health` (200).

**Fix:** Updated liveness probe path in main.tf:
```hcl
liveness_probe {
  http_get {
    path   = "/health"  # was /api/health
    port   = 8080
    scheme = "http"
  }
}
```

**Learning:** This wasn't a provider bug. The provider likely wrote data successfully, but the container crashed and restarted with a fresh in-memory database, losing all data. Once the crash loop was fixed, everything worked.

#### 2. Insufficient Wait Time
**Symptom:** Provider timeouts during apply: "Client.Timeout exceeded while awaiting headers"

**Root cause:** ACI container takes longer to be fully ready than local Docker. The 15-second wait wasn't enough.

**Fix:** Increased `time_sleep.wait_for_healthy` to 60 seconds.

#### 3. Output Drift on Every Plan
**Symptom:** `terraform plan` always showed changes to `system_info` output (changing client IP).

**Root cause:** Output referenced `data.http.system_info` which re-fetches on every plan, but `demoapp_display` resource has `ignore_changes = [data]`.

**Fix:** Changed output to reference the display resource instead:
```hcl
output "system_info" {
  description = "System info captured at initial apply (from display panel)"
  value       = jsondecode(demoapp_display.system_snapshot.data)
}
```

Now outputs are stable and plans are clean.

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `eastus` | Azure region to deploy resources |
| `resource_group_name` | `demo-app-rg` | Name of the Azure resource group |
| `container_name` | `demo-app-aci` | Name of the container instance |
| `dns_suffix` | `001` | Suffix for DNS name label (override for multiple deployments) |

### Files Created
- `azure-baseline/main.tf` — infrastructure and provider configuration
- `azure-baseline/variables.tf` — input variables
- `azure-baseline/outputs.tf` — outputs
- `azure-baseline/README.md` — usage and design decisions
- `azure-baseline/.gitignore` — protect state files

### Known Issues / Future Work

**DNS Collision:** Multiple deployments using default `dns_suffix="001"` will conflict because ACI DNS labels must be globally unique within a region. 

**Potential solutions:**
1. Document that users must override `dns_suffix` for multiple deployments
2. Use random provider to generate suffix (attempted but doesn't work due to provider configuration timing)
3. Enhance demoapp provider to support dynamic endpoint configuration (would require provider changes)

For now, documented limitation is acceptable. This is for demos, not production multi-tenancy.

---

## 2026-01-15 — Session 1: Baseline Demo

### What We Built
- Initial repository structure
- Baseline demo using Docker + HTTP + DemoApp providers
- Single `terraform apply` provisions container AND populates data

### Demo Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Docker         │     │  HTTP           │     │  DemoApp        │
│  Provider       │────►│  Provider       │────►│  Provider       │
│                 │     │  (data source)  │     │                 │
│  Creates        │     │  Fetches from   │     │  Posts to       │
│  container      │     │  /api/system    │     │  /api/display   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Providers Used

| Provider | Source | Purpose |
|----------|--------|---------|
| docker | kreuzwerker/docker | Run demo-app container |
| http | hashicorp/http | Fetch data from running app |
| time | hashicorp/time | Wait for container health |
| demoapp | billgrant/demoapp | Post to display, create items |

### Key Design Decision: Lifecycle Ignore Changes

```hcl
resource "demoapp_display" "system_snapshot" {
  data = jsonencode({ ... })

  lifecycle {
    ignore_changes = [data]
  }
}
```

**Why:** Terraform is the persistence layer for this stateless app. If the app crashes:
1. Data in the display panel is lost
2. Run `terraform apply`
3. The *same* data is restored from Terraform state

Without `ignore_changes`, Terraform would fetch *new* data on each apply — which might have changed or become unavailable (breaking the demo).

**Default is opt-out** — remove the `lifecycle` block if you want dynamic updates.

### Terraform Init Quirk

The `demoapp` provider isn't published to the registry yet. With dev overrides:
- `terraform init` will error trying to find the provider
- But `terraform apply` works because the dev override is in effect
- Use `terraform providers lock` for the other providers first

### Files Created
- `baseline/main.tf` — full demo configuration
- `baseline/README.md` — usage and design decisions
- `README.md` — repo overview and future examples
- `.gitignore` — Terraform state files

### Future Improvements
- Once container images are published to ghcr.io, update to pull from registry
- Goal: `git clone` → `terraform init` → `terraform apply` with no prerequisites

---
