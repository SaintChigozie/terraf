terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region_name
}

resource "aws_s3_bucket" "example" {
  bucket = "gozi-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

resource "aws_iam_role_policy" "inline" {
  name = "test_policy"
  role = aws_iam_role.test_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBuckets*",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.example.arn
        ]
      },
      {
        Action = [
          "s3:GetOject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.example.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "tag-value"
  }
}
resource "aws_vpc" "customVPC" {
  cidr_block = var.vpc_cidr
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.customVPC.id

  tags = {
    Name = "customVPC"
  }
}

resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.customVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRT"
  }
}

resource "aws_subnet" "custom_public_sunet1" {
  vpc_id                  = aws_vpc.customVPC.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.az1

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "custom_public_sunet2" {
  vpc_id                  = aws_vpc.customVPC.id
  cidr_block              = var.subnet2_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.az2

  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_route_table_association" "public_subnet_association1" {
  subnet_id      = aws_subnet.custom_public_sunet1.id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_route_table_association" "public_subnet_association2" {
  subnet_id      = aws_subnet.custom_public_sunet2.id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.customVPC.id

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
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.customVPC.id

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
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.customVPC.id

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
}


resource "aws_lb_target_group" "alb-example" {
  name        = "tf-example-lb-alb-tg"
  target_type = "alb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = aws_vpc.customVPC.id
}


resource "aws_lb" "web-alb" {
  name               = "goziapp-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.custom_public_sunet1.id, aws_subnet.custom_public_sunet2.id]
}
# tags = {
#   Environment = "lab"
# }

resource "aws_launch_template" "example_launch_template" {
  name_prefix   = "example-launch-template"
  image_id      = var.ami_id
  instance_type = var.instance_type
}

resource "aws_autoscaling_group" "example_asg" {
  launch_template {
    id      = aws_launch_template.example_launch_template.id
    version = "$Latest"
  }
  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.custom_public_sunet1.id, aws_subnet.custom_public_sunet2.id]
}

resource "aws_instance" "app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.custom_public_sunet1.id

  tags = {
    Name = "Okeke-Terraform"
  }
}


resource "aws_instance" "app_server1" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.custom_public_sunet1.id

  tags = {
    Name = "Okeke-Terraform"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "foo"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}