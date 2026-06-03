output "web_public_ip" {
  value = module.compute.web_public_ip
}

output "app_private_ip" {
  value = module.compute.app_private_ip
}

output "db_endpoint" {
  value = module.database.db_endpoint
}