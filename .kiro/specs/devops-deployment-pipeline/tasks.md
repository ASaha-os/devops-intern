# Tasks

## Overview

This document lists all tasks required to implement the DevOps deployment pipeline for the containerized NGINX application. Tasks are organized sequentially from source control through deployment and monitoring, with clear dependencies and verification criteria for each.

## Implementation Plan

The implementation follows a logical sequence:

1. **Source Control Setup** - Establish repository structure, gitignore, and feature branch workflow
2. **Shell Scripts Development** - Create sysinfo.sh and healthcheck.sh with quality standards
3. **Containerization** - Build production-ready Docker image with NGINX configuration
4. **CI/CD Pipeline** - Implement GitHub Actions workflow for automated testing and publishing
5. **Nomad Orchestration** - Configure job specification with health checks and deployment strategy
6. **Monitoring Stack** - Set up Loki, Promtail, and Grafana for log aggregation
7. **Documentation** - Write comprehensive README with architecture, commands, and troubleshooting
8. **Release & Finalization** - Create PR, merge, and tag release v1.0.0

## Task Dependency Graph

```
Source Control Setup (1.x)
    │
    ├──▶ Shell Scripts Implementation (2.x)
    │         │
    │         ├──▶ Containerization (3.x)
    │         │         │
    │         │         ├──▶ CI/CD Pipeline (4.x)
    │         │         │
    │         │         └──▶ Monitoring Stack (6.x)
    │         │
    │         └──▶ Documentation (7.x)
    │
    └──▶ Nomad Orchestration (5.x) [Independent path]
              │
              └──▶ Release & Finalization (8.x)
                        │
                        └──▶ All previous tasks completed
```

## Tasks

### 1. Source Control Setup

**Task ID:** 1.1  
**Description:** Create .gitignore with proper exclusions for IDEs, environment files, and build artifacts  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 5 minutes  
**Sub-tasks:**  
- fs_write .gitignore file with .idea/, .vscode/, .env, build artifacts exclusions  
- Verify gitignore rules cover all required patterns  
**Verification:** Run git check-ignore to verify patterns are working  
**Dependencies:** []

**Task ID:** 1.2  
**Description:** Initialize git repository with feature branch workflow and create conventional commits  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Initialize git repository if not already initialized  
- Create initial commit with folder structure  
- Create feature branch for implementation work  
- Make commits with conventional prefixes (feat:, fix:, docs:, ci:)  
- Ensure at least 5 commits showing incremental development  
**Verification:** git log shows conventional commit messages and branch structure  
**Dependencies:** [1.1]

**Task ID:** 1.3  
**Description:** Create GitHub Actions CI workflow for lint, build, test, and publish stages  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 15 minutes  
**Sub-tasks:**  
- Create .github/workflows/ci.yml with lint job (ShellCheck, Hadolint)  
- Add build job with Docker build and BUILD_SHA argument  
- Add test job with container start and HTTP endpoint verification  
- Add publish job for main branch with GHCR authentication  
**Verification:** GitHub Actions runs successfully on push to main  
**Dependencies:** [1.2, 2.1, 2.2, 3.3]

### 2. Shell Scripts Implementation

**Task ID:** 2.1  
**Description:** Create sysinfo.sh with host environment reporting  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 15 minutes  
**Sub-tasks:**  
- fs_write shebang and set -euo pipefail directive  
- Implement user info (username, UID)  
- Implement hostname and kernel version  
- Implement date in ISO-8601 format  
- Implement disk usage (df -h)  
- Implement memory usage (free or /proc/meminfo)  
- Implement Docker daemon status check  
- Mark as executable in git index (git update-index --chmod=+x)  
**Verification:** Script runs successfully and outputs all sections; ShellCheck passes with no errors  
**Dependencies:** [1.1]

**Task ID:** 2.2  
**Description:** Create healthcheck.sh with HTTP endpoint verification  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- fs_write shebang and set -euo pipefail directive  
- Accept URL as $1, default to http://localhost:8080  
- Implement curl availability check (exit 127 if not found)  
- Implement HTTP GET with timeout and status code validation  
- Exit 0 on HTTP 200, exit 1 on non-200, print diagnostic  
- Mark as executable in git index (git update-index --chmod=+x)  
**Verification:** Script returns correct exit codes; ShellCheck passes with no errors  
**Dependencies:** [1.1]

### 3. Containerization

**Task ID:** 3.1  
**Description:** Update app/nginx.conf to serve on port 8080 with /healthz endpoint  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Configure server to listen on port 8080  
- Add location /healthz returning 200 with body "ok"  
- Configure access logs to stdout, error logs to stderr  
- Configure writable temp directories for non-root operation  
**Verification:** nginx -t validates configuration; container responds on port 8080  
**Dependencies:** [1.1]

**Task ID:** 3.2  
**Description:** Update app/index.html with build identifier injection support  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 5 minutes  
**Sub-tasks:**  
- Modify index.html to include placeholder for BUILD_SHA  
- Add your name and assessment date  
- Ensure BUILD_SHA can be injected via sed during build  
**Verification:** BUILD_SHA appears in served page after docker build --build-arg  
**Dependencies:** [1.1]

**Task ID:** 3.3  
**Description:** Create production Dockerfile with all security and configuration requirements  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 15 minutes  
**Sub-tasks:**  
- Base on alpine:3.21.3 with exact tag  
- Install nginx=1.26.3-r3 with exact version pin  
- Create nginx user and group  
- Copy custom nginx.conf  
- Validate with nginx -t  
- Accept BUILD_SHA argument with validation (alphanumeric, dot, underscore, hyphen)  
- Inject BUILD_SHA into index.html  
- Add HEALTHCHECK instruction (interval 30s, timeout 3s, start-period 5s, retries 3)  
- Set USER to nginx (non-root)  
- Ensure final image size under 60 MB  
**Verification:** docker build succeeds; image size < 60 MB; HEALTHCHECK works  
**Dependencies:** [3.1, 3.2]

**Task ID:** 3.4  
**Description:** Test Docker image build and run to verify all requirements  
**Status:** ready  
**Priority:** medium  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Build image with default BUILD_SHA  
- Build image with custom BUILD_SHA argument  
- Run container and verify / returns 200  
- Run container and verify /healthz returns 200  
- Verify BUILD_SHA appears in response  
- Verify non-root user (ps aux shows nginx user)  
- Verify image size is under 60 MB  
**Verification:** All endpoint tests pass; image meets size requirement  
**Dependencies:** [3.3]

### 4. CI/CD Pipeline

**Task ID:** 4.1  
**Description:** Implement GitHub Actions lint job with ShellCheck and Hadolint  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Add ShellCheck action for scripts/sysinfo.sh  
- Add ShellCheck action for scripts/healthcheck.sh  
- Add Hadolint action for app/Dockerfile  
- Configure job to fail on lint errors  
**Verification:** Lint job runs and passes on clean code  
**Dependencies:** [2.1, 2.2, 3.3]

**Task ID:** 4.2  
**Description:** Implement GitHub Actions build job with Docker  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Set up Docker buildx  
- Build image with BUILD_SHA=${{ github.sha }}  
- Tag image for testing  
**Verification:** Build job completes successfully  
**Dependencies:** [4.1]

**Task ID:** 4.3  
**Description:** Implement GitHub Actions test job with container and HTTP verification  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Start container from built image  
- Wait for container health  
- Verify / returns HTTP 200  
- Verify /healthz returns HTTP 200  
- Verify response contains build identifier  
- Clean up container after tests  
**Verification:** Test job passes all endpoint verifications  
**Dependencies:** [4.2]

**Task ID:** 4.4  
**Description:** Implement GitHub Actions publish job to GHCR  
**Status:** ready  
**Priority:** medium  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Add condition for push to main branch only  
- Login to GHCR with GITHUB_TOKEN  
- Tag image with SHA and latest  
- Push both tags to registry  
**Verification:** Images appear in GHCR with both tags  
**Dependencies:** [4.3]

### 5. Nomad Orchestration

**Task ID:** 5.1  
**Description:** Complete nomad/nginx-app.nomad.hcl with all required specifications  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 15 minutes  
**Sub-tasks:**  
- Set job name to "nginx-app"  
- Declare variables for image_repository and image_tag  
- Configure update strategy (max_parallel=1, min_healthy_time=10s, healthy_deadline=2m, auto_revert=true)  
- Configure restart policy (attempts=3, interval=5m, delay=15s, mode=fail)  
- Configure reschedule policy (attempts=3, interval=1h, delay=30s, max_delay=5m, unlimited=false)  
- Define service group "web" with count=1  
- Define task "nginx" with Docker driver  
- Allocate 100 MHz CPU, 64 MB memory  
- Configure task logs (max_files=3, max_file_size=5 MB)  
**Verification:** nomad job validate passes  
**Dependencies:** [1.1]

**Task ID:** 5.2  
**Description:** Configure Nomad networking and Consul service registration  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 5 minutes  
**Sub-tasks:**  
- Define dynamic port "http" forwarded to container port 8080  
- Register Consul service "nginx-app" on http port  
**Verification:** nomad job plan shows correct port mapping  
**Dependencies:** [5.1]

**Task ID:** 5.3  
**Description:** Configure Nomad health checking with Consul  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 5 minutes  
**Sub-tasks:**  
- Add Consul HTTP health check named "HTTP health"  
- Set check path to /healthz  
- Configure interval (10s) and timeout (2s)  
**Verification:** Health check defined in job spec  
**Dependencies:** [5.2]

### 6. Monitoring Stack

**Task ID:** 6.1  
**Description:** Create Loki configuration file with proper settings  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Configure http_listen_port: 3100  
- Set up ingester with inmemory ring  
- Configure boltdb-shipper storage with filesystem backend  
- Set schema to v11 starting from 2024-01-01  
**Verification:** Loki starts and responds on /ready endpoint  
**Dependencies:** [1.1]

**Task ID:** 6.2  
**Description:** Create Promtail configuration for Docker log collection  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Configure Docker service discovery  
- Mount /var/run/docker.sock read-only  
- Set Loki endpoint to http://loki:3100/loki/api/v1/push  
- Add relabel configs for job, container, service labels  
**Verification:** Promtail starts and forwards logs to Loki  
**Dependencies:** [6.1]

**Task ID:** 6.3  
**Description:** Create docker-compose.yaml for monitoring stack deployment  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Define loki service (grafana/loki:3.0.0, port 3100, volume mount, health check)  
- Define promtail service (grafana/promtail:3.0.0, depends_on loki, volume mounts)  
- Define grafana service (grafana/grafana:11.0.0, port 3000, depends_on loki, volume)  
- Define named volumes for loki-data, promtail-positions, grafana-data  
**Verification:** docker compose up starts all services successfully  
**Dependencies:** [6.1, 6.2]

**Task ID:** 6.4  
**Description:** Verify log aggregation is working end-to-end  
**Status:** ready  
**Priority:** medium  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Start monitoring stack  
- Start NGINX container  
- Generate some log entries via HTTP requests  
- Query Loki for NGINX logs  
- Configure Grafana with Loki data source  
**Verification:** Logs appear in Loki; Grafana can query successfully  
**Dependencies:** [6.3, 3.4]

### 7. Documentation

**Task ID:** 7.1  
**Description:** Update README.md with comprehensive project documentation  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 30 minutes  
**Sub-tasks:**  
- Add title, your name, submission date  
- Add CI status badge (GitHub Actions badge)  
- Add architecture overview with ASCII diagram  
- Add repository layout section  
- Add prerequisites with pinned versions  
- Add Quick Start section (under 10 commands)  
- Add section for each task with commands and expected output  
- Add Troubleshooting section with at least 3 failure scenarios  
- Add Known Limitations section  
- Use markdown formatting consistently  
**Verification:** README is complete, accurate, and reproducible  
**Dependencies:** [1.2, 2.1, 2.2, 3.4, 4.4, 5.3, 6.4]

**Task ID:** 7.2  
**Description:** Take documentation screenshots for visual reference  
**Status:** ready  
**Priority:** low  
**Estimated Time:** 15 minutes  
**Sub-tasks:**  
- Screenshot of repository structure  
- Screenshot of successful Docker build  
- Screenshot of container running and responding  
- Screenshot of GitHub Actions workflow status  
- Screenshot of monitoring stack running  
**Verification:** Screenshots saved in docs/screenshots/ and referenced in README  
**Dependencies:** [7.1]

### 8. Release and Finalization

**Task ID:** 8.1  
**Description:** Merge feature branch to main via pull request  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 5 minutes  
**Sub-tasks:**  
- Open pull request from feature branch to main  
- Add self-review with description  
- Merge PR to main branch  
**Verification:** Main branch contains merged changes  
**Dependencies:** [1.3, 2.1, 2.2, 3.3, 4.4, 5.3, 6.3, 7.1]

**Task ID:** 8.2  
**Description:** Create release tag v1.0.0  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 2 minutes  
**Sub-tasks:**  
- Tag current commit as v1.0.0  
- Push tag to origin  
**Verification:** git tag shows v1.0.0; GitHub releases show the tag  
**Dependencies:** [8.1]

**Task ID:** 8.3  
**Description:** Final verification and cleanup  
**Status:** ready  
**Priority:** high  
**Estimated Time:** 10 minutes  
**Sub-tasks:**  
- Verify all requirements are met (check requirements document)  
- Verify all scripts pass ShellCheck  
- Verify Docker image size under 60 MB  
- Verify all files are committed and pushed  
- Clean up any temporary files  
**Verification:** All requirements satisfied; project ready for submission  
**Dependencies:** [8.2]

## Notes

- All scripts must follow POSIX standards and pass ShellCheck validation
- Docker images must remain under 60 MB to meet the requirement
- CI pipeline must successfully run lint, build, test, and publish stages
- Nomad job specification must be validated with `nomad job validate`
- All documentation must be reproducible by following the README commands
- Screenshots should be added to docs/screenshots/ folder as PNG files