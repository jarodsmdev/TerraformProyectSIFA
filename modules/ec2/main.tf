resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  private_ip             = var.private_ip
  iam_instance_profile   = var.iam_instance_profile

  user_data              = var.user_data

  user_data_replace_on_change = true

  tags = {
    Name = var.name
  }
}

# Asociación opcional de Elastic IP
resource "aws_eip_association" "this" {
  count = var.associate_eip ? 1 : 0

  instance_id   = aws_instance.this.id
  allocation_id = var.allocation_id

}
