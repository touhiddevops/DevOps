provider "aws" {
  region = var.region
}

############### Code block for vpc and subnet #################

resource "aws_vpc" "main_vpc" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnet_cidrs[0]
  availability_zone = var.availability_zones[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.public_subnet_cidrs[1]
  availability_zone = var.availability_zones[1]
  map_public_ip_on_launch = true
}

############# IGW and Route table ################

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_route_table" "main_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.main_rt.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.main_rt.id
}

################# Create security groups for the ALB and the instances ######################

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


################# Add the public key to Terraform ##################

resource "aws_key_pair" "web_key" {
  key_name   = "web_key"
  public_key = file("~/.ssh/web_key.pub")
}


################ Define a launch template with user data to install Apache2 #################

resource "aws_launch_template" "main_lt" {
  name_prefix   = "autoscaling-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.web_key.key_name

  network_interfaces {
    security_groups = [aws_security_group.instance_sg.id]
    associate_public_ip_address = true
  }

   user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
    apt-get update -y
    apt-get install git -y
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
    . /.nvm/nvm.sh
    nvm install --lts
    mkdir -p /demo-website
    cd /demo-website
    git clone https://github.com/imnulhaqueruman/simple-express-server.git .
    cd simple-express-server
    npm install
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 3000
    npm install pm2@latest -g
    pm2 start app.js
  EOF
  )
}

#################### Create a target group and Application Load Balancer #####################

resource "aws_lb_target_group" "main_tg" {
  name     = "autoscaling-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "main_alb" {
  name               = "autoscaling-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}

############## Set up the Auto Scaling Group to manage instance scaling #####################

resource "aws_autoscaling_group" "main_asg" {
  desired_capacity     = var.desired_capacity
  max_size             = var.max_size
  min_size             = var.min_size
  vpc_zone_identifier  = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  target_group_arns    = [aws_lb_target_group.main_tg.arn]
  launch_template {
    id      = aws_launch_template.main_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "autoscaling-instance"
    propagate_at_launch = true
  }
}


