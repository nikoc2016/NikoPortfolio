provider "aws" {
  region = "us-west-1"
}

module "networking" {
  source     = "./modules/networking"
  name_prefix = var.name_prefix
}

module "database" {
  source        = "./modules/database"
  name_prefix   = var.name_prefix
  vpc_id        = module.networking.vpc_id
  pem_name      = var.pem_name
  public_subnets = module.networking.public_subnets
  private_subnet_id = module.networking.private_subnet_id
  vpc_cidr_block    = module.networking.vpc_cidr_block
}

module "eks" {
  source     = "./modules/eks"
  name_prefix = var.name_prefix
  subnets     = module.networking.public_subnets
  eks_role_arn = var.eks_role_arn
  node_role_arn = var.node_role_arn
}


terraform {
  backend "s3" {
    bucket = "prometheus-spacec"
    key    = "terraform/dashboard/terraform.tfstate"
    region = "us-west-1"
  }
}
