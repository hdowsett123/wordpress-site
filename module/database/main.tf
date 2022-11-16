#S3
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "harrydowsetresume" {
  bucket = "harrydowsetresume"

  tags = {
    Name        = "wordpress-images"
    Environment = "Prod"
  }
}

resource "aws_s3_bucket_acl" "wordpress" {
  bucket = aws_s3_bucket.harrydowsetresume.id
  acl    = "private"
}

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_s3_bucket" "wordpress_alb_logs" {
  bucket        = "harrydowsetresume-alb-logs"
  acl           = "private"
  force_destroy = true
  tags = {
    Name = "LB Logs"
  }

  policy = <<EOF
 {
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : ["${data.aws_elb_service_account.main.arn}"]
        },
        "Action" : ["s3:PutObject"],
        "Resource" : ["arn:aws:s3:::harrydowsetresume-alb-logs/*"]
      }
    ]
 }
   EOF
}

#Elasticache
resource "aws_elasticache_parameter_group" "wordpress-cluster" {
  name   = "wordpress-cluster"
  family = "memcached1.6"

  parameter {
    name  = "max_item_size"
    value = 10485760
  }
}

resource "aws_elasticache_subnet_group" "private-data-1a" {
  name       = "private-data-1a"
  subnet_ids = [var.vpc.private_subnets[2]]
}

resource "aws_elasticache_cluster" "wordpress-cluster-1a" {
  cluster_id           = "wordpress-cluster"
  engine               = "memcached"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "wordpress-cluster"
  port                 = 11211
  subnet_group_name    = "private-data-1a"
  security_group_ids   = [var.sg.cache]
}

resource "aws_elasticache_subnet_group" "private-data-1b" {
  name       = "private-data-1b"
  subnet_ids = [var.vpc.private_subnets[3]]
}

resource "aws_elasticache_cluster" "wordpress-cluster-1b" {
  cluster_id           = "wordpress-cluster-1b"
  engine               = "memcached"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "wordpress-cluster"
  port                 = 11211
  subnet_group_name    = "private-data-1b"
  security_group_ids   = [var.sg.cache]
}

#Aurora
resource "aws_db_subnet_group" "DB_SUBNET_DATA" {
  name       = "main"
  subnet_ids = [var.vpc.private_subnets[2], var.vpc.private_subnets[3]]

  tags = {
    Name = "My DB subnet group Private"
  }
}

resource "aws_db_instance" "master_aurora_db" {
  allocated_storage       = 10
  engine                  = "mysql"
  engine_version          = 5.7
  instance_class          = "db.t2.micro"
  name                    = "aurora_db"
  username                = "admin"
  password                = random_string.password.result
  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "10:46-11:16"
  backup_retention_period = 1
  port                    = "3306"
  availability_zone       = "us-east-1b"

  final_snapshot_identifier = "prod-wordpress-db-snapshot"
  snapshot_identifier       = null
  skip_final_snapshot       = true
  vpc_security_group_ids    = [var.sg.aurora]
  db_subnet_group_name      = aws_db_subnet_group.DB_SUBNET_DATA.id
}

resource "aws_db_instance" "replica_aurora_db" {
  allocated_storage       = 10
  instance_class          = "db.t2.micro"
  password                = random_string.password.result
  maintenance_window      = "Mon:00:00-Mon:03:00"
  backup_window           = "10:46-11:16"
  backup_retention_period = 1
  port                    = "3306"
  availability_zone       = "us-east-1a"

  final_snapshot_identifier = "prod-wordpress-db-snapshot"
  snapshot_identifier       = null
  skip_final_snapshot       = true
  vpc_security_group_ids    = [var.sg.aurora]
  replicate_source_db       = aws_db_instance.master_aurora_db.id
}

resource "random_string" "password" {
  length  = 16
  special = false
}
