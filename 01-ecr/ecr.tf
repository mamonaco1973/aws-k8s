# AWS Elastic Container Registry (ECR) for storing Docker container images
# Stores flask_app containers

resource "aws_ecr_repository" "flask_app" {
  name                 = "flask-app"              # ECR repository name
  image_tag_mutability = "MUTABLE"                # Allow overwriting of image tags

  # Enable automatic image scanning for vulnerabilities
  image_scanning_configuration {
    scan_on_push = true                           # Scan images on push
  }
}

# AWS Elastic Container Registry (ECR) for storing Docker container images
# Stores tic-tac-toe container

resource "aws_ecr_repository" "games" {
  name                 = "games"                  # ECR repository name
  image_tag_mutability = "MUTABLE"                # Allow overwriting of image tags

  # Enable automatic image scanning for vulnerabilities
  image_scanning_configuration {
    scan_on_push = true                           # Scan images on push
  }
}

