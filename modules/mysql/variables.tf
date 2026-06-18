variable "name" {}
variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" {
  type = list(string)
}
variable "key_name" {}
variable "private_ip" {
  type    = string
  default = null
}
variable "mysql_user" {}
variable "mysql_password" {}
variable "associate_eip" {
  type    = bool
  default = false
}
variable "allocation_id" {
  type    = string
  default = null
}
