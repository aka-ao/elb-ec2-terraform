data "aws_route_table" "elb_ec2" {
  vpc_id = aws_vpc.elb_ec2_vpc.id
}

resource "aws_route" "route" {
  route_table_id         = data.aws_route_table.elb_ec2.id
  gateway_id             = aws_internet_gateway.elb_ec2.id
  destination_cidr_block = "0.0.0.0/0"
}


resource "aws_internet_gateway" "elb_ec2" {
  vpc_id = aws_vpc.elb_ec2_vpc.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnets" {
  count = 2
  //  # 先程作成したVPCを参照し、そのVPC内にSubnetを立てる
  vpc_id = aws_vpc.elb_ec2_vpc.id

  cidr_block = "10.0.${count.index + 1}.0/24"

  # Subnetを作成するAZ
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "aws-elb-ec2-subnet-${count.index + 1}"
  }
}
