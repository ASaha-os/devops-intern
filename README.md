# DevOps Intern Final Assessment


| Field | Value |
|---|---|
| Name | akash saha |
| Submission date | 2026-11-08 |
| Project | DevOps Intern Final |

This repository builds and tests a small static NGINX site, publishes the image to GitHub Container Registry (GHCR) from `main`, deploys it as a Nomad service, and collects container logs with Grafana Loki.

## Architecture

```text
Source → GitHub Actions (lint/build/test) → GHCR → Nomad + Consul
                                                     ↓
                                                Docker logs → Promtail → Loki → Grafana
```

## Repository layout

```text
app/                 NGINX image, site, and server configuration
scripts/             System information and HTTP health-check scripts
.github/workflows/   CI and GHCR publishing
nomad/               Nomad service job
monitoring/          Loki, Promtail, and Compose configuration
```

## Prerequisites

- Docker Engine 24.0.7 with Compose v2
- Nomad 1.7.7 and Consul 1.17.3 for deployment
- ShellCheck 0.9.0
- `curl` for health checks and Loki queries
- A GHCR package readable by the Nomad client

## Quick Start

```sh
git clone https://github.com/ASaha-os/devops-intern.git
cd devops-intern
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:local
bash scripts/healthcheck.sh http://localhost:8080/
curl --fail http://localhost:8080/healthz
docker rm --force nginx-app
```

The site displays `akash saha`, the submission date, and the build identifier supplied through `BUILD_SHA`.

## 1. Source control

The repository is `devops-intern` on GitHub. All commits follow conventional commit prefixes (`feat:`, `fix:`, `docs:`, `ci:`). Development uses `feature/*` branches merged to `main` through pull requests. The final release is tagged `v1.0.0`.

The `.gitignore` excludes `.idea/`, `.vscode/`, local environment files, and common build artifacts.

## 2. Linux scripting

Both scripts use strict Bash mode (`set -euo pipefail`). `sysinfo.sh` reports the effective user and UID, host and kernel, ISO-8601 date, disk and memory usage, and Docker daemon availability. `healthcheck.sh` accepts a target URL (default `http://localhost:8080`), checks it with `curl`, and succeeds only for HTTP 200.

```sh
bash scripts/sysinfo.sh
bash scripts/healthcheck.sh http://localhost:8080/healthz
```

On a Linux host the system report includes lines for `User`, `Effective UID`, `Hostname`, `Kernel`, `Date`, `Disk usage`, `Memory usage`, and `Docker daemon`. A successful endpoint check prints `healthcheck: http://localhost:8080/healthz returned HTTP 200`. The exact system values depend on the host.

After adding these scripts to a Git repository, stage them and set executable bits in the index with `git add scripts/sysinfo.sh scripts/healthcheck.sh` followed by `git update-index --chmod=+x scripts/sysinfo.sh scripts/healthcheck.sh`. CI runs ShellCheck on both scripts.

## 3. Containerization

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

## 4. Continuous integration

`.github/workflows/ci.yml` runs for pushes and pull requests targeting `main`. The lint job runs ShellCheck and Hadolint; build builds with the commit SHA; test starts the container and checks both HTTP endpoints; publish runs only for pushes to `main` and pushes SHA and `latest` tags to GHCR using the job-scoped `GITHUB_TOKEN` package permission.

The workflow badge at the top points to the repository Actions page. A successful run can be confirmed in the Actions tab after this project is pushed to GitHub.

## 5. Nomad deployment

`nomad/nginx-app.nomad.hcl` defines one Docker task in a service group, with dynamic named port `http`, 100 MHz CPU, 64 MB memory, a Consul `/healthz` HTTP check, rolling update settings, restart policy, and bounded rescheduling.

```sh
nomad job validate -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=abc1234' nomad/nginx-app.nomad.hcl
nomad job plan -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=abc1234' nomad/nginx-app.nomad.hcl
nomad job run -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=abc1234' nomad/nginx-app.nomad.hcl
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

## 6. Log aggregation

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

## Known limitations

- The demo uses an HTTP endpoint and a Docker socket-mounted Promtail collector; production would add TLS, managed secrets, restricted log access, durable/replicated Loki storage, and resource/security hardening.
- Nomad deployment requires a running Nomad/Consul cluster with Docker driver and GHCR access. Screenshots show example output from a test environment.
- The monitoring stack uses single-node Loki with filesystem storage, suitable only for development. Production requires distributed Loki with object storage (S3/GCS).
- `scripts/*.sh` use Bash strict mode; `pipefail` is not POSIX shell syntax but is widely supported.
- Image size may vary slightly depending on Alpine package updates. The target is < 60 MB.

## Screenshots

All screenshots are available in `docs/screenshots/`:
- `ci-workflow.png` - GitHub Actions successful CI run
- `docker-build.png` - Docker build output with image size
- `nomad-deployment.png` - Nomad job deployment with SHA-tagged image
- `grafana-loki-query.png` - Grafana Explore with LogQL query results
- `loki-logs.png` - Container log visualization in Grafana
