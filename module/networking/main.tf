data "aws_availability_zones" "available" {}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.16.1"
  name = "wordpress_website_vpc"
  cidr = "10.11.0.0/16"
  azs = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.11.1.0/24", "10.11.2.0/24", "10.11.5.0/24", "10.11.6.0/24"]
  public_subnets = ["10.11.3.0/24", "10.11.4.0/24"]
  enable_nat_gateway  = true
  one_nat_gateway_per_az = true
  single_nat_gateway = false
}

#security groups
resource "aws_security_group" "DEVOPS_ADMIN" {
  name        = "DEVOPS_ADMIN"
  description = "Security group for DEVOPS_ADMIN access"
  vpc_id      = module.vpc.vpc_id

  #inbound admin whitelist
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    #inbound ssh from: devops admins
    cidr_blocks = [var.devops_admin_public_ip]
    self        = true
  }
  #icmp from the office and vpn for ping
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.devops_admin_public_ip]
    self        = true
  }
  #EFS ingress
  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
  }
  #wide open egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "DEVOPS_ADMIN access"
  }
}

resource "aws_security_group" "edge-frontends-instances" {
  name        = "edge-frontends-instances"
  description = "Security group for edge-frontends instances"
  vpc_id      = module.vpc.vpc_id

  #inbound 80 from the alb and DEVOPS_ADMIN
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.edge-frontends-alb.id, aws_security_group.DEVOPS_ADMIN.id]
  }
  #inbound 443 from the alb and DEVOPS_ADMIN
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.edge-frontends-alb.id, aws_security_group.DEVOPS_ADMIN.id]
  }
  #inbound 22 from DEVOPS_ADMIN
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.DEVOPS_ADMIN.id]
    self            = true
  }
  #wide open egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Edge Frontends instances"
  }
}

resource "aws_security_group" "edge-frontends-alb" {
  name        = "edge-frontends-alb"
  description = "Security group for edge-frontends ALB"
  vpc_id      = module.vpc.vpc_id

  #inbound 80 from the alb
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["67.164.84.151/32"]
  }
  #inbound 443 from the alb
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["67.164.84.151/32"]
    security_groups = [aws_security_group.DEVOPS_ADMIN.id]
  }
  #wide open egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #inbound 80 from the DEVOPS_ADMIN
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.DEVOPS_ADMIN.id]
  }

  tags = {
    Name = "Wordpress ALB"
  }
}

#Elasticache SG
resource "aws_security_group" "elasticache" {
  name        = "elasticache"
  description = "Allow TLS inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 11211
    to_port     = 11211
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
    Name = "allow_tls"
  }
}

#Aurora DB
resource "aws_security_group" "aurora_db" {
  name        = "aurora_db"
  description = "database"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.11.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
