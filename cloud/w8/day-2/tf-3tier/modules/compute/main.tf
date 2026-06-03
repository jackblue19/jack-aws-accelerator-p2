resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.public_subnet_id

  vpc_security_group_ids = [var.web_sg_id]

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "Hello from Web Tier" > /var/www/html/index.html
EOF

  tags = {
    Name = "${var.project_name}-web-ec2"
  }
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.private_app_subnet_id

  vpc_security_group_ids = [var.app_sg_id]

  tags = {
    Name = "${var.project_name}-app-ec2"
  }
}