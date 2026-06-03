output "web_public_ip" {
  value = aws_instance.web.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}