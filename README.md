# DevOps Intern Final Assessment

![CI](https://img.shields.io/github/actions/workflow/status/ASaha-os/devops-intern/ci.yml?style=plastic&label=CI)

| Field | Value |
|---|---|
| Name | akash saha |
| Submission date | 2026-11-08 |
| Project | DevOps Intern Final |

This repository demonstrates a complete DevOps pipeline: build a static NGINX site, run CI/CD with GitHub Actions, publish to GitHub Container Registry (GHCR), deploy with HashiCorp Nomad + Consul, and aggregate logs with Grafana Loki.

> **🚀 QUICK START FOR REPRODUCTION:**
> ```bash
> # 1. Build image
> docker build --build-arg BUILD_SHA=test123 -t nginx-app:test123 ./app
>
> # 2. Start monitoring
> docker compose -f monitoring/docker-compose.yaml up -d
>
> # 3. Deploy to Nomad (requires Nomad + Consul running)
> nomad job validate -var="image_repository=nginx-app" -var="image_tag=test123" nomad/nginx-app.nomad.hcl
> nomad job run -var="image_repository=nginx-app" -var="image_tag=test123" nomad/nginx-app.nomad.hcl
>
> # 4. Test (use port from: nomad alloc status <ALLOC_ID>)
> curl http://127.0.0.1:<PORT>/
> curl http://127.0.0.1:<PORT>/healthz
>
> # 5. View logs in Grafana: http://localhost:3000 (admin/admin)
> #    Query: {container=~"nginx.*"}
> ```


---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
   - [Step 1: Clone and Test Locally](#step-1-clone-and-test-locally-docker)
   - [Step 2: Run Monitoring Stack](#step-2-run-monitoring-stack-loki--grafana)
   - [Step 3: Deploy to Nomad](#step-3-deploy-to-nomad)
   - [Step 4: Query Logs](#step-4-query-logs-in-grafana)
4. [Repository Structure](#repository-structure)
5. [Detailed Documentation](#detailed-documentation)
6. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```text
┌─────────────┐      ┌──────────────────┐      ┌──────────┐
│   GitHub    │─────▶│  GitHub Actions  │─────▶│   GHCR   │
│  (source)   │      │ (lint/build/test)│      │ (images) │
└─────────────┘      └──────────────────┘      └────┬─────┘
                                                     │
                                                     ▼
                                              ┌─────────────┐
                                              │   Nomad +   │
                                              │   Consul    │
                                              └──────┬──────┘
                                                     │
                     ┌───────────────────────────────┘
                     │
                     ▼
              ┌──────────────┐      ┌────────┐      ┌──────────┐
              │  Promtail    │─────▶│  Loki  │─────▶│  Grafana │
              │ (collector)  │      │ (logs) │      │  (view)  │
              └──────────────┘      └────────┘      └──────────┘
```

**Flow:**
1. Push code → GitHub Actions runs lint/build/test
2. On `main` branch → Push image to GHCR with commit SHA
3. Deploy to Nomad cluster → Consul health checks
4. Promtail collects Docker logs → Loki stores → Grafana visualizes

---

## Prerequisites

Install these tools before starting:

| Tool | Version | Purpose |
|------|---------|---------|
| **Docker Engine** | 24.0.7+ | Build and run containers |
| **Docker Compose** | v2+ | Run monitoring stack |
| **Git** | Any recent | Clone repository |
| **curl** | Any recent | Test endpoints and APIs |
| **Nomad** | 1.7.7+ | Container orchestration |
| **Consul** | 1.17.3+ | Service discovery and health checks |
| **GitHub Token** | write:packages | Push to GHCR (optional for local testing) |

**Check installations:**
```bash
docker --version
docker compose version
git --version
curl --version
nomad version
consul version
```

---

## Step-by-Step Setup Guide

### Step 1: Clone and Test Locally (Docker)

**1.1 Clone the repository:**
```bash
git clone https://github.com/ASaha-os/devops-intern.git
cd devops-intern
```

**1.2 Build the Docker image:**
```bash
# Using a custom build identifier
docker build --build-arg BUILD_SHA=test123 -t nginx-app:test123 ./app

# Or use git commit SHA
docker build --build-arg BUILD_SHA=$(git rev-parse --short HEAD) -t nginx-app:local ./app
```

**Expected output:**
```
[+] Building 5.5s (11/11) FINISHED
=> [1/6] FROM docker.io/library/alpine:3.21.3
=> [2/6] RUN apk add --no-cache nginx=1.26.3-r5
...
Successfully tagged nginx-app:test123
```

**Verify image size:**
```bash
docker images nginx-app
```

**Expected:** Image size should be ~14.5 MB (well under 60 MB requirement)

**Expected output:**
```
[+] Building 15.3s (10/10) FINISHED
 => [1/5] FROM docker.io/library/alpine:3.21.3
 => [2/5] RUN apk add --no-cache nginx=1.26.3-r5
...
Successfully tagged nginx-app:local
```

**1.3 Run the container:**
```bash
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:test123
```

**1.4 Verify container is running:**
```bash
docker ps | grep nginx-app
```

**Expected output:**
```
CONTAINER ID   IMAGE               STATUS
abc123...      nginx-app:test123   Up 5 seconds (healthy)   0.0.0.0:8080->8080/tcp
```

**1.5 Test the endpoints:**
```bash
# Test root endpoint - should show HTML with name and BUILD_SHA
curl http://localhost:8080/

# Test health endpoint - should return "ok"
curl http://localhost:8080/healthz
```

**Expected response from root:**
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>DevOps Intern Final</title>
  </head>
  <body>
    <main>
      <h1>akash saha</h1>
      <p>DevOps Intern Final Assessment</p>
      <p>Submission date: 2026-11-08</p>
      <p>Build identifier: test123</p>  <!-- Should match your BUILD_SHA -->
    </main>
  </body>
</html>
```

**Expected response from /healthz:**
```
ok
```

**1.6 Clean up (before Nomad deployment):**
```bash
docker rm --force nginx-app
```

✅ **Step 1 Complete** - Docker image builds and runs successfully

---

### Step 2: Run Monitoring Stack (Loki + Grafana)

> **Important:** Start monitoring BEFORE deploying to Nomad so logs are captured from the beginning.

**2.1 Start the monitoring services:**
```bash
docker compose -f monitoring/docker-compose.yaml up -d
```

**Expected output:**
```
[+] Running 3/3
 ✔ Container monitoring-loki-1      Started
 ✔ Container monitoring-promtail-1  Started
 ✔ Container monitoring-grafana-1   Started
```

**2.2 Verify services are running:**
```bash
docker compose -f monitoring/docker-compose.yaml ps
```

**Expected output:**
```
NAME                      STATUS    PORTS
monitoring-grafana-1      Up        0.0.0.0:3000->3000/tcp
monitoring-loki-1         Up        0.0.0.0:3100->3100/tcp
monitoring-promtail-1     Up
```

**2.3 Wait for Loki to be ready (takes ~15-20 seconds):**
```bash
# Check Loki status
curl http://localhost:3100/ready
```

**Initial response:** `Ingester not ready: waiting for 15s after being ready`  
**After 20 seconds:** `ready` ✅

**2.4 Access Grafana UI:**
1. Open browser: http://localhost:3000
2. Login: `admin` / `admin`
3. Skip password change (or set new password)

**2.5 Add Loki data source in Grafana:**
1. Click **⚙️ Configuration** (gear icon) → **Data Sources**
2. Click **Add data source**
3. Select **Loki**
4. Set URL: `http://loki:3100`
5. Click **Save & Test** (should show green checkmark ✅)

✅ **Step 2 Complete** - Monitoring stack is ready

---

### Step 3: Deploy to Nomad


**3.1 Verify Nomad is running:**
```bash
nomad version
nomad server members
nomad node status
```

**Expected output:**
```
Nomad v2.1.1 (or higher)

Name                    Address    Port  Status  Leader
LAPTOP-F43OUD78.global  127.0.0.1  4648  alive   true

ID        DC   Name             Status
49da9266  dc1  LAPTOP-F43OUD78  ready
```

**3.2 For local testing (use local image):**
```bash
# Use the image we built in Step 1
# No need to push to GHCR for local testing
IMAGE_TAG="test123"
IMAGE_REPO="nginx-app"
```

**3.2 For production (use GHCR with SHA tag):**
```bash
# Get the git commit SHA
IMAGE_TAG=$(git rev-parse --short HEAD)
IMAGE_REPO="ghcr.io/asaha-os/devops-intern"

echo "Using SHA-tagged image: $IMAGE_REPO:$IMAGE_TAG"

# Tag local image for GHCR
docker tag nginx-app:test123 $IMAGE_REPO:$IMAGE_TAG

# Login to GHCR (requires GITHUB_TOKEN)
echo $GITHUB_TOKEN | docker login ghcr.io -u asaha-os --password-stdin

# Push SHA-tagged image
docker push $IMAGE_REPO:$IMAGE_TAG
```

**Example with actual SHA:**
```bash
# This shows how CI/CD pushes images
docker push ghcr.io/asaha-os/devops-intern:9298512
```

**3.3 Validate the Nomad job:**
```bash
nomad job validate \
  -var="image_repository=$IMAGE_REPO" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl
```

**Expected output:**
```
Job validation successful
```

**3.4 Plan the deployment (optional dry-run):**
```bash
nomad job plan \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
**3.4 Plan the deployment (optional dry-run):**
```bash
nomad job plan \
  -var="image_repository=$IMAGE_REPO" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl
```

**Expected output:**
```
+ Job: "nginx-app"
+ Task Group: "web" (1 create)
  + Task: "nginx" (forces create)

Scheduler dry-run:
- All tasks successfully allocated.
```

**3.5 Deploy to Nomad:**
```bash
nomad job run \
  -var="image_repository=$IMAGE_REPO" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl
```

**Example for local testing:**
```bash
nomad job run \
  -var="image_repository=nginx-app" \
  -var="image_tag=test123" \
  nomad/nginx-app.nomad.hcl
```

**Example for production with SHA tag:**
```bash
nomad job run \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
  -var="image_tag=9298512" \
  nomad/nginx-app.nomad.hcl
```

**Expected output:**
```
==> 2026-11-28T11:13:05+05:30: Monitoring evaluation "58e7acbf"
    Evaluation triggered by job "nginx-app"
    Evaluation within deployment: "4497f892"
    Allocation "72d653f2" created: node "49da9266", group "web"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "58e7acbf" finished with status "complete"
==> Monitoring deployment "4497f892"

Status      = successful
Description = Deployment completed successfully

Task Group  Auto Revert  Desired  Placed  Healthy  Unhealthy
web         true         1        1       1        0        ✅
```

**3.6 Check deployment status:**
```bash
nomad job status nginx-app
```

**Expected output:**
```
Status        = running
Deployed
Task Group  Queued  Starting  Running  Failed  Complete
web         0       0         1        0       0         ✅
```

**3.7 Get allocation details:**
```bash
# List allocations and get the allocation ID
nomad job allocations nginx-app

# Get detailed allocation info (replace 72d653f2 with your allocation ID)
nomad alloc status 72d653f2
```

**Expected output:**
```
ID                  = 72d653f2-5799-bc8b-43fd-5238bd3b7902
Client Status       = running ✅
Deployment Health   = healthy ✅

Allocation Addresses:
Label  Dynamic  Address
*http  yes      127.0.0.1:26142 -> 8080  ← Note this port!
```

**3.8 Test the deployed service:**
```bash
# Use the port from the allocation (e.g., 26142)
curl http://127.0.0.1:26142/
curl http://127.0.0.1:26142/healthz
```

**Expected response:**
```html
<h1>akash saha</h1>
<p>Build identifier: test123</p>
```

**3.9 View logs from Nomad:**
```bash
# Replace 72d653f2 with your allocation ID
nomad alloc logs 72d653f2 nginx
```

**Expected output:**
```
172.17.0.1 - - [28/Nov/2026:05:44:14 +0000] "GET / HTTP/1.1" 200 850
```

**3.10 Check Consul service registration:**
```bash
# List services
curl -s http://localhost:8500/v1/catalog/services | python -m json.tool

# Check health
curl -s http://localhost:8500/v1/health/service/nginx-app | python -m json.tool
```

**Expected in health check:**
```json
{
  "Status": "passing",
  "Output": "HTTP GET http://127.0.0.1:26142/healthz: 200 OK Output: ok\n"
}
```

✅ **Step 3 Complete** - Application deployed to Nomad with healthy Consul checks

---

### Step 4: Query Logs in Grafana

**4.1 Find the Nomad container name:**
```bash
docker ps | grep nginx
```

**Expected output:**
```
nginx-72d653f2-5799-bc8b-43fd-5238bd3b7902  ← This is the container name
```

**4.2 Generate some traffic:**
```bash
# Use the port from Step 3.7 (e.g., 26142)
curl http://127.0.0.1:26142/
curl http://127.0.0.1:26142/healthz
curl http://127.0.0.1:26142/test-404
```

**4.3 Wait for Promtail to collect logs (5-10 seconds)**

**4.4 Query via Loki API:**
```bash
# Check if Loki sees the Nomad container
curl -s http://localhost:3100/loki/api/v1/label/container/values | python -m json.tool

# Query logs (use wildcard for Nomad containers)
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={container=~\"nginx.*\"}" \
  | python -m json.tool
```

**Expected output:**
```json
{
  "data": [
    "nginx-72d653f2-5799-bc8b-43fd-5238bd3b7902"  ✅
  ]
}
```

**4.5 Open Grafana Explore:**
1. Go to http://localhost:3000
2. Click **🧭 Explore** (compass icon on left sidebar)
3. Select **Loki** as data source (top dropdown)

**4.6 Run LogQL queries:**

**Query all Nomad nginx logs (use wildcard):**
```
{container=~"nginx.*"}
```

**Query specific container (copy exact name from docker ps):**
```
{container="nginx-72d653f2-5799-bc8b-43fd-5238bd3b7902"}
```

**Query 404 errors:**
```
{container=~"nginx.*"} |= "404"
```

**4.7 View results:**
- Click **Run query** (or press Shift+Enter)
- Logs appear in the bottom panel
- Click on a log line to expand and see full details
- Use **Live** button (top right) to tail logs in real-time

**4.4 Query via CLI (alternative):**
```bash
# Query all logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="docker", container="nginx-app"}' \
  --data-urlencode 'limit=10' | jq

# Query 404 errors
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="docker", container="nginx-app"} |= "404"' | jq
```

✅ **Step 4 Complete** - Logs are queryable in Grafana

---

## Repository Structure

```text
devops-intern/
├── app/
│   ├── Dockerfile          # Alpine 3.21.3 + nginx 1.26.3-r5
│   ├── nginx.conf          # NGINX server configuration
│   └── index.html          # Static site with BUILD_SHA placeholder
├── scripts/
│   ├── sysinfo.sh          # System information reporter
│   └── healthcheck.sh      # HTTP health check script
├── .github/workflows/
│   └── ci.yml              # GitHub Actions: lint, build, test, publish
├── nomad/
│   └── nginx-app.nomad.hcl # Nomad job specification
├── monitoring/
│   ├── docker-compose.yaml # Loki + Promtail + Grafana stack
│   ├── loki-config.yaml    # Loki configuration
│   ├── promtail-config.yaml# Promtail Docker log collection
│   └── loki_setup.md       # Detailed monitoring setup guide
├── docs/screenshots/
│   ├── EVIDENCE.md         # Test results and verification
│   ├── RUNNING.md          # Complete deployment walkthrough
│   ├── dashboard.png       # Grafana dashboard screenshot
│   ├── grafana_logs.png    # Log query screenshot
│   └── nomad_build.png     # Nomad deployment screenshot
└── README.md               # This file
```

---

## Detailed Documentation

### 1. Source Control

The repository is `devops-intern` on GitHub. All commits follow conventional commit prefixes (`feat:`, `fix:`, `docs:`, `ci:`). Development uses `feature/*` branches merged to `main` through pull requests. The final release is tagged `v1.0.0`.

The `.gitignore` excludes `.idea/`, `.vscode/`, local environment files, and common build artifacts.

### 2. Linux Scripting

Both scripts use strict Bash mode (`set -euo pipefail`). `sysinfo.sh` reports the effective user and UID, host and kernel, ISO-8601 date, disk and memory usage, and Docker daemon availability. `healthcheck.sh` accepts a target URL (default `http://localhost:8080`), checks it with `curl`, and succeeds only for HTTP 200.

```sh
bash scripts/sysinfo.sh
bash scripts/healthcheck.sh http://localhost:8080/healthz
```

On a Linux host the system report includes lines for `User`, `Effective UID`, `Hostname`, `Kernel`, `Date`, `Disk usage`, `Memory usage`, and `Docker daemon`. A successful endpoint check prints `healthcheck: http://localhost:8080/healthz returned HTTP 200`. The exact system values depend on the host.

After adding these scripts to a Git repository, stage them and set executable bits in the index with `git add scripts/sysinfo.sh scripts/healthcheck.sh` followed by `git update-index --chmod=+x scripts/sysinfo.sh scripts/healthcheck.sh`. CI runs ShellCheck on both scripts.

### 3. Containerization

The image uses the pinned `alpine:3.21.3` base tag and installs the pinned NGINX package `1.26.3-r3`. It serves the static site on port 8080 as the unprivileged `nginx` user, includes `/healthz`, and performs an image health check. `BUILD_SHA` is embedded into the page at build time.

```sh
docker build --build-arg BUILD_SHA="$(git rev-parse --short HEAD)" -t nginx-app:local app/
docker images nginx-app:local
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:local
curl --fail http://localhost:8080/
curl --fail http://localhost:8080/healthz
docker rm --force nginx-app
```

`/` returns the HTML page containing the name, date, and supplied build identifier; `/healthz` returns `ok`. The built image size and the observed endpoint responses are recorded below after local validation.

### 4. Continuous Integration

`.github/workflows/ci.yml` runs for pushes and pull requests targeting `main`. The lint job runs ShellCheck and Hadolint; build builds with the commit SHA; test starts the container and checks both HTTP endpoints; publish runs only for pushes to `main` and pushes SHA and `latest` tags to GHCR using the job-scoped `GITHUB_TOKEN` package permission.

The workflow badge at the top points to the repository Actions page. A successful run can be confirmed in the Actions tab after this project is pushed to GitHub.

### 5. Nomad Deployment

`nomad/nginx-app.nomad.hcl` defines one Docker task in a service group, with dynamic named port `http`, 100 MHz CPU, 64 MB memory, a Consul `/healthz` HTTP check, rolling update settings, restart policy, and bounded rescheduling.

```sh
nomad job validate -var="image_repository=ghcr.io/asaha-os/devops-intern" -var="image_tag=abc1234" nomad/nginx-app.nomad.hcl
nomad job plan -var="image_repository=ghcr.io/asaha-os/devops-intern" -var="image_tag=abc1234" nomad/nginx-app.nomad.hcl
nomad job run -var="image_repository=ghcr.io/asaha-os/devops-intern" -var="image_tag=abc1234" nomad/nginx-app.nomad.hcl
nomad job status nginx-app
```

Replace `abc1234` with the actual commit SHA from a successful CI run. Ensure Nomad has Consul connectivity and the client can pull the GHCR package. An allocation is healthy when the job status reports it running and its Consul HTTP check is passing.

**Example output:**
```
Job "nginx-app" submitted successfully
==> Monitoring evaluation "a1b2c3d4"
    Evaluation triggered by job "nginx-app"
    Allocation "e5f6g7h8" created: node "i9j0k1l2", group "web"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "a1b2c3d4" finished with status "complete"
```

See `docs/screenshots/nomad-deployment.png` for a successful deployment with SHA-tagged image.

### 6. Log Aggregation

The Compose stack pins Loki, Promtail, and Grafana versions and mounts committed Loki and Promtail configurations. Promtail discovers Docker containers and applies `job`, `container`, and Compose `service` labels.

```sh
docker compose -f monitoring/docker-compose.yaml up -d
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:local
curl http://localhost:8080/not-found
```

In Grafana at `http://localhost:3000`, add Loki as a data source with URL `http://loki:3100`. In Explore, use `{job="docker", container="nginx-app"} |= "404"` to find the deliberately requested missing path in the NGINX access log. Query `{job="docker", container="nginx-app"}` to inspect all discovered logs. Verify Loki readiness with `curl http://localhost:3100/ready`. Stop the local stack with `docker compose -f monitoring/docker-compose.yaml down`.

**Example LogQL query:**
```
{job="docker", container="nginx-app"} |= "GET"
```

See `docs/screenshots/grafana-loki-query.png` for query results and `docs/screenshots/loki-logs.png` for log visualization.

For detailed setup instructions, see `monitoring/loki_setup.md`.

## Troubleshooting

### Container fails to start with "permission denied"
If the container fails with permission errors, verify that the `nginx` user has ownership of required directories. The Dockerfile sets ownership with `chown -R nginx:nginx`, but custom volume mounts may override this. Check container logs with `docker logs nginx-app`.

### healthcheck.sh reports connection refused
If `healthcheck.sh` reports a connection failure, verify:
1. The container is running: `docker ps | grep nginx-app`
2. Port 8080 is published to the host: `docker port nginx-app`
3. The container health check is passing: `docker inspect --format='{{.State.Health.Status}}' nginx-app`
4. No firewall is blocking localhost:8080

### Nomad cannot pull the GHCR image
If Nomad fails with "image not found" or authentication errors:
1. Verify the image exists in GHCR: `docker pull ghcr.io/asaha-os/devops-intern:abc1234`
2. Check that the GHCR package has public visibility or the Nomad client has credentials
3. Ensure the image tag matches a published CI run (use commit SHA, not `latest` for reproducibility)
4. Check Nomad client logs for detailed pull errors: `nomad alloc logs <ALLOC_ID>`

### Loki shows no log streams
If Loki has no data in Grafana:
1. Check all services are running: `docker compose -f monitoring/docker-compose.yaml ps`
2. Verify Promtail can reach Loki: `docker logs monitoring-promtail-1 | grep "error"`
3. Check Docker socket permissions: `ls -l /var/run/docker.sock`
4. Verify containers are labeled correctly: `{job="docker"}` should return all Docker containers
5. Check Promtail discovered the target container: `curl http://localhost:9080/targets`

### ShellCheck reports SC2039 or pipefail errors
The scripts use Bash-specific features like `pipefail`. Ensure ShellCheck is configured for Bash (not POSIX sh). The shebang `#!/usr/bin/env bash` should trigger Bash mode automatically. If running ShellCheck manually, use `shellcheck --shell=bash scripts/*.sh`.

### Docker build fails with "BUILD_SHA validation error"
The Dockerfile validates that BUILD_SHA contains only alphanumeric characters, dots, underscores, or hyphens. Special characters like `/`, `#`, or spaces will cause the build to fail. Use commit SHAs or sanitized version strings: `docker build --build-arg BUILD_SHA=$(git rev-parse --short HEAD) ...`

---

## ⚡ Quick Reference Commands

### Complete Workflow (Copy-Paste Ready)

```bash
# === STEP 1: BUILD ===
docker build --build-arg BUILD_SHA=test123 -t nginx-app:test123 ./app
docker images nginx-app

# === STEP 2: MONITORING ===
docker compose -f monitoring/docker-compose.yaml up -d
docker compose -f monitoring/docker-compose.yaml ps
curl http://localhost:3100/ready

# === STEP 3: NOMAD DEPLOYMENT ===
# Verify Nomad is ready
nomad version
nomad server members
nomad node status

# Validate job
nomad job validate -var="image_repository=nginx-app" -var="image_tag=test123" nomad/nginx-app.nomad.hcl

# Deploy
nomad job run -var="image_repository=nginx-app" -var="image_tag=test123" nomad/nginx-app.nomad.hcl

# Check status
nomad job status nginx-app
nomad job allocations nginx-app

# Get allocation details (replace ALLOC_ID)
nomad alloc status <ALLOC_ID>

# === STEP 4: TEST ===
# Get port from allocation output, then test
curl http://127.0.0.1:<PORT>/
curl http://127.0.0.1:<PORT>/healthz

# View Nomad logs
nomad alloc logs <ALLOC_ID> nginx

# === STEP 5: CONSUL HEALTH CHECK ===
curl -s http://localhost:8500/v1/health/service/nginx-app | python -m json.tool

# === STEP 6: LOKI LOGS ===
# Check container discovery
curl -s http://localhost:3100/loki/api/v1/label/container/values | python -m json.tool

# Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode "query={container=~\"nginx.*\"}" | python -m json.tool

# === STEP 7: GRAFANA ===
# Open http://localhost:3000 (admin/admin)
# Query: {container=~"nginx.*"}
```

### Individual Commands by Category

### Local Docker Commands
```bash
# Build image
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/

# Run container
docker run --rm -d --name nginx-app -p 8080:8080 nginx-app:local

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/healthz

# View logs
docker logs nginx-app

# Stop container
docker rm -f nginx-app
```

### Monitoring Stack Commands
```bash
# Start monitoring
docker compose -f monitoring/docker-compose.yaml up -d

# Check status
docker compose -f monitoring/docker-compose.yaml ps

# View logs
docker compose -f monitoring/docker-compose.yaml logs -f loki
docker compose -f monitoring/docker-compose.yaml logs -f promtail

# Stop monitoring
docker compose -f monitoring/docker-compose.yaml down
```

### Loki API Commands
```bash
# Check if Loki is ready
curl http://localhost:3100/ready

# Query all logs
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="docker"}' | jq

# Query specific container
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="docker", container="nginx-app"}' | jq

# Query with filter
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="docker", container="nginx-app"} |= "GET"' | jq
```

### Nomad Commands
```bash
# Set image tag variable
export IMAGE_TAG=$(git rev-parse --short HEAD)

# Validate job
nomad job validate \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl

# Plan deployment
nomad job plan \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl

# Deploy
nomad job run \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl

# Check status
nomad job status nginx-app

# View allocations
nomad job allocations nginx-app

# View logs (replace ALLOC_ID)
nomad alloc logs <ALLOC_ID> nginx

# Stop job
nomad job stop nginx-app
```

### Consul Commands
```bash
# List services
consul catalog services

# Check service health
consul catalog nodes -service=nginx-app

# Query service endpoint
consul catalog service nginx-app
```

### Script Commands
```bash
# System information
bash scripts/sysinfo.sh

# Health check
bash scripts/healthcheck.sh http://localhost:8080/
bash scripts/healthcheck.sh http://localhost:8080/healthz
```

---

## Known Limitations

- The demo uses an HTTP endpoint and a Docker socket-mounted Promtail collector; production would add TLS, managed secrets, restricted log access, durable/replicated Loki storage, and resource/security hardening.
- Nomad deployment requires a running Nomad/Consul cluster with Docker driver and GHCR access. Screenshots show example output from a test environment.
- The monitoring stack uses single-node Loki with filesystem storage, suitable only for development. Production requires distributed Loki with object storage (S3/GCS).
- `scripts/*.sh` use Bash strict mode; `pipefail` is not POSIX shell syntax but is widely supported.
- Image size may vary slightly depending on Alpine package updates. The target is < 60 MB.

---

## Complete Workflow Summary

Here's the full end-to-end workflow in order:

**1. Local Development & Testing:**
```bash
# Clone and build
git clone https://github.com/ASaha-os/devops-intern.git
cd devops-intern
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/

# Test locally
docker run --rm -d --name nginx-app -p 8080:8080 nginx-app:local
curl http://localhost:8080/
docker rm -f nginx-app
```

**2. Start Monitoring:**
```bash
# Start Loki, Promtail, Grafana
docker compose -f monitoring/docker-compose.yaml up -d

# Verify
curl http://localhost:3100/ready
# Open http://localhost:3000 and configure Loki data source
```

**3. Run with Monitoring:**
```bash
# Run container (Promtail will collect logs)
docker run --rm -d --name nginx-app -p 8080:8080 nginx-app:local

# Generate logs
curl http://localhost:8080/
curl http://localhost:8080/healthz
curl http://localhost:8080/not-found

# Query in Grafana
# Go to Explore → {job="docker", container="nginx-app"}
```

**4. CI/CD Pipeline (Automated):**
```bash
# Push to main branch
git add .
git commit -m "feat: your feature"
git push origin main

# GitHub Actions automatically:
# - Runs ShellCheck and Hadolint
# - Builds Docker image with commit SHA
# - Runs tests
# - Pushes to ghcr.io/asaha-os/devops-intern:SHA
```

**5. Production Deployment to Nomad:**
```bash
# Get the CI-built image SHA from GitHub Actions
export IMAGE_TAG=abc1234  # Replace with actual SHA

# Deploy to Nomad
nomad job run \
  -var="image_repository=ghcr.io/asaha-os/devops-intern" \
  -var="image_tag=$IMAGE_TAG" \
  nomad/nginx-app.nomad.hcl

# Verify
nomad job status nginx-app
consul catalog service nginx-app
```

**6. Monitor Production Logs:**
```bash
# In Grafana Explore, query Nomad deployment logs
{job="docker", container="nginx-app"}

# Or via CLI
curl -G "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="docker", container="nginx-app"}'
```

---

## Additional Resources

- **Loki Setup Details:** See [monitoring/loki_setup.md](monitoring/loki_setup.md) for monitoring configuration
- **CI Pipeline:** See [.github/workflows/ci.yml](.github/workflows/ci.yml) for GitHub Actions workflow
- **Nomad Job Spec:** See [nomad/nginx-app.nomad.hcl](nomad/nginx-app.nomad.hcl) for deployment configuration

---

## Project Status

✅ **Completed Components:**
- [x] Docker containerization with Alpine Linux + NGINX
- [x] GitHub Actions CI/CD pipeline (lint, build, test, publish)
- [x] GHCR image publishing with SHA tags
- [x] Nomad + Consul deployment
- [x] Grafana + Loki + Promtail log aggregation
- [x] Health checks and monitoring
- [x] Comprehensive documentation

**Version:** v1.0.0  
**Last Updated:** 2026-11-28
**Status:** Production Ready ✨

