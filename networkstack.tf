########################### VPC  ###############################
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "default" {
  route_table_id         = aws_vpc.vpc.main_route_table_id
  gateway_id             = aws_internet_gateway.gw.id
  destination_cidr_block = "0.0.0.0/0"
}

######################################## ALB Public Subnet #################################################

resource "aws_subnet" "alb" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(split(",", var.alb_cidrs), count.index)
  availability_zone       = element(split(",", var.alb_azs), count.index)
  count                   = length(split(",", var.alb_cidrs))
  map_public_ip_on_launch = true

  tags = {
    Name = "Private Subnet"
  }
}




#################################################  NAT Instance #############################################
resource "aws_security_group" "nat_sec" {
  name        = "nat_sec"
  description = "Allow traffic to pass from the private subnet to the internet"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.fargate_cidrs]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.fargate_cidrs]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "NATSEC"
  }
}

resource "aws_instance" "natserver" {
  ami                         = "ami-0553ff0c22b782b45" # this is a special ami preconfigured to do NAT
  availability_zone           = "us-west-2a"
  instance_type               = "t2.micro"
  key_name                    = var.aws_key_name
  vpc_security_group_ids      = [aws_security_group.nat_sec.id]
  subnet_id                   = aws_subnet.alb[0].id
  associate_public_ip_address = true
  source_dest_check           = false

  tags = {
    Name = " NAT"
  }
}


resource "aws_eip" "nat" {
  instance = aws_instance.natserver.id
  vpc      = true
}


########################################################### Fargate Private subnet ######################################################

# note : we have configured Nat instance to route outside internet traffic 
resource "aws_subnet" "fargate" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(split(",", var.fargate_cidrs), count.index)
  availability_zone = element(split(",", var.fargate_azs), count.index)
  count             = length(split(",", var.fargate_cidrs))

  tags = {
    Name = "Private Subnet"
  }

}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.natserver.id
  }

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_route_table_association" "private" {
  count          = 1
  subnet_id      = aws_subnet.fargate[count.index].id
  route_table_id = aws_route_table.private.id
}


############################### security_groups ##################################
resource "aws_security_group" "alb" {
  name        = "alb-security-group"
  description = "ingress to the ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.alb_port
    to_port     = var.alb_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-task-security-group"
  description = "allow inbound from ALB to ECS Fargate"
  vpc_id      = aws_vpc.vpc.id

  # restricts access from the Internet 
  ingress {
    protocol        = "tcp"
    from_port       = var.web_port
    to_port         = var.web_port
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
