variable "docker_host" {
  description = "Docker daemon socket"
  type        = string
  default     = "npipe:////.//pipe//docker_engine"   # Windows default
}

variable "app_version" {
  description = "Application version tag for Docker images"
  type        = string
  default     = "2.0.0"
}

variable "backend_port" {
  description = "Host port for the backend API"
  type        = number
  default     = 8000
}

variable "frontend_port" {
  description = "Host port for the frontend app"
  type        = number
  default     = 3000
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}
