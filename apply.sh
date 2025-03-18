#!/bin/bash

# Run environment check script
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# Function to initialize Terraform if not already initialized
init_terraform() {
    if [ ! -d ".terraform" ]; then
        terraform init
    fi
}

# Navigate to the ECR setup directory and deploy
cd "01-ecr" || { echo "ERROR: Failed to change directory to 01-ecr"; exit 1; }
echo "NOTE: Building ECR Instance."
init_terraform
terraform apply -auto-approve
cd ..

# Navigate to the Docker setup directory and build the container
cd "02-docker" || { echo "ERROR: Failed to change directory to 02-docker"; exit 1; }
echo "NOTE: Building Flask container with Docker."

# Retrieve AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "ERROR: Failed to retrieve AWS Account ID. Exiting."
    exit 1
fi

# Authenticate Docker to AWS ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com || {
    echo "ERROR: Docker authentication to ECR failed. Exiting."
    exit 1
}

# Build and push the Docker image
IMAGE_TAG="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com/flask-app:flask-app-rc1"
docker build -t $IMAGE_TAG . || { echo "ERROR: Docker build failed. Exiting."; exit 1; }
docker push $IMAGE_TAG || { echo "ERROR: Docker push failed. Exiting."; exit 1; }
cd ..

# Navigate to the EKS setup directory and deploy
cd "03-eks" || { echo "ERROR: Failed to change directory to 03-eks"; exit 1; }
echo "NOTE: Building EKS instance and deploying Flask container."
init_terraform
terraform apply -auto-approve

# Replace placeholder in the Kubernetes deployment template
sed "s/\${account_id}/$AWS_ACCOUNT_ID/g" flask-app.yaml.tmpl > ../flask-app.yaml || {
    echo "ERROR: Failed to generate Kubernetes deployment file. Exiting."
    exit 1
}
cd ..

# Configure kubectl for EKS cluster
aws eks update-kubeconfig --name flask-eks-cluster --region us-east-2 || {
    echo "ERROR: Failed to update kubeconfig for EKS. Exiting."
    exit 1
}

# Deploy Flask container to EKS
kubectl apply -f flask-app.yaml || {
    echo "ERROR: Failed to deploy to EKS. Exiting."
    exit 1
}

echo ""
echo "NOTE: Validating Solutions"

# Run validation script
./validate.sh || {
    echo "ERROR: Validation failed. Exiting."
    exit 1
}

echo "NOTE: Deployment completed successfully."
