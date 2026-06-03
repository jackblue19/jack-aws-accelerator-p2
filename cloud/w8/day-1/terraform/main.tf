terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.44.0"
    }
  }
  required_version = ">= 1.8.0"
}

provider "aws" {
  region = "ap-southeast-1"
}

# resource "local_file" "hello" {
#   filename = "hello.txt"
#   content  = "Hello, Terraform!"
# }

resource "aws_s3_bucket" "demo-tf" {
  bucket = "demo-tf-bucket-2026zzzzzzzzzzzzzzzzzzzz"
  # acl    = "private"
  tags = {
    Name        = "demo-tf-bucket"
    Environment = "Dev"
  }
}

# terraform state pull -> dùng để lấy nội dung của state file về local, 
      # thường dùng khi muốn xem nội dung của state file hoặc muốn backup state file về local
