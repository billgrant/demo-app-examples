# Demo App Examples

A library of Terraform configurations demonstrating [demo-app](https://github.com/billgrant/demo-app) in various scenarios.

## Purpose

Demo-app is a universal demo application for infrastructure demonstrations. This repo provides ready-to-use examples showing how to deploy and interact with demo-app using Terraform.

Each example is self-contained and runs with a single `terraform apply`.

## Examples

| Example | Description | Providers Used |
|---------|-------------|----------------|
| [baseline](./baseline/) | Local Docker deployment with data flow demo | Docker, HTTP, DemoApp |
| [azure-baseline](./azure-baseline/) | Azure Container Instances deployment | Azure, HTTP, DemoApp |

### Coming Soon

- **vault** — Inject secrets from HashiCorp Vault into the display panel
- **observability** — Ship logs to Grafana/Loki stack
- **ci-cd** — GitHub Actions pipeline posting build status
- **mcp** — AI agent (Claude) managing app state

## Prerequisites

**All examples require:**
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0

**Additional requirements by example:**
- **baseline**: [Docker](https://docs.docker.com/get-docker/)
- **azure-baseline**: [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (authenticated with `az login`)

The [DemoApp provider](https://registry.terraform.io/providers/billgrant/demoapp/latest) is installed automatically by `terraform init`, and the container image is pulled from `ghcr.io/billgrant/demo-app` during `terraform apply`.

## Quick Start

```bash
# Clone this repo
git clone https://github.com/billgrant/demo-app-examples.git
cd demo-app-examples

# Run the baseline demo
cd baseline
terraform init
terraform apply

# Open the app
open http://localhost:8080

# Clean up
terraform destroy
```

## Related Repos

- [demo-app](https://github.com/billgrant/demo-app) — The application
- [terraform-provider-demoapp](https://github.com/billgrant/terraform-provider-demoapp) — Terraform provider

## License

MIT
