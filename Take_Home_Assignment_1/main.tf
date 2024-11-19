data "aws_caller_identity" "current" {}

# Define the Network Load Balancer
resource "aws_lb" "nginx_alb" {
  name               = "nginx-alb"
  internal           = false                           # Internet-facing ALB
  load_balancer_type = "application"
  subnets           = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]
  security_groups    = [aws_security_group.alb_sg.id]  # Reference the ALB's security group
}


# Target Group for ALB
resource "aws_lb_target_group" "nginx" {
  name        = "nginx-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.custom_vpc.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
    protocol            = "HTTP"
  }

  tags = {
    Name = "nginx-tg"
  }
}

# Register EC2 instance with the target group
resource "aws_lb_target_group_attachment" "nginx" {
  target_group_arn = aws_lb_target_group.nginx.arn
  target_id        = aws_instance.nginx_server.id
  port             = 80                    # Port to route traffic
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

# Create a security group for ALB if it doesn't exist
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg-"
  description = "Allow HTTP access to ALB"
  vpc_id      = aws_vpc.custom_vpc.id

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

  tags = {
    Name = "alb-sg"
  }
}

# Allow traffic from ALB on port 80
resource "aws_security_group" "nginx_sg" {
  name_prefix = "nginx-sg"
  description = "Security group for Nginx instance"
  vpc_id      = aws_vpc.custom_vpc.id

  ingress {
    description = "Allow HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups  = [aws_security_group.alb_sg.id] # Reference ALB SG to make sure that it has access to EC2
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create IAM Role for SSM Access
resource "aws_iam_role" "ssm_role" {
  name               = "nginx-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach SSM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create Instance Profile for IAM Role
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "nginx-ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Create EC2 Instance
resource "aws_instance" "nginx_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private_subnet.id
  associate_public_ip_address = false # Don't assign public IP. Instance will be sitting in the private subnet and accessed thru ALB only

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name
  vpc_security_group_ids = [aws_security_group.nginx_sg.id]

  user_data = <<-EOF
              #!/bin/bash -xe
              # Update package repository
              apt-get update -y

              # Install Nginx
              apt-get install -y nginx
              service nginx start  # Use `service` instead of `systemctl`
              EOF

  tags = {
    Name = "nginx-server"
  }
}

