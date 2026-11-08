variable "image_repository" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

job "nginx-app" {
  datacenters = ["dc1"]
  type        = "service"

  group "web" {
    count = 1

    network {
      port "http" {
        to = 8080
      }
    }

    service {
      name     = "nginx-app"
      port     = "http"
      provider = "consul"

      check {
        name     = "HTTP health"
        type     = "http"
        path     = "/healthz"
        interval = "10s"
        timeout  = "2s"
      }
    }

    update {
      max_parallel     = 1
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "${var.image_repository}:${var.image_tag}"
        ports = ["http"]
      }

      resources {
        cpu    = 100
        memory = 64
      }

      logs {
        max_files     = 3
        max_file_size = 5
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "1h"
      delay          = "30s"
      delay_function = "exponential"
      max_delay      = "5m"
      unlimited      = false
    }
  }
}
