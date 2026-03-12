provider "aws" {
  region = "us-west-1"
}

resource "aws_instance" "bastion_host" {
  ami           = "ami-08012c0a9ee8e21c4"
  instance_type = "t2.micro"
  key_name      = var.pem_name
  subnet_id     = var.public_subnets[0]

  tags = {
    Name = "${var.name_prefix}-bastion-host"
  }

  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.name_prefix}-bastion-SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-bastion-SG"
  }
}

resource "aws_instance" "database_instance" {
  ami           = "ami-08012c0a9ee8e21c4"
  instance_type = "t2.medium"
  key_name      = var.pem_name
  subnet_id     = var.private_subnet_id

  tags = {
    Name = "${var.name_prefix}-db-instance"
  }

  vpc_security_group_ids = [aws_security_group.database_sg.id]
  
  depends_on = [aws_instance.bastion_host]
}

resource "null_resource" "db_provisioner" {
  // Using triggers to ensure that this null_resource re-runs whenever the instance ID changes
  triggers = {
    instance_id = aws_instance.database_instance.id
  }

  provisioner "local-exec" {
    command = <<EOT
      chmod +x ${path.module}/run_ansible.sh
      ${path.module}/run_ansible.sh ${path.module}/db_ansible ${aws_instance.database_instance.private_ip} ${aws_instance.bastion_host.public_ip} /tmp/dashboard_secrets/${var.pem_name}.pem
    EOT
  }

  depends_on = [
    aws_instance.database_instance
  ]
}

resource "aws_security_group" "database_sg" {
  name_prefix = "${var.name_prefix}-db-SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-db-SG"
  }
}

resource "aws_route53_zone" "private" {
  name = "deploycluster"
  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "db_record" {
  zone_id = aws_route53_zone.private.zone_id
  name = "db"
  type = "A"
  ttl = 300
  records = [aws_instance.database_instance.private_ip]
}