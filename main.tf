provider "aws" {
  region     = "us-east-1"
  access_key = "*"
  secret_key = "*"
}

#VPC
resource "aws_vpc" "sgp" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "SGP"
  }
}
# Create IGW
resource "aws_internet_gateway" "gw" {
   vpc_id = aws_vpc.sgp.id
}

# Create public subnet
resource "aws_subnet" "publicsubnet" {
  vpc_id            = aws_vpc.sgp.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-subnet"
  }
}

# Create Private subnet
resource "aws_subnet" "privatesubnet" {
  vpc_id            = aws_vpc.sgp.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Private-subnet"
  }
}


resource "aws_route_table" "public-route-table" {
    vpc_id = aws_vpc.sgp.id

    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
}

    route {
     ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
   }

   tags = {
     Name = "Public"
   }
 }

#create network interface
resource "aws_network_interface" "sgp-nic" {
   subnet_id       = aws_subnet.privatesubnet.id
   private_ips     = ["10.0.2.50"]
   security_groups = [aws_security_group.allow_web.id]

}

#create private route table
 resource "aws_route_table" "private-route-table" {
    vpc_id = aws_vpc.sgp.id
    

    route {
    cidr_block = "10.0.2.0/24"
    network_interface_id = aws_network_interface.sgp-nic.id
    
}

   tags = {
     Name = "Private"
   }
 }

# associate subnet
resource "aws_route_table_association" "public" {
   subnet_id      = aws_subnet.publicsubnet.id
   route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "private" {
   subnet_id      = aws_subnet.privatesubnet.id
   route_table_id = aws_route_table.private-route-table.id
}

# Create Security group
resource "aws_security_group" "allow_web" {
   name        = "allow_web_traffic"
   description = "Allow Web inbound traffic"
   vpc_id      = aws_vpc.sgp.id

   ingress {
     description = "HTTPS"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "HTTP"
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "SSH"
     from_port   = 22
     to_port     = 22
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }

   egress {
     from_port   = 0
     to_port     = 0
     protocol    = "-1"
     cidr_blocks = ["0.0.0.0/0"]
   }

   tags = {
     Name = "allow_web"
   }
}

#Create EC2
resource "aws_instance" "web-server-instance" {
   ami               = "ami-087c17d1fe0178315"
   instance_type     = "t2.micro"
   availability_zone = "us-east-1a"
   key_name          = "sgp"


   tags = {
     Name = "web-server"
   }
}

### For Elastic Beanstalk

# Create elastic beanstalk application

resource "aws_elastic_beanstalk_application" "elasticapp" {
  name = var.elasticapp
}

# Create elastic beanstalk Environment

resource "aws_elastic_beanstalk_environment" "beanstalkappenv" {
  name                = var.beanstalkappenv
  application         = aws_elastic_beanstalk_application.elasticapp.name
  solution_stack_name = var.solution_stack_name
  tier                = var.tier

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     =  "aws-elasticbeanstalk-ec2-role"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     =  "True"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.public_subnets)
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.medium"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet facing"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

}
