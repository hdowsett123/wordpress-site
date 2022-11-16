#EC2
module "ec2_instance_bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"
  
  count = 2

  name = "bastion-instance-${count.index+1}"

  ami                    = "ami-0cff7528ff583bf9a"
  instance_type          = "t2.micro"
  key_name               = "ssh-keys.pub"
  monitoring             = false
  vpc_security_group_ids = [var.sg.admin]
  subnet_id              = var.vpc.public_subnets[count.index]
  associate_public_ip_address = true
  source_dest_check           = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_instance_private" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  count = 4

  name = "private-instance-${count.index+1}"

  ami                    = "ami-0cff7528ff583bf9a"
  instance_type          = "t2.micro"
  monitoring             = false
  vpc_security_group_ids = [var.sg.admin]
  subnet_id              = var.vpc.private_subnets[count.index]
  associate_public_ip_address = true
  source_dest_check           = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#ALB
resource "aws_lb" "frontends" {
  name                             = "Edge-frontends"
  internal                         = false
  load_balancer_type               = "application"
  security_groups                  = [var.sg.lb]
  subnets                          = var.vpc.public_subnets
  enable_cross_zone_load_balancing = true

  enable_deletion_protection = true

  access_logs {
    bucket  = "harrydowsetresume-alb-logs"
    prefix  = "frontends"
    enabled = true
  }

  #tags = {
    #Environment = "production"
  #}
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.frontends.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_target.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.frontends.arn
  port              = 443
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb_target.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "alb_target" {
  name     = "Edge-Frontends"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = var.vpc.vpc_id
  tags = {
    name = "Edge-Frontends"
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
}

#Autoscaling
resource "aws_placement_group" "wordpress-ASG" {
  name     = "Edge frontends"
  strategy = "cluster"
}

resource "aws_launch_configuration" "edge-frontends" {
  name_prefix     = "edge-frontends autoscaling launch configuration"
  image_id        = "ami-0cff7528ff583bf9a"
  instance_type   = "t2.micro"
  security_groups = [var.sg.asg]
  user_data       = "wordpress-web"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "edge-frontends" {
  vpc_zone_identifier       = [var.vpc.public_subnets[0],var.vpc.public_subnets[1], var.vpc.private_subnets[0], var.vpc.private_subnets[1]]
  name                      = "edge-frontends"
  max_size                  = 4
  min_size                  = 2
  wait_for_capacity_timeout = "300s"
  health_check_grace_period = 10
  health_check_type         = "EC2"
  desired_capacity          = 2
  target_group_arns         = [aws_alb_target_group.alb_target.arn]
  force_delete              = true
  launch_configuration      = aws_launch_configuration.edge-frontends.name
  depends_on                = [aws_lb.frontends]

  timeouts {
    delete = "15m"
  }

}

#EFS
resource "aws_efs_file_system" "wordpress-efs" {
  creation_token   = "efs-token"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"
  tags = {
    Name = "wordpress-efs"
  }
}

resource "aws_efs_mount_target" "efs-mount" {
  file_system_id  = aws_efs_file_system.wordpress-efs.id
  count           = 2
  subnet_id       = var.vpc.private_subnets[count.index+2]
  security_groups = [var.sg.admin]
}

resource "null_resource" "configure_nfs" {
  count = 2
  depends_on = [aws_efs_mount_target.efs-mount]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.my_key.private_key_pem
    host        = aws_instance.ec201.public_ip
  }
}
