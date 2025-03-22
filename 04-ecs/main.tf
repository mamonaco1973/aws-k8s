# Configure the AWS provider block
# This section configures the AWS provider, allowing Terraform to manage AWS resources in the specified region.
provider "aws" {
  region = "us-east-2" # Set AWS region to US East (Ohio). Change as necessary.
}

# Fetch information about the current AWS account
# This is a data source used to retrieve the AWS account ID, ARN, and user information.
data "aws_caller_identity" "current" {}

# IAM Role for ECS Task Execution
# ECS tasks use this role to pull container images and write logs to CloudWatch.
resource "aws_iam_role" "ecs_task_execution" {
  name = "ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

# IAM Policy for ECS Task Execution
# This policy grants permissions for ECS tasks to interact with ECR and CloudWatch Logs.
resource "aws_iam_policy" "ecs_task_execution_policy" {
  name = "ecs-task-execution-policy"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:*",
            "logs:*"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

# IAM Role for ECS Task
# This role allows ECS tasks to perform actions based on their application needs.
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      }
    }
  ]
}
EOF
}

# IAM Policy for DynamoDB Access
# Grants ECS tasks access to specific DynamoDB actions such as querying, scanning, and writing data.
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "ecs_task_dynamodb_policy"
  description = "Policy for ECS task to access DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["dynamodb:Query", "dynamodb:PutItem", "dynamodb:Scan"],
        Effect   = "Allow",
        Resource = "${data.aws_dynamodb_table.candidate-table.arn}" # Reference the table's ARN
      }
    ]
  })
}

# Attach DynamoDB Policy to ECS Task Role
# Links the DynamoDB access policy to the ECS Task Role.
resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# Attach ECS Task Execution Policy to the Execution Role
# This enables ECS tasks to use the policy for pulling container images and writing logs.
resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

# Application Load Balancer for ECS
# The ALB routes incoming HTTP requests to ECS services and ensures high availability.
resource "aws_lb" "ecs_lb" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg_http.id]
  subnets            = [data.aws_subnet.k8s-subnet-1.id, data.aws_subnet.k8s-subnet-2.id]
}

# Target Group for ECS Load Balancer
# This target group defines the backend ECS service endpoints and performs health checks.
resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.k8s-vpc.id

  target_type = "ip"

  health_check {
    path                 = "/gtg"
    interval             = 10
    timeout              = 5
    healthy_threshold    = 3
    unhealthy_threshold  = 2
    matcher              = "200,300-310"
  }
}

# Listener for ECS Load Balancer
# The listener forwards traffic to the target group defined above.
resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_lb.ecs_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# IAM Role for ECS EC2 Instances
# This role allows EC2 instances in the ECS cluster to perform tasks like pulling container images.
resource "aws_iam_role" "ecs_ec2_role" {
  name = "ecs_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach AmazonEC2ContainerServiceforEC2Role managed policy to ECS EC2 Role
resource "aws_iam_role_policy_attachment" "ecs_ec2_role_attach" {
  role       = aws_iam_role.ecs_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Attach the AmazonSSMManagedInstanceCore policy for SSM access
resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.ecs_ec2_role.name  # IAM Role to attach the policy
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # SSM Managed Policy ARN
}


# Define Instance Profile for ECS EC2 Instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_ec2_role.name
}

# Launch Template for ECS
# Configures EC2 instances used in the ECS cluster, including IAM instance profile and networking.
resource "aws_launch_template" "ecs_lt" {
  name          = "ecs-launch-template"
  image_id      = "ami-0e3b2096ff08f7b38"
  instance_type = "t2.small"
  user_data     = base64encode("#!/bin/bash\necho ECS_CLUSTER=ecs-cluster >> /etc/ecs/ecs.config")

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
    }
  }
  # Define tags for instances launched from this template
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "eks-worker-node-flask-api"
    }
  }
  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true

    security_groups = [
      aws_security_group.ecs_sg_flask.id,
      aws_security_group.ecs_sg_https.id
    ]
  }
}

# ECS Auto Scaling Group
# Manages the scaling of EC2 instances in the ECS cluster.
resource "aws_autoscaling_group" "ecs_asg" {
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  min_size            = 1
  max_size            = 4
  desired_capacity    = 1
  vpc_zone_identifier = [data.aws_subnet.k8s-subnet-1.id, data.aws_subnet.k8s-subnet-2.id]

  name = "ecs-cluster-asg"

  tag {
    key                 = "Name"
    value               = "ecs-asg-instance"
    propagate_at_launch = true
  }
}

# ECS Cluster Definition
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "flask-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  cpu    = "256"
  memory = "256"

  container_definitions = jsonencode([
    {
      name      = "flask-container",
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-2.amazonaws.com/flask-app:flask-app-rc1",
      cpu       = 256,
      memory    = 256,
      essential = true,
      portMappings = [
        {
          containerPort = 8000,
          hostPort      = 8000
        }
      ]
    }
  ])
}

# ECS Service
# Deploys and manages the ECS tasks defined above.
resource "aws_ecs_service" "ecs_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets         = [data.aws_subnet.k8s-subnet-1.id, data.aws_subnet.k8s-subnet-2.id]
    security_groups = [aws_security_group.ecs_sg_flask.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "flask-container"
    container_port   = 8000
  }
}