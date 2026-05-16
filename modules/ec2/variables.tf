variable "name" {}
variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" {
  type = list(string)
}
variable "key_name" {}

variable "associate_eip" {
  type    = bool
  default = false
}

variable "allocation_id" {
  type    = string
  default = null
}

variable "user_data" {
  type    = string
  default = null
}

variable "private_ip" {
  type    = string
  default = null
}

variable "iam_instance_profile" {
  type    = string
  default = null
}
