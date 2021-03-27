# AWS基本設定
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = "ap-northeast-1"
}

resource "aws_vpc" "elb_ec2_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "elb_ec2_vpc"
  }
}

data "aws_route_table" "elb_ec2" {
  vpc_id = aws_vpc.elb_ec2_vpc.id
}

resource "aws_route" "route" {
  route_table_id = data.aws_route_table.elb_ec2.id
  gateway_id = aws_internet_gateway.elb_ec2.id
  destination_cidr_block = "0.0.0.0/0"
}


resource "aws_internet_gateway" "elb_ec2" {
  vpc_id = aws_vpc.elb_ec2_vpc.id
}

resource "aws_security_group" "elb_ec2" {
  vpc_id = aws_vpc.elb_ec2_vpc.id
  name = "elb_ec2"
  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    protocol = "TCP"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnets" {
  count = 2
//  # 先程作成したVPCを参照し、そのVPC内にSubnetを立てる
  vpc_id = aws_vpc.elb_ec2_vpc.id

  cidr_block = "10.0.${count.index+1}.0/24"

  # Subnetを作成するAZ
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_key_pair" "elb_ec2" {
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "ec2" {
  count         = 2
  ami           = "ami-0bc8ae3ec8e338cbc"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnets[count.index].id
  key_name      = aws_key_pair.elb_ec2.id
  tags = {
    Name = "elb-ec2-${count.index}"
  }
  security_groups = [aws_security_group.elb_ec2.id]

  user_data = <<EOF
  #!/bin/bash
  sudo yum install -y httpd
  sudo yum install -y mysql
  sudo systemctl start httpd
  sudo systemctl enable httpd
  sudo usermod -a -G apache ec2-user
  sudo chown -R ec2-user:apache /var/www
  sudo chmod 2775 /var/www
  find /var/www -type d -exec chmod 2775 {} \;
  find /var/www -type f -exec chmod 0664 {} \;
  echo `hostname` > /var/www/html/index.html
  EOF
}

resource "aws_eip" "elb_ec2" {
  count    = 2
  vpc      = true
  instance = aws_instance.ec2[count.index].id
  tags = {
    Name = "elb_ec2_${count.index}"
  }
}

resource "aws_alb" "ec2_alb" {
  name = "ec2alb"
  subnets = aws_subnet.subnets.*.id
  security_groups = [aws_security_group.elb_ec2.id]

}

resource "aws_lb_target_group" "lb_target_group" {
  name = "ec2alb"
  protocol = "HTTP"
  port = "80"
  vpc_id = aws_vpc.elb_ec2_vpc.id
  health_check {
    protocol = "HTTP"
    path = "/"
  }
}

output "lb_result" {
  value = aws_alb.ec2_alb.dns_name
}

resource "aws_lb_target_group_attachment" "alb_ec2" {
  count = 2
  target_group_arn = aws_lb_target_group.lb_target_group.arn
  target_id = aws_instance.ec2[count.index].id
  port             = 80
}

resource "aws_lb_listener" "alb_ec2" {
  load_balancer_arn = aws_alb.ec2_alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
