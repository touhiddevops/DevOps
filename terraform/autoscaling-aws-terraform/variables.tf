variable "region" {
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "key_name" {
  default = "mykey"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_id" {
  default = "ami-060e277c0d4cce553"  # Ubuntu AMI
}

variable "desired_capacity" {
  default = 1
}

variable "max_size" {
  default = 4
}

variable "min_size" {
  default = 1
}

