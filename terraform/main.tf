# ──────────────────────────────────────────────────────────────
# CloudSieve Pro — Terraform Configuration
# Infrastructure as Code using Docker Provider
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

# ── Docker Network ──
resource "docker_network" "cloudsieve" {
  name   = "cloudsieve-network"
  driver = "bridge"
}

# ── Backend Image ──
resource "docker_image" "backend" {
  name = "cloudsieve-backend:${var.app_version}"
  build {
    context    = "${path.module}/../backend"
    dockerfile = "${path.module}/../docker/Dockerfile.backend"
    tag        = ["cloudsieve-backend:${var.app_version}", "cloudsieve-backend:latest"]
  }
}

# ── Frontend Image ──
resource "docker_image" "frontend" {
  name = "cloudsieve-frontend:${var.app_version}"
  build {
    context    = "${path.module}/../frontend"
    dockerfile = "${path.module}/../docker/Dockerfile.frontend"
    tag        = ["cloudsieve-frontend:${var.app_version}", "cloudsieve-frontend:latest"]
  }
}

# ── Persistent Volumes ──
resource "docker_volume" "uploads" {
  name = "cloudsieve-uploads"
}

resource "docker_volume" "outputs" {
  name = "cloudsieve-outputs"
}

# ── Backend Container ──
resource "docker_container" "backend" {
  name  = "cloudsieve-backend"
  image = docker_image.backend.image_id

  ports {
    internal = 8000
    external = var.backend_port
  }

  volumes {
    volume_name    = docker_volume.uploads.name
    container_path = "/app/uploads"
  }

  volumes {
    volume_name    = docker_volume.outputs.name
    container_path = "/app/outputs"
  }

  env = [
    "ENVIRONMENT=production",
    "PYTHONUNBUFFERED=1"
  ]

  networks_advanced {
    name = docker_network.cloudsieve.id
  }

  restart = "unless-stopped"

  healthcheck {
    test         = ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }
}

# ── Frontend Container ──
resource "docker_container" "frontend" {
  name  = "cloudsieve-frontend"
  image = docker_image.frontend.image_id

  ports {
    internal = 80
    external = var.frontend_port
  }

  networks_advanced {
    name = docker_network.cloudsieve.id
  }

  restart   = "unless-stopped"
  depends_on = [docker_container.backend]
}
