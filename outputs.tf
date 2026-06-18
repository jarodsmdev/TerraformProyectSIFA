output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_ec2" {
  value = {
    name        = module.public_ec2.name
    public_ip   = module.public_ec2.public_ip
    instance_id = module.public_ec2.instance_id
  }
}

output "private_ec2" {
  value = {
    name        = module.private_ec2.name
    private_ip  = module.private_ec2.private_ip
    instance_id = module.private_ec2.instance_id
  }
}

output "private_ec2_core" {
  value = {
    name       = module.private_ec2_core.name
    private_ip = module.private_ec2_core.private_ip
  }
}

output "private_ec2_plate" {
  value = {
    name       = module.private_ec2_plate.name
    private_ip = module.private_ec2_plate.private_ip
  }
}

output "mysql" {
  value = {
    name        = "sifa-mysql"
    private_ip  = module.mysql.private_ip
    public_ip   = module.mysql.public_ip
    instance_id = module.mysql.instance_id
  }
}