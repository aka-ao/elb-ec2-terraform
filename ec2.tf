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
  instance = aws_instance.ec2[count.index].id
  tags = {
    Name = "elb_ec2_${count.index}"
  }
}

resource "aws_ebs_volume" "second_ebs" {
  availability_zone = data.aws_availability_zones.available.names[0]
  encrypted         = true
  size              = 1
}

resource "aws_volume_attachment" "second_ebs" {
  depends_on  = [aws_instance.ec2[0], aws_ebs_volume.second_ebs]
  device_name = "/dev/sdh"
  instance_id = aws_instance.ec2[0].id
  volume_id   = aws_ebs_volume.second_ebs.id
}

resource "null_resource" "mount_ebs" {
  depends_on = [aws_volume_attachment.second_ebs]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_eip.elb_ec2[0].public_ip
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
    }

    inline = [
      "sudo mkfs -t ext4 /dev/sdh",
      "sudo mkdir /data2",
      "sudo mount /dev/sdh /data2"
    ]
  }
}
