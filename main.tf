#Backend
terraform {
  backend "s3" {
    bucket         = "terraform-state-wordpress-website"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_locking"
    encrypt        = true
  }
}

#Modules
module "database" {
  source = "./module/database"
  sg     = module.networking.sg
  vpc    = module.networking.vpc
}

module "autoscaling" {
  source = "./module/autoscaling"
  vpc    = module.networking.vpc
  sg     = module.networking.sg
}

module "networking" {
  source                 = "./module/networking"
  devops_admin_public_ip = var.devops_admin_public_ip
  vpc                    = module.networking.vpc
}

