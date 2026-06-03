module "network" {
  source = "./modules/network"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidr       = var.public_subnet_cidr
  private_app_subnet_cidr  = var.private_app_subnet_cidr
  private_db_subnet_1_cidr = var.private_db_subnet_1_cidr
  private_db_subnet_2_cidr = var.private_db_subnet_2_cidr
}

module "security" {
  source = "./modules/security"

  project_name = var.project_name
  vpc_id       = module.network.vpc_id
}

module "compute" {
  source = "./modules/compute"

  project_name  = var.project_name
  ami_id        = var.ami_id
  instance_type = var.instance_type

  public_subnet_id      = module.network.public_subnet_id
  private_app_subnet_id = module.network.private_app_subnet_id

  web_sg_id = module.security.web_sg_id
  app_sg_id = module.security.app_sg_id
}

module "database" {
  source = "./modules/database"

  project_name = var.project_name

  private_db_subnet_ids = module.network.private_db_subnet_ids
  db_sg_id              = module.security.db_sg_id

  db_username = var.db_username
  db_password = var.db_password
}
