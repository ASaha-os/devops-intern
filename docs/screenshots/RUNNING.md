# Running the Full Deployment

## Prerequisites

- Docker Engine 24.0.7+
- Nomad 1.7.7+ with Consul 1.17.3+
- HashiCorp CLI tools (`nomad`, `consul`)
- GitHub Personal Access Token with `write:packages` scope

## 1. Run the Monitoring Stack (Loki + Promtail + Grafana)

```bash
# Start the monitoring stack
docker compose -f d:\devops-intern\monitoring\docker-compose.yaml up -d

# Wait for services to start (30-60 seconds)
docker compose -f d:\devops-intern\monitoring\docker-compose.yaml ps
```

**Services:**
- Loki: http://localhost:3100
- Grafana: http://localhost:3000 (admin/admin)
- Promtail: logs Docker containers

## 2. Configure Grafana Data Source

1. Open http://localhost:3000
2. Login with `admin/admin`
3. Go to **Configuration → Data Sources → Add data source**
4. Select **Loki**
5. URL: `http://loki:3100`
6. Click **Save & Test**

## 3. Deploy the Nomad Job with SHA-Tagged Image

### Step 1: Build and Push Image to GHCR

```bash
# Navigate to project directory
cd d:\devops-intern\app

# Build with commit SHA
docker build --build-arg BUILD_SHA=$(git rev-parse --short HEAD) -t nginx-app:$(git rev-parse --short HEAD) .

# Tag for GitHub Container Registry
docker tag nginx-app:$(git rev-parse --short HEAD) ghcr.io/asaha-os/devops-intern:$(git rev-parse --short HEAD)
docker tag nginx-app:$(git rev-parse --short HEAD) ghcr.io/asaha-os/devops-intern:latest

# Login to GHCR
docker login ghcr.io -u asaha-os -p <YOUR_GITHUB_TOKEN>

# Push images
docker push ghcr.io/asaha-os/devops-intern:$(git rev-parse --short HEAD)
docker push ghcr.io/asaha-os/devops-intern:latest
```

### Step 2: Validate and Run Nomad Job

```bash
# Navigate to project directory
cd d:\devops-intern\nomad

# Get the current SHA
$SHA = git rev-parse --short HEAD
echo "Using SHA: $SHA"

# Validate job specification
nomad job validate -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=$SHA' nginx-app.nomad.hcl

# Plan deployment (dry run)
nomad job plan -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=$SHA' nginx-app.nomad.hcl

# Run the deployment
nomad job run -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=$SHA' nginx-app.nomad.hcl

# Check job status
nomad job status nginx-app
```

**Expected Output:**
```
Job "nginx-app" submitted successfully
==> Monitoring evaluation "abc12345"
    Evaluation triggered by job "nginx-app"
    Allocation "def67890" created: node "node-1", group "web"
    Allocation "def67890" status: "running" → "healthy"
    Evaluation status changed: "pending" → "complete"
==> Evaluation "abc12345" finished with status "complete"
```

## 4. Verify Deployment

### Check Container Health

```bash
# List allocations
nomad job allocations nginx-app

# Check allocation status
nomad alloc status <ALLOC_ID>

# View logs
nomad alloc logs <ALLOC_ID> nginx

# Check Consul service
consul services list
```

### Query Logs via Loki API

```bash
# Query all logs from the container
curl -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="docker", container="nginx-app"}'

# Query for specific patterns (404 errors)
curl -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="docker", container="nginx-app"} |= "404"'

# Query for access logs
curl -G "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="docker", container="nginx-app"} |= "GET"'
```

### Test Endpoints

```bash
# Get the Nomad port mapping
nomad job status nginx-app | grep -A5 "Network"

# Test via Nomad node IP
curl http://<NOMAD_NODE_IP>:<MAPPED_PORT>/
curl http://<NOMAD_NODE_IP>:<MAPPED_PORT>/healthz
```

## 5. Grafana Loki Query Examples

In Grafana **Explore** tab, use these LogQL queries:

### All NGINX Logs
```
{job="docker", container="nginx-app"}
```

### Access Logs with GET Requests
```
{job="docker", container="nginx-app"} |= "GET"
```

### Requests with 4xx Status
```
{job="docker", container="nginx-app"} |= " 4"
```

### Error Logs
```
{job="docker", container="nginx-app"} |= "error"
```

## 6. Cleanup

```bash
# Stop Nomad job
nomad job stop nginx-app

# Stop monitoring stack
docker compose -f d:\devops-intern\monitoring\docker-compose.yaml down

# Remove containers
docker rm -f nginx-app
```