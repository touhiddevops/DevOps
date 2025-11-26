# main.tf

provider "aws" {
  region = "ap-southeast-1"
}

# Uses the VPC module from the Terraform Registry to create a VPC along with public and private subnets, NAT gateways, and route tables.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"  # Specify the version of the module

  name = "my-vpc"


  cidr = "10.0.0.0/16" # Specifies the CIDR block for the VPC

  azs             = ["ap-southeast-1a"] # Specifies the availability zones in which the subnets will be created
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.2.0/24"]

  enable_nat_gateway = true # Enables the creation of NAT gateways for private subnets
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Explicitly enable auto-assign public IPv4 address on public subnets
  map_public_ip_on_launch = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


# Security Group for the Public Instance
resource "aws_security_group" "public_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
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
    Name = "public-sg"
  }
}

# Security Group for the Private Instance
resource "aws_security_group" "private_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]  # Only allow SSH from the public subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}



# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "main-key"
  public_key = file("~/.ssh/web_key.pub")  # Replace with your own public key
}


# Public EC2 Instance
resource "aws_instance" "public" {
  ami           = "ami-060e277c0d4cce553"  # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "public-instance"
  }

  vpc_security_group_ids  = [aws_security_group.public_sg.id]
}

# Private EC2 Instance
resource "aws_instance" "private" {
  ami           = "ami-060e277c0d4cce553"  # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.private_subnets[0]
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "private-instance"
  }

  vpc_security_group_ids  = [aws_security_group.private_sg.id]
}






