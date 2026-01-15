# Demo App Examples — Development Log

> Session notes for blog posts and future reference.

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
