variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidr" {
  type = string
}

variable "private_app_subnet_cidr" {
  type = string
}

variable "private_db_subnet_1_cidr" {
  type = string
}

variable "private_db_subnet_2_cidr" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}