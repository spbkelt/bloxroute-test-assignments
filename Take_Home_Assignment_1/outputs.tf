output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.nginx_server.id
}

output "nginx_http_endpoint" {
  description = "HTTP endpoint to access the Nginx server"
  value       = "http://${aws_lb.nginx_alb.dns_name}"
}