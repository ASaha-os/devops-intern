# Requirements Document

## Introduction

This document specifies the requirements for a comprehensive DevOps intern assessment project that demonstrates proficiency in source control, Linux scripting, containerization, CI/CD pipelines, container orchestration with HashiCorp Nomad, and log aggregation with Grafana Loki. The system delivers an end-to-end deployment pipeline for a containerized NGINX web application with monitoring capabilities.

## Glossary

- **Repository**: The Git version control repository hosted on GitHub containing all project source code and configuration
- **Commit**: A Git commit representing an atomic change to the repository with a descriptive message
- **Pull_Request**: A GitHub pull request proposing changes from a feature branch to be merged into the main branch
- **Release_Tag**: A Git tag marking a specific commit as a versioned release
- **Sysinfo_Script**: The shell script (sysinfo.sh) that reports system environment information
- **Healthcheck_Script**: The shell script (healthcheck.sh) that verifies application HTTP endpoints
- **NGINX_Image**: The Docker container image containing the NGINX web server and custom configuration
- **Base_Image**: The Alpine Linux Docker image used as the foundation for the NGINX_Image
- **Dockerfile**: The file containing instructions to build the NGINX_Image
- **Build_Argument**: A Docker build-time variable (BUILD_SHA) passed during image construction
- **Health_Endpoint**: The HTTP endpoint (/healthz) used to verify application health
- **Nomad_Job**: The HashiCorp Nomad job specification defining the deployment configuration
- **Consul**: The HashiCorp service discovery and health checking system integrated with Nomad
- **Loki**: The Grafana Loki log aggregation system for collecting and querying container logs
- **Promtail**: The log collection agent that sends Docker container logs to Loki
- **CI_Pipeline**: The GitHub Actions continuous integration workflow that builds, tests, and publishes the NGINX_Image
- **GHCR**: GitHub Container Registry where container images are published
- **ShellCheck**: The static analysis tool for shell scripts
- **Hadolint**: The static analysis tool for Dockerfiles
- **README**: The documentation file providing project overview, instructions, and troubleshooting guidance

## Requirements

### Requirement 1: Source Control Repository Structure

**User Story:** As a DevOps intern, I want to maintain a well-organized Git repository, so that the project history and structure demonstrate version control best practices.

#### Acceptance Criteria

1. THE Repository SHALL be named "devops-intern-final"
2. THE Repository SHALL contain directories for app/, scripts/, nomad/, monitoring/, and .github/workflows/
3. THE Repository SHALL include a .gitignore file excluding .idea/, .vscode/, .env, and build artifacts
4. THE Repository SHALL be publicly accessible on GitHub

### Requirement 2: Conventional Commit History

**User Story:** As a project reviewer, I want to see incremental commit history with conventional prefixes, so that I can understand the evolution of changes and their categories.

#### Acceptance Criteria

1. WHEN a feature is added, THE Repository SHALL contain commits with the "feat:" prefix
2. WHEN a bug is fixed, THE Repository SHALL contain commits with the "fix:" prefix
3. WHEN documentation is updated, THE Repository SHALL contain commits with the "docs:" prefix
4. WHEN CI configuration is modified, THE Repository SHALL contain commits with the "ci:" prefix
5. THE Repository SHALL contain at least 5 commits demonstrating incremental development

### Requirement 3: Feature Branch Workflow

**User Story:** As a DevOps engineer, I want to use feature branches with pull requests, so that changes are reviewed before merging to the main branch.

#### Acceptance Criteria

1. THE Repository SHALL contain at least one branch with the naming pattern "feature/*"
2. THE Repository SHALL contain at least one Pull_Request from a feature branch to the main branch
3. THE Pull_Request SHALL show evidence of review (comments or approval) before merging
4. WHEN the Pull_Request is merged, THE main branch SHALL contain the integrated changes

### Requirement 4: Release Tagging

**User Story:** As a release manager, I want to tag the final release, so that the completed version can be identified and referenced.

#### Acceptance Criteria

1. THE Repository SHALL contain a Release_Tag with the exact name "v1.0.0"
2. THE Release_Tag SHALL point to the commit representing the completed project state

### Requirement 5: System Information Script

**User Story:** As a system administrator, I want to collect host environment information, so that I can verify system configuration and Docker availability.

#### Acceptance Criteria

1. THE Sysinfo_Script SHALL output the effective username
2. THE Sysinfo_Script SHALL output the effective user ID
3. THE Sysinfo_Script SHALL output the hostname
4. THE Sysinfo_Script SHALL output the kernel version
5. THE Sysinfo_Script SHALL output the current date in ISO-8601 format
6. THE Sysinfo_Script SHALL output disk usage information
7. THE Sysinfo_Script SHALL output memory usage information
8. THE Sysinfo_Script SHALL report Docker daemon availability status

### Requirement 6: Health Check Script

**User Story:** As a DevOps engineer, I want to verify application health via HTTP, so that I can confirm the application is responding correctly.

#### Acceptance Criteria

1. THE Healthcheck_Script SHALL accept a target URL as a command-line argument
2. WHEN no argument is provided, THE Healthcheck_Script SHALL default to "http://localhost:8080"
3. WHEN the target endpoint returns HTTP 200, THE Healthcheck_Script SHALL exit with status 0 and print a success message
4. WHEN the target endpoint returns a non-200 status, THE Healthcheck_Script SHALL exit with status 1 and print an error message
5. WHEN curl is not available, THE Healthcheck_Script SHALL exit with status 127 and print an error message

### Requirement 7: Shell Script Quality Standards

**User Story:** As a code reviewer, I want shell scripts to follow best practices, so that they are reliable and maintainable.

#### Acceptance Criteria

1. THE Sysinfo_Script SHALL begin with the shebang "#!/usr/bin/env bash"
2. THE Healthcheck_Script SHALL begin with the shebang "#!/usr/bin/env bash"
3. THE Sysinfo_Script SHALL include "set -euo pipefail" for strict error handling
4. THE Healthcheck_Script SHALL include "set -euo pipefail" for strict error handling
5. THE Sysinfo_Script SHALL be marked as executable in the Git index
6. THE Healthcheck_Script SHALL be marked as executable in the Git index
7. WHEN analyzed by ShellCheck, THE Sysinfo_Script SHALL produce no warnings or errors
8. WHEN analyzed by ShellCheck, THE Healthcheck_Script SHALL produce no warnings or errors

### Requirement 8: Container Base Image Configuration

**User Story:** As a security engineer, I want to use pinned, minimal base images, so that the container has a predictable and small attack surface.

#### Acceptance Criteria

1. THE Dockerfile SHALL specify "alpine:3.21.3" as the Base_Image with an exact tag
2. THE Dockerfile SHALL install NGINX package version "1.26.3-r3" with an exact version pin
3. WHEN the NGINX_Image is built, THE final image size SHALL be less than 60 MB

### Requirement 9: Container Security Configuration

**User Story:** As a security engineer, I want the container to run as a non-root user, so that the application has minimal privileges.

#### Acceptance Criteria

1. THE Dockerfile SHALL create or use the "nginx" user account
2. THE Dockerfile SHALL set the USER directive to "nginx"
3. WHEN the NGINX_Image runs, THE main process SHALL execute as the "nginx" user

### Requirement 10: NGINX Server Configuration

**User Story:** As a web application developer, I want custom NGINX configuration, so that the server listens on port 8080 and provides a health endpoint.

#### Acceptance Criteria

1. THE Dockerfile SHALL copy a custom nginx.conf file to /etc/nginx/nginx.conf
2. THE nginx.conf SHALL configure the server to listen on port 8080
3. THE nginx.conf SHALL define a location for the Health_Endpoint at path "/healthz"
4. WHEN the Health_Endpoint is requested, THE server SHALL return HTTP 200 with body "ok"
5. THE nginx.conf SHALL configure writable temporary directories in /tmp for non-root operation
6. THE nginx.conf SHALL configure access logs to stdout and error logs to stderr

### Requirement 11: Build Argument for Traceability

**User Story:** As a release engineer, I want to embed build metadata in the application, so that I can trace deployed instances to specific commits.

#### Acceptance Criteria

1. THE Dockerfile SHALL declare a Build_Argument named "BUILD_SHA" with default value "local"
2. WHEN the NGINX_Image is built, THE Dockerfile SHALL embed the BUILD_SHA value into the served HTML page
3. WHEN the Build_Argument contains invalid characters, THE build SHALL fail with an error message
4. THE Build_Argument validation SHALL permit only letters, digits, dots, underscores, and hyphens

### Requirement 12: Container Health Check

**User Story:** As a container orchestrator, I want Docker health checks, so that I can detect unhealthy containers automatically.

#### Acceptance Criteria

1. THE Dockerfile SHALL include a HEALTHCHECK instruction
2. THE HEALTHCHECK SHALL request the Health_Endpoint at "http://127.0.0.1:8080/healthz"
3. THE HEALTHCHECK SHALL use an interval of 30 seconds
4. THE HEALTHCHECK SHALL use a timeout of 3 seconds
5. THE HEALTHCHECK SHALL use a start period of 5 seconds
6. THE HEALTHCHECK SHALL use 3 retries before marking the container unhealthy
7. WHEN the Health_Endpoint returns non-200 status, THE HEALTHCHECK SHALL report the container as unhealthy

### Requirement 13: Container Image Building

**User Story:** As a developer, I want to build the container image locally, so that I can test changes before pushing to the registry.

#### Acceptance Criteria

1. WHEN docker build is executed with the Dockerfile, THE NGINX_Image SHALL be created successfully
2. WHEN the Build_Argument is provided at build time, THE value SHALL be embedded in the HTML page
3. WHEN the Dockerfile is executed, THE nginx configuration SHALL be validated with "nginx -t" before completion

### Requirement 14: CI Pipeline Linting Stage

**User Story:** As a code quality engineer, I want automated linting, so that code quality issues are caught before merging.

#### Acceptance Criteria

1. THE CI_Pipeline SHALL include a lint job that runs on push and pull request events
2. THE lint job SHALL execute ShellCheck on the Sysinfo_Script
3. THE lint job SHALL execute ShellCheck on the Healthcheck_Script
4. THE lint job SHALL execute Hadolint on the Dockerfile
5. WHEN any linting tool reports errors, THE lint job SHALL fail

### Requirement 15: CI Pipeline Build Stage

**User Story:** As a CI engineer, I want automated image building, so that every commit produces a testable artifact.

#### Acceptance Criteria

1. THE CI_Pipeline SHALL include a build job that runs on push and pull request events
2. THE build job SHALL build the NGINX_Image using the commit SHA as the BUILD_SHA value
3. WHEN the build completes successfully, THE NGINX_Image SHALL be available for subsequent jobs

### Requirement 16: CI Pipeline Test Stage

**User Story:** As a QA engineer, I want automated endpoint testing, so that regressions are detected before deployment.

#### Acceptance Criteria

1. THE CI_Pipeline SHALL include a test job that runs after the build job
2. THE test job SHALL start a container from the built NGINX_Image
3. THE test job SHALL verify the root endpoint "/" returns HTTP 200
4. THE test job SHALL verify the Health_Endpoint "/healthz" returns HTTP 200
5. THE test job SHALL verify the response contains the expected build identifier
6. WHEN any endpoint check fails, THE test job SHALL fail

### Requirement 17: CI Pipeline Publish Stage

**User Story:** As a deployment engineer, I want automatic image publishing, so that main branch builds are available for deployment.

#### Acceptance Criteria

1. THE CI_Pipeline SHALL include a publish job that runs only for pushes to the main branch
2. THE publish job SHALL authenticate to GHCR using the GITHUB_TOKEN
3. THE publish job SHALL tag the NGINX_Image with the commit SHA
4. THE publish job SHALL tag the NGINX_Image with "latest"
5. THE publish job SHALL push both tags to GHCR
6. WHEN the publish job completes, THE NGINX_Image SHALL be pullable from GHCR

### Requirement 18: Nomad Job Specification

**User Story:** As a platform engineer, I want a Nomad job specification, so that the application can be deployed to a Nomad cluster.

#### Acceptance Criteria

1. THE Nomad_Job SHALL be named "nginx-app"
2. THE Nomad_Job SHALL declare variables for "image_repository" and "image_tag"
3. THE Nomad_Job SHALL target datacenters named "dc1"
4. THE Nomad_Job SHALL define a service group named "web" with count 1
5. THE Nomad_Job SHALL define a task named "nginx" using the Docker driver
6. THE Nomad_Job SHALL configure the task to use the image specified by the variables
7. THE Nomad_Job SHALL allocate 100 MHz CPU to the task
8. THE Nomad_Job SHALL allocate 64 MB memory to the task

### Requirement 19: Nomad Networking Configuration

**User Story:** As a network engineer, I want dynamic port allocation, so that multiple instances can coexist on the same host.

#### Acceptance Criteria

1. THE Nomad_Job SHALL define a dynamic port named "http" forwarded to container port 8080
2. THE Nomad_Job SHALL register a Consul service named "nginx-app" on the "http" port

### Requirement 20: Nomad Health Checking

**User Story:** As a reliability engineer, I want Consul health checks, so that unhealthy instances are detected and removed from service.

#### Acceptance Criteria

1. THE Nomad_Job SHALL define a Consul HTTP health check named "HTTP health"
2. THE health check SHALL request the Health_Endpoint path "/healthz"
3. THE health check SHALL use an interval of 10 seconds
4. THE health check SHALL use a timeout of 2 seconds
5. WHEN the Health_Endpoint returns HTTP 200, THE health check SHALL pass
6. WHEN the Health_Endpoint returns non-200 or times out, THE health check SHALL fail

### Requirement 21: Nomad Deployment Strategy

**User Story:** As a deployment engineer, I want rolling updates with health verification, so that deployments are safe and can be automatically reverted.

#### Acceptance Criteria

1. THE Nomad_Job SHALL configure rolling updates with max_parallel of 1
2. THE Nomad_Job SHALL require min_healthy_time of 10 seconds before considering a deployment successful
3. THE Nomad_Job SHALL set healthy_deadline of 2 minutes for new allocations to become healthy
4. THE Nomad_Job SHALL enable auto_revert to rollback failed deployments

### Requirement 22: Nomad Restart and Reschedule Policy

**User Story:** As a reliability engineer, I want automatic restart and rescheduling, so that transient failures are handled without manual intervention.

#### Acceptance Criteria

1. THE Nomad_Job SHALL configure restart attempts of 3 within a 5 minute interval
2. THE Nomad_Job SHALL configure restart delay of 15 seconds
3. THE Nomad_Job SHALL configure restart mode as "fail"
4. THE Nomad_Job SHALL configure reschedule attempts of 3 within a 1 hour interval
5. THE Nomad_Job SHALL configure reschedule with exponential delay starting at 30 seconds up to 5 minutes maximum
6. THE Nomad_Job SHALL disable unlimited rescheduling

### Requirement 23: Nomad Logging Configuration

**User Story:** As a operations engineer, I want log rotation, so that disk space is managed automatically.

#### Acceptance Criteria

1. THE Nomad_Job SHALL configure task logs with max_files of 3
2. THE Nomad_Job SHALL configure task logs with max_file_size of 5 MB

### Requirement 24: Nomad Job Validation and Deployment

**User Story:** As a deployment engineer, I want to validate and deploy the Nomad job, so that I can safely roll out the application.

#### Acceptance Criteria

1. WHEN nomad job validate is executed with required variables, THE Nomad_Job SHALL pass validation
2. WHEN nomad job plan is executed with required variables, THE Nomad_Job SHALL show a valid execution plan
3. WHEN nomad job run is executed with required variables, THE allocation SHALL be scheduled
4. WHEN the allocation starts and the health check passes, THE Nomad_Job status SHALL show "running"

### Requirement 25: Loki Configuration

**User Story:** As a monitoring engineer, I want a Loki instance for log aggregation, so that I can centralize and query container logs.

#### Acceptance Criteria

1. THE monitoring system SHALL deploy Loki version 3.0.0
2. THE Loki service SHALL listen on port 3100
3. THE Loki service SHALL use a custom configuration file mounted at /etc/loki/config.yaml
4. THE Loki service SHALL persist data to a named volume
5. WHEN Loki is healthy, THE /ready endpoint SHALL return a successful response

### Requirement 26: Promtail Configuration

**User Story:** As a logging engineer, I want Promtail to collect Docker logs, so that container output is sent to Loki.

#### Acceptance Criteria

1. THE monitoring system SHALL deploy Promtail version 3.0.0
2. THE Promtail service SHALL use a custom configuration file mounted at /etc/promtail/config.yaml
3. THE Promtail service SHALL mount the Docker socket at /var/run/docker.sock with read-only access
4. THE Promtail service SHALL discover Docker containers automatically
5. THE Promtail service SHALL apply labels "job", "container", and "service" to collected logs
6. THE Promtail service SHALL send logs to the Loki service

### Requirement 27: Grafana Configuration

**User Story:** As a monitoring engineer, I want Grafana for log visualization, so that I can query and explore logs through a web interface.

#### Acceptance Criteria

1. THE monitoring system SHALL deploy Grafana version 11.0.0
2. THE Grafana service SHALL listen on port 3000
3. THE Grafana service SHALL persist data to a named volume
4. WHEN Grafana is accessed, THE web interface SHALL be available at http://localhost:3000

### Requirement 28: Monitoring Stack Deployment

**User Story:** As a platform engineer, I want to deploy the monitoring stack with Docker Compose, so that I can quickly set up log aggregation.

#### Acceptance Criteria

1. THE monitoring system SHALL provide a docker-compose.yaml file
2. WHEN docker compose up is executed, THE Loki, Promtail, and Grafana services SHALL start
3. THE Promtail service SHALL depend on the Loki service
4. THE Grafana service SHALL depend on the Loki service
5. THE docker-compose.yaml SHALL define named volumes for Loki data, Promtail positions, and Grafana data

### Requirement 29: Log Query Verification

**User Story:** As a DevOps engineer, I want to query logs in Grafana, so that I can verify log collection is working correctly.

#### Acceptance Criteria

1. WHEN the NGINX_Image is running, THE container logs SHALL be collected by Promtail
2. WHEN Grafana is configured with Loki as a data source at http://loki:3100, THE connection SHALL succeed
3. WHEN a LogQL query is executed for the NGINX container, THE query SHALL return log entries
4. WHEN filtering for specific log content, THE query SHALL return matching entries

### Requirement 30: Comprehensive Documentation

**User Story:** As a project evaluator, I want comprehensive documentation, so that I can understand, build, and run the project.

#### Acceptance Criteria

1. THE README SHALL include an architecture overview with a text diagram
2. THE README SHALL include a repository layout section describing directory structure
3. THE README SHALL list all prerequisites with specific version numbers
4. THE README SHALL include a Quick Start section with fewer than 10 commands
5. THE README SHALL include sections for each major task: source control, Linux scripting, containerization, CI, Nomad deployment, and log aggregation
6. THE README SHALL include example commands with expected outputs or descriptions
7. THE README SHALL include a Troubleshooting section with common failure scenarios
8. THE README SHALL include a Known Limitations section documenting environment constraints

### Requirement 31: Documentation Quality

**User Story:** As a technical writer, I want clear and accurate documentation, so that users can follow instructions without ambiguity.

#### Acceptance Criteria

1. WHEN the README provides commands, THE commands SHALL use correct syntax for the documented tool versions
2. WHEN the README references file paths, THE paths SHALL be consistent with the repository structure
3. WHEN the README describes verification steps, THE steps SHALL be reproducible
4. THE README SHALL use markdown formatting for code blocks and command examples
5. THE README SHALL include placeholders (e.g., <OWNER>, <SHA>) where user-specific values are required

