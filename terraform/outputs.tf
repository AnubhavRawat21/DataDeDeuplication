# terraform/outputs.tf
# CloudSieve Pro — Infrastructure Deployment Outputs

output "elastic_ip" {
  description = "Static public IPv4 address assigned to the CloudSieve Pro server"
  value       = aws_eip.server_eip.public_ip
}

output "application_url" {
  description = "Web interface URL for CloudSieve Pro"
  value       = "http://${aws_eip.server_eip.public_ip}"
}

output "api_docs_url" {
  description = "FastAPI interactive documentation (Swagger UI)"
  value       = "http://${aws_eip.server_eip.public_ip}/docs"
}

output "health_check_url" {
  description = "Backend health and telemetry endpoint"
  value       = "http://${aws_eip.server_eip.public_ip}/health"
}

output "cloudwatch_log_group" {
  description = "Name of the Amazon CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "ssh_command" {
  description = "SSH connection command (using auto-generated key if applicable)"
  value       = var.existing_key_name == "" ? "ssh -i ${path.module}/cloudsieve-key.pem ubuntu@${aws_eip.server_eip.public_ip}" : "ssh -i <your-key-file>.pem ubuntu@${aws_eip.server_eip.public_ip}"
}
