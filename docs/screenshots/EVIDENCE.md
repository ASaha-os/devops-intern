# Evidence Documentation

## Docker Build

**Command:**
```bash
docker build --build-arg BUILD_SHA=abc1234 -t nginx-app:abc1234 d:\devops-intern\app
```

**Image Size:**
```
IMAGE               ID             DISK USAGE   CONTENT SIZE
nginx-app:abc1234   eb5603584905       14.5MB         4.28MB
```

✅ Image size: **14.5 MB** (well under 60 MB requirement)

## Container Runtime

**Container started successfully:**
```bash
docker run --rm --name nginx-app -p 8080:8080 nginx-app:abc1234
```

### Endpoint Tests

**Root endpoint (/):**
```bash
$ curl http://localhost:8080/
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
      <p>Build identifier: abc1234</p>
    </main>
  </body>
</html>
```

**Health endpoint (/healthz):**
```bash
$ curl http://localhost:8080/healthz
ok
```

✅ Both endpoints responding correctly
✅ BUILD_SHA successfully injected into page

## Monitoring Stack

**Started monitoring stack:**
```bash
docker compose -f monitoring/docker-compose.yaml up
```

**Services running:**
- ✅ Loki (port 3100)
- ✅ Promtail (log collection)  
- ✅ Grafana (port 3000)

### Loki Query Example

**LogQL Query:**
```
{job="docker", container="nginx-app"}
```

**Expected Results:** Container logs from NGINX showing HTTP requests

### Grafana Access

- URL: http://localhost:3000
- Data Source: http://loki:3100
- Query logs in Explore tab

## Nomad Deployment (Example Output)

**Command:**
```bash
nomad job run -var='image_repository=ghcr.io/asaha-os/devops-intern' -var='image_tag=abc1234' nomad/nginx-app.nomad.hcl
```

**Expected Output:**
```
Job "nginx-app" submitted successfully
==> Monitoring evaluation "a1b2c3d4"
    Evaluation triggered by job "nginx-app"
    Allocation "e5f6g7h8" created: node "i9j0k1l2", group "web"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "a1b2c3d4" finished with status "complete"
```

**Note:** Nomad deployment requires a running Nomad/Consul cluster. The above shows expected output format for documentation purposes.