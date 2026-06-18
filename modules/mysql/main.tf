resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name
  private_ip             = var.private_ip

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt update -y
    apt install mysql-server -y

    systemctl start mysql
    systemctl enable mysql

    sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    systemctl restart mysql

    mysql -e "CREATE USER '${var.mysql_user}'@'%' IDENTIFIED BY '${var.mysql_password}';"
    mysql -e "GRANT ALL PRIVILEGES ON *.* TO '${var.mysql_user}'@'%' WITH GRANT OPTION;"
    mysql -e "FLUSH PRIVILEGES;"
    EOF

  user_data_replace_on_change = true

  tags = {
    Name = var.name
  }
}

resource "aws_eip_association" "this" {
  count = var.associate_eip ? 1 : 0

  instance_id   = aws_instance.this.id
  allocation_id = var.allocation_id
}
