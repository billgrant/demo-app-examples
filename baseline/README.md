# Baseline Demo

A single `terraform apply` that demonstrates the demo-app ecosystem:

1. **Docker Provider** — Runs the demo-app container
2. **HTTP Provider** — Fetches system info from the running app
3. **DemoApp Provider** — Posts that data to the display panel + creates items

## Prerequisites

- Docker running locally
- Demo-app container image built:
  ```bash
  cd ~/code/demo-app
  docker build -t demo-app:latest .
  ```
- Terraform >= 1.0
- DemoApp provider dev override configured (see main repo README)

## Usage

```bash
# Initialize providers
terraform init

# Run the demo
terraform apply

# Open in browser
open http://localhost:8080

# Clean up
terraform destroy
```

## What Happens

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Docker         │     │  HTTP           │     │  DemoApp        │
│  Provider       │────►│  Provider       │────►│  Provider       │
│                 │     │  (data source)  │     │                 │
│  Creates        │     │  Fetches from   │     │  Posts to       │
│  container      │     │  /api/system    │     │  /api/display   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

1. Docker provider pulls the image and starts the container
2. `time_sleep` waits for the container to be healthy
3. HTTP data source fetches `/api/system` (hostname, IPs, etc.)
4. DemoApp provider posts that info to `/api/display`
5. DemoApp provider creates example items

## Demo Flow

After `terraform apply`:

1. Open http://localhost:8080
2. **System Info Panel** shows live system data (from the container)
3. **Display Panel** shows the same data captured at apply time (proving Terraform fetched it)
4. **Items Panel** shows "Provisioned by Terraform" items

The display panel demonstrates: "Terraform can fetch data from this app and post it back."

## Design Decision: Ignore Changes on Display

The `demoapp_display` resource uses `lifecycle { ignore_changes = [data] }` by default.

**Why:** Terraform is the persistence layer for this stateless app. If the app crashes mid-demo:
1. Restart the container
2. Run `terraform apply`
3. The *same* data is restored from Terraform state

Without `ignore_changes`, Terraform would fetch *new* data on each apply — which might have changed or become unavailable (breaking your demo).

**To opt out:** Remove the `lifecycle` block if you want the display to update with fresh data on every apply.

## Outputs

| Output | Description |
|--------|-------------|
| `container_id` | Docker container ID |
| `app_url` | URL to access the app |
| `system_info` | System info fetched during apply |
| `items_created` | IDs of created items |
