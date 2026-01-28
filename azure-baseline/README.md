# Azure Baseline Demo

A single `terraform apply` that demonstrates the demo-app ecosystem running in Azure:

1. **Azure Provider** — Creates Container Instance running demo-app
2. **HTTP Provider** — Fetches system info from the running app
3. **DemoApp Provider** — Posts that data to the display panel + creates items

## Prerequisites

- Azure CLI authenticated (`az login`)
- Terraform >= 1.0
- DemoApp provider installed from registry.terraform.io

## Usage

```bash
# Initialize providers
terraform init

# Run the demo (optionally override region)
terraform apply

# Or specify a different region
terraform apply -var="region=westus2"

# Open in browser (use the app_url from outputs)
# Example: http://demo-app-aci.eastus.azurecontainer.io:8080

# Clean up
terraform destroy
```

## What Happens

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Azure          │     │  HTTP           │     │  DemoApp        │
│  Provider       │────►│  Provider       │────►│  Provider       │
│                 │     │  (data source)  │     │                 │
│  Creates ACI    │     │  Fetches from   │     │  Posts to       │
│  container      │     │  /api/system    │     │  /api/display   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

1. Azure provider creates resource group and container instance
2. Container pulls `ghcr.io/billgrant/demo-app:latest` and starts
3. `time_sleep` waits for the container to be healthy
4. HTTP data source fetches `/api/system` (hostname, IPs, etc.)
5. DemoApp provider posts that info to `/api/display`
6. DemoApp provider creates example items

## Demo Flow

After `terraform apply`:

1. Use the `app_url` output to open the app in your browser
2. **System Info Panel** shows live system data (from the Azure container)
3. **Display Panel** shows the same data captured at apply time (proving Terraform fetched it)
4. **Items Panel** shows "Provisioned by Terraform" items

The display panel demonstrates: "Terraform can fetch data from this app and post it back."

## Design Decision: Ignore Changes on Display

The `demoapp_display` resource uses `lifecycle { ignore_changes = [data] }` by default.

**Why:** Terraform is the persistence layer for this stateless app. If the app crashes mid-demo:
1. Run `terraform apply` again
2. The *same* data is restored from Terraform state

Without `ignore_changes`, Terraform would fetch *new* data on each apply — which might have changed or become unavailable (breaking your demo).

**To opt out:** Remove the `lifecycle` block in `main.tf` if you want the display to update with fresh data on every apply.

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | `eastus` | Azure region to deploy resources |
| `resource_group_name` | `demo-app-rg` | Name of the Azure resource group |
| `container_name` | `demo-app-aci` | Name of the container instance |
| `dns_suffix` | `001` | Suffix for DNS name label (override if deploying multiple instances) |

**Note:** The DNS name label must be globally unique within the Azure region. If you deploy multiple instances or encounter a name collision, override the `dns_suffix`:

```bash
terraform apply -var="dns_suffix=myuniqueid"
```

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group` | Name of the Azure resource group |
| `container_fqdn` | Fully qualified domain name of the container |
| `app_url` | URL to access the app |
| `system_info` | System info captured at initial apply (from display panel) |
| `items_created` | IDs of created items |

## Cost Note

Azure Container Instances are billed per second while running. Remember to `terraform destroy` when done with your demo to avoid ongoing charges.
