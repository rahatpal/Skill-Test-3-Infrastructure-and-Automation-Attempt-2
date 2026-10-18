output "public_ip" {
  description = "Public IPv4 address of the Nginx EC2 instance."
  value       = aws_instance.nginx.public_ip
}

output "website_url" {
  description = "Open this HTTP URL after cloud-init finishes installing Nginx."
  value       = "http://${aws_instance.nginx.public_ip}"
}
