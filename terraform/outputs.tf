output "backend_url" {
  description = "URL for the CloudSieve backend API"
  value       = "http://localhost:${var.backend_port}"
}

output "frontend_url" {
  description = "URL for the CloudSieve frontend app"
  value       = "http://localhost:${var.frontend_port}"
}

output "api_docs_url" {
  description = "URL for the FastAPI auto-generated docs"
  value       = "http://localhost:${var.backend_port}/docs"
}

output "backend_container_id" {
  description = "Docker container ID for backend"
  value       = docker_container.backend.id
}

output "frontend_container_id" {
  description = "Docker container ID for frontend"
  value       = docker_container.frontend.id
}

output "network_name" {
  description = "Docker network name"
  value       = docker_network.cloudsieve.name
}
