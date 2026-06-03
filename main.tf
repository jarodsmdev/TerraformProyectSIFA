############################################
# CONFIGURACIÓN DEL LABORATORIO
############################################
locals {
  region = "us-east-1"

  project_name = "SIFA"

  # S3
  bucket_name = "sifa-core-images-quisco"

  # PAIR KEY
  key_name = "SIFA-KEY"

  # Elastic IP del gateway
  gateway_eip_allocation_id = "eipalloc-07238f86a5fb036d7"

  # AMI Ubuntu
  ubuntu_ami = "ami-05cf1e9f73fbad2e2"

  gateway_private_ip = "10.0.1.10"
  auth_private_ip    = "10.0.2.10"
  plate_private_ip   = "10.0.2.20"
  core_private_ip    = "10.0.2.30"
}

terraform {
  backend "s3" {
    bucket         = "sifa-terraform-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = local.region
}

module "vpc" {
  source = "./modules/vpc"

  project_name        = "SIFA"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  az                  = "us-east-1a"
}

# Security Group público
module "public_sg" {
  source = "./modules/sg"

  name        = "sifa-public-sg"
  description = "Public access"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow SSH from internet"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Allow HTTP from internet"
    },
    {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/16"] # Permitir ICMP solo desde la VPC
      description = "Allow ICMP from private subnet"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Security Group privado
module "private_sg" {
  source = "./modules/sg"

  name        = "sifa-private-sg"
  description = "Private access"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.public_sg.sg_id]
    },
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      security_groups = [module.public_sg.sg_id]
    },

  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# S3 para imágenes
module "s3_images" {
  source = "./modules/s3"

  bucket_name  = local.bucket_name # Debe ser único globalmente
  project_name = local.project_name
}

# EC2 en subnet pública con EIP (API-Gateway) IP: 3.219.255.24
module "public_ec2" {
  source = "./modules/ec2"

  name               = "sifa-gateway"
  ami                = local.ubuntu_ami
  instance_type      = "t3.micro"
  subnet_id          = module.vpc.public_subnet_id
  security_group_ids = [module.public_sg.sg_id]
  private_ip         = local.gateway_private_ip // Asignación de IP privada en la subnet pública

  key_name = local.key_name

  associate_eip = true
  allocation_id = local.gateway_eip_allocation_id // Reemplaza con tu Allocation ID del EIP creado para el NAT Gateway IP: 3.219.255.24

  user_data = file("${path.root}/modules/scripts/docker-install.sh")
}

# EC2 en subnet privada sin EIP (Auth-Service)
module "private_ec2" {
  source = "./modules/ec2"

  name               = "sifa-auth"
  ami                = local.ubuntu_ami
  instance_type      = "t3.micro"
  subnet_id          = module.vpc.private_subnet_id
  security_group_ids = [module.private_sg.sg_id]
  private_ip         = local.auth_private_ip // Asignación de IP privada en la subnet privada

  key_name = local.key_name

  associate_eip = false

  user_data = file("${path.root}/modules/scripts/docker-install.sh")
}

# EC2 en subnet privada sin EIP (Plate-Service)
module "private_ec2_plate" {
  source = "./modules/ec2"

  name               = "sifa-plate"
  ami                = local.ubuntu_ami
  instance_type      = "t3.large"
  subnet_id          = module.vpc.private_subnet_id
  security_group_ids = [module.private_sg.sg_id]
  private_ip         = local.plate_private_ip // Asignación de IP privada en la subnet privada

  key_name = local.key_name

  associate_eip = false

  user_data = file("${path.root}/modules/scripts/docker-install.sh")
}

# EC2 en subnet privada sin EIP (Sifa-Core-Service)
module "private_ec2_core" {
  source = "./modules/ec2"

  name                 = "sifa-core"
  ami                  = local.ubuntu_ami
  instance_type        = "t3.micro"
  subnet_id            = module.vpc.private_subnet_id
  security_group_ids   = [module.private_sg.sg_id]
  private_ip           = local.core_private_ip // Asignación de IP privada en la subnet privada
  iam_instance_profile = "EMR_EC2_DefaultRole" // Perfil de IAM para permitir acceso a S3 desde la instancia

  key_name = local.key_name

  associate_eip = false

  user_data = file("${path.root}/modules/scripts/docker-install.sh")
}
