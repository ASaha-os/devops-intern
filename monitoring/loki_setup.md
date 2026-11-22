# Loki and Promtail Setup

This document describes how Loki and Promtail were configured for Docker log aggregation.

## Loki Configuration

Loki is configured in `loki-config.yaml` with the following key settings:

- **Port:** 3100 (HTTP API)
- **Schema:** v11 with boltdb-shipper for index storage
- **Storage:** Filesystem backend for chunks and index
- **Replication:** Single replica (inmemory ring)

The configuration uses a simplified schema suitable for single-node development and testing. Production deployments should use distributed storage (S3, GCS) and multi-node replication.

### Key Configuration Sections

```yaml
server:
  http_listen_port: 3100

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
```

## Promtail Configuration

Promtail is configured in `promtail-config.yaml` to discover and scrape Docker container logs:

- **Discovery:** Docker service discovery via Unix socket
- **Target:** Sends logs to Loki at `http://loki:3100/loki/api/v1/push`
- **Labels:** Extracts container name, compose service, and job labels

### Docker Socket Access

Promtail requires read-only access to the Docker socket (`/var/run/docker.sock`) to discover running containers. This is mounted as a volume in the docker-compose.yaml:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

**Security Note:** Mounting the Docker socket grants full container visibility. In production, use a restricted log collector or sidecar pattern.

### Label Extraction

Promtail applies relabeling to add metadata:

```yaml
relabel_configs:
  - source_labels: [__meta_docker_container_name]
    regex: /(.+)
    target_label: container
  - source_labels: [__meta_docker_container_label_com_docker_compose_service]
    regex: (.+)
    target_label: service
```

## Deployment

The monitoring stack is deployed with Docker Compose:

```sh
docker compose -f monitoring/docker-compose.yaml up -d
```

This starts:
- Loki on port 3100
- Promtail (no exposed ports, internal)
- Grafana on port 3000

## Verification

Check Loki readiness:
```sh
curl http://localhost:3100/ready
```

Query logs via Loki API:
```sh
curl -G -s "http://localhost:3100/loki/api/v1/query" --data-urlencode 'query={job="docker"}'
```

## Grafana Integration

1. Open Grafana at `http://localhost:3000`
2. Add Loki data source with URL `http://loki:3100`
3. Use Explore to query logs with LogQL: `{job="docker", container="nginx-app"}`

## Production Considerations

- Replace filesystem storage with S3, GCS, or Azure Blob
- Use authentication (auth_enabled: true)
- Enable TLS for Loki API
- Run Loki in distributed mode with read/write/backend components
- Use a dedicated log shipper with authentication instead of Docker socket access
- Configure retention policies and compaction
- Add alerting rules for log patterns