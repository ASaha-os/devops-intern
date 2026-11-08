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
cd devops-intern-final
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:local
bash scripts/healthcheck.sh http://localhost:8080/
curl --fail http://localhost:8080/healthz
docker rm --force nginx-app
```

The site displays `akash saha`, the submission date, and the build identifier supplied through `BUILD_SHA`.

## 1. Source control

The intended repository is `devops-intern-final`. Commit incremental changes with conventional prefixes such as `feat:`, `fix:`, `docs:`, and `ci:`; use a `feature/*` branch and merge it to `main` through a reviewed pull request. Tag the completed release `v1.0.0`. This working directory has no Git metadata, so its branch, commit history, pull request, and tag cannot be created or verified here.

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
nomad job validate -var='image_repository=ghcr.io/<OWNER>/devops-intern-final' -var='image_tag=<SHA>' nomad/nginx-app.nomad.hcl
nomad job plan -var='image_repository=ghcr.io/<OWNER>/devops-intern-final' -var='image_tag=<SHA>' nomad/nginx-app.nomad.hcl
nomad job run -var='image_repository=ghcr.io/<OWNER>/devops-intern-final' -var='image_tag=<SHA>' nomad/nginx-app.nomad.hcl
nomad job status nginx-app
```

Replace `<OWNER>` and `<SHA>` with the GHCR namespace and a published commit SHA. Ensure Nomad has Consul connectivity and the client can pull the GHCR package. An allocation is healthy when the job status reports it running and its Consul HTTP check is passing. Nomad was not available in this working environment, so no successful plan or allocation output is claimed.

## 6. Log aggregation

The Compose stack pins Loki, Promtail, and Grafana versions and mounts committed Loki and Promtail configurations. Promtail discovers Docker containers and applies `job`, `container`, and Compose `service` labels.

```sh
docker compose -f monitoring/docker-compose.yaml up -d
docker build --build-arg BUILD_SHA=local -t nginx-app:local app/
docker run --rm --detach --name nginx-app -p 8080:8080 nginx-app:local
curl http://localhost:8080/not-found
```

In Grafana at `http://localhost:3000`, add Loki as a data source with URL `http://loki:3100`. In Explore, use `{job="docker", container="nginx-app"} |= "404"` to find the deliberately requested missing path in the NGINX access log. Query `{job="docker", container="nginx-app"}` to inspect all discovered logs. Verify Loki readiness with `curl http://localhost:3100/ready`. Stop the local stack with `docker compose -f monitoring/docker-compose.yaml down`.

This environment did not run Docker Compose or Grafana; query results and screenshots therefore remain to be captured during a live run. The Docker socket mount grants Promtail access to the host Docker API and is suitable only for a trusted local demonstration; production should use a restricted log-collection design.

## Troubleshooting

- If `healthcheck.sh` reports a connection failure, check that the container is running and that port 8080 is published to the host.
- If Nomad cannot pull the image, verify the GHCR image name and tag and grant the Nomad client credentials/read access to the package.
- If Loki has no streams, check `docker compose ... ps`, Promtail logs, Docker socket access, and the exact labels shown by `{job="docker"}`.

These are diagnostic steps for the common failure points; no failures are represented as having been observed in this working directory.

## Known limitations

- The working copy is not a Git repository, so branch history, pull request review, release tagging, and a live CI run could not be completed.
- The image size, Nomad validation/deployment output, Loki query results, and Grafana screenshot require the corresponding runtimes and have not been fabricated.
- The demo uses an HTTP endpoint and a Docker socket-mounted Promtail collector; production would add TLS, managed secrets, restricted log access, durable/replicated Loki storage, and resource/security hardening.
- `scripts/*.sh` use Bash strict mode; `pipefail` is not POSIX shell syntax.
