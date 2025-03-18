#!/bin/bash

./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi


# Navigate to the 01-ecr directory
cd "01-ecr" 
echo "NOTE: Building ECR Instance."

if [ ! -d ".terraform" ]; then
    terraform init
fi
terraform apply -auto-approve

# Return to the parent directory
cd ..

# Navigate to the 02-docker directory

cd "02-docker"
echo "NOTE: Building flask container with Docker."

# Retrieve the AWS Account ID using the AWS CLI.
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Authenticate Docker to AWS ECR using the retrieved credentials.
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com

# Build and push the Docker image.
# The image tag includes the AWS Account ID and the specified repository and tag.

docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-2.amazonaws.com/flask-app:flask-app-rc1 . --push

cd ..

# Navigate to the 03-apprunner directory
cd 04-eks
echo "NOTE: Building EKS instance and deploy flask container."

if [ ! -d ".terraform" ]; then
    terraform init
fi

terraform apply -auto-approve
sed "s/\${account_id}/$AWS_ACCOUNT_ID/g" flask-app.yaml.tmpl > ../flask-app.yaml

# Return to the parent directory
cd ..

# Configure kubectl command

aws eks update-kubeconfig --name flask-eks-cluster --region us-east-2

# Deploy flask container with kubectl

kubectl apply -f flask-app.yaml

./validate.sh


