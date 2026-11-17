# Design Document

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         DevOps Deployment Pipeline                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐   │
│  │   GitHub    │────▶│   GitHub    │────▶│    GHCR     │────▶│   Nomad     │   │
│  │   Repo      │     │   Actions   │     │  Registry   │     │   Cluster   │   │
│  └─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘   │
│         │                   │                   │                    │          │
│         │                   │                   │                    │          │
│  ┌──────▼───────────────────▼───────────────────▼────────────────────▼────────┐ │
│  │                           Monitoring Stack                               │ │
│  │  ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────────────┐    │ │
│  │  │ Docker  │────▶│ Promtail│────▶│   Loki  │────▶│    Grafana      │    │ │
│  │  │  Logs   │     │         │     │         │     │   (Query)       │    │ │
│  │  └─────────┘     └─────────┘     └─────────┘     └─────────────────┘    │ │
│  └───────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Component Specifications

### 1. Repository Structure

```
devops-intern-final/
├── .github/
│   └── workflows/
│       └── ci.yml           # GitHub Actions CI pipeline
├── app/
│   ├── Dockerfile           # NGINX container image definition
│   ├── nginx.conf           # Custom NGINX configuration
│   └── index.html           # Served content with build SHA injection
├── scripts/
│   ├── sysinfo.sh           # Host environment information script
│   └── healthcheck.sh       # HTTP health verification script
├── nomad/
│   └── nginx-app.nomad.hcl  # Nomad job specification
├── monitoring/
│   ├── docker-compose.yaml  # Monitoring stack deployment
│   ├── loki-config.yaml     # Loki configuration
│   └── promtail-config.yaml # Promtail configuration
├── docs/
│   └── screenshots/         # Documentation screenshots
├── README.md                # Project documentation
└── .gitignore               # Git ignore rules
```

### 2. Shell Scripts Design

#### sysinfo.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

# Output sections:
# 1. User Information
# 2. Hostname & Kernel
# 3. System Date (ISO-8601)
# 4. Disk Usage
# 5. Memory Usage
# 6. Docker Daemon Status
```

**Functions:**
- `get_user_info()` - Effective username and UID
- `get_host_info()` - Hostname and kernel version
- `get_date_info()` - Current date in ISO-8601 format
- `get_disk_info()` - Human-readable disk usage (df -h)
- `get_memory_info()` - Memory usage (free or cat /proc/meminfo)
- `check_docker()` - Docker daemon availability and version

#### healthcheck.sh
```bash
#!/usr/bin/env bash
set -euo pipefail

# Accept URL as $1, default to http://localhost:8080
# Exit codes: 0 = healthy, 1 = unhealthy, 127 = curl not found
```

**Functions:**
- `check_curl()` - Verify curl availability
- `check_endpoint(url)` - HTTP GET with timeout, validate status 200

### 3. Container Design

#### Dockerfile (app/Dockerfile)
```dockerfile
FROM alpine:3.21.3

# Install NGINX with exact version
RUN apk add --no-cache nginx=1.26.3-r3

# Create nginx user
RUN addgroup -S nginx && adduser -S -G nginx nginx

# Copy custom nginx.conf
COPY nginx.conf /etc/nginx/nginx.conf

# Validate nginx config
RUN nginx -t

# Set working directory
WORKDIR /var/lib/nginx

# Copy and inject BUILD_SHA into index.html
ARG BUILD_SHA=local
COPY index.html /var/www/html/
RUN sed -i "s/{{BUILD_SHA}}/$(echo $BUILD_SHA | tr -cd '[:alnum:]._-')/" /var/www/html/index.html

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1

# Set ownership
RUN chown -R nginx:nginx /var/lib/nginx /var/www/html

# Switch to non-root user
USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
```

**Image Size Target:** < 60 MB

#### nginx.conf (app/nginx.conf)
```nginx
worker_processes auto;
error_log /dev/stderr info;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /dev/stdout;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 8080;
        server_name localhost;

        root /var/www/html;
        index index.html;

        location / {
            try_files $uri $uri/ =404;
        }

        location /healthz {
            access_log off;
            return 200 "ok";
            add_header Content-Type text/plain;
        }
    }
}
```

### 4. CI/CD Pipeline Design (.github/workflows/ci.yml)

**Stages:**

1. **Lint Stage**
   - ShellCheck on scripts/sysinfo.sh
   - ShellCheck on scripts/healthcheck.sh
   - Hadolint on app/Dockerfile

2. **Build Stage**
   - Docker build with BUILD_SHA=${{ github.sha }}
   - Image tagging: nginx-app:${{ github.sha }}

3. **Test Stage**
   - Container startup
   - HTTP tests on / and /healthz
   - Verify BUILD_SHA in response

4. **Publish Stage** (main branch only)
   - Login to GHCR
   - Push with SHA tag and latest tag

### 5. Nomad Job Specification (nomad/nginx-app.nomad.hcl)

```hcl
job "nginx-app" {
  datacenters = ["dc1"]

  variable "image_repository" {
    type = string
  }

  variable "image_tag" {
    type = string
    default = "latest"
  }

  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "2m"
    auto_revert = true
  }

  group "web" {
    count = 1

    restart {
      attempts = 3
      interval = "5m"
      delay = "15s"
      mode = "fail"
    }

    reschedule {
      attempts = 3
      interval = "1h"
      delay = "30s"
      max_delay = "5m"
      unlimited = false
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "${var.image_repository}:${var.image_tag}"
        ports = ["http"]
      }

      resources {
        cpu = 100
        memory = 64
      }

      service {
        name = "nginx-app"
        port = "http"

        check {
          name = "HTTP health"
          type = "http"
          path = "/healthz"
          interval = "10s"
          timeout = "2s"
        }
      }

      log_config {
        max_files = 3
        max_file_size = 5
      }
    }

    port "http" {
      to = 8080
    }
  }
}
```

### 6. Monitoring Stack Design

#### docker-compose.yaml
```yaml
version: "3.8"

services:
  loki:
    image: grafana/loki:3.0.0
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/config.yaml:ro
      - loki-data:/var/loki
    command: -config.file=/etc/loki/config.yaml

  promtail:
    image: grafana/promtail:3.0.0
    volumes:
      - ./promtail-config.yaml:/etc/promtail/config.yaml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - loki
    command: -config.file=/etc/promtail/config.yaml

  grafana:
    image: grafana/grafana:11.0.0
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      - loki
    environment:
      - GF_PATHS_PROVISIONING=/etc/grafana/provisioning

volumes:
  loki-data:
  promtail-positions:
  grafana-data:
```

#### loki-config.yaml
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kv_store:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_block_size: 262144
  chunk_retain_period: 1m

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /var/loki/boltdb-shipper-active
    cache_location: /var/loki/boltdb-shipper-cache
    cache_ttl: 24h
  filesystem:
    directory: /var/loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

#### promtail-config.yaml
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/promtail/positions.yaml

clients:
  - endpoint: http://loki:3100/loki/api/v1/push
    tenant_id: ""
    batchwait: 1s
    batchsize: 102400
    timeout: 10s

scrape_configs:
  - job_name: containers
    docker_sd_configs:
      - host: /var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        regex: '/(.*)'
        target_label: container
      - source_labels: [__meta_docker_container_label_com_docker_compose_project]
        target_label: job
      - source_labels: [__meta_docker_container_label_com_docker_compose_service]
        target_label: service
```

## Data Flow

### Build Pipeline
```
Git Push → GitHub Actions Trigger → Lint (ShellCheck, Hadolint) 
    → Build (Docker) → Test (Container Start, HTTP Checks) 
    → Publish (GHCR Push) → Nomad Deployment
```

### Logging Pipeline
```
Container Output → Docker Log Driver → Promtail (Docker Socket) 
    → Loki (Aggregation) → Grafana (Visualization)
```

## Implementation Sequence

1. **Source Control Setup**
   - Initialize repository with proper structure
   - Create .gitignore
   - Set up feature branch workflow

2. **Shell Scripts Development**
   - Implement sysinfo.sh with all functions
   - Implement healthcheck.sh
   - Verify ShellCheck compliance

3. **Containerization**
   - Create Dockerfile with all requirements
   - Create custom nginx.conf
   - Create index.html with BUILD_SHA injection
   - Test image build and run

4. **CI/CD Pipeline**
   - Create GitHub Actions workflow
   - Implement lint, build, test, publish stages
   - Configure GHCR authentication

5. **Nomad Configuration**
   - Complete nginx-app.nomad.hcl
   - Validate job specification
   - Test deployment (if Nomad available)

6. **Monitoring Stack**
   - Complete Loki configuration
   - Complete Promtail configuration
   - Create docker-compose.yaml
   - Test log aggregation

7. **Documentation**
   - Write comprehensive README.md
   - Add architecture diagrams
   - Document troubleshooting steps
   - Include known limitations