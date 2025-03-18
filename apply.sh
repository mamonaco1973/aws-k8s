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

# Wait until available

# Function to get the ALB DNS name from Kubernetes Ingress
get_alb_name() {
  kubectl get ingress flask-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
}

# Wait for Ingress to be assigned a hostname
echo "Waiting for Kubernetes Ingress to get an external hostname..."
while true; do
  ALB_NAME=$(get_alb_name)

  if [ -n "$ALB_NAME" ]; then
    echo "Ingress is ready! ALB detected: $ALB_NAME"
    break
  fi

  echo "Ingress not ready yet. Waiting 30 seconds..."
  sleep 30
done

# Wait for ALB to return HTTP 200 on /gtg
echo "Waiting for ALB ($ALB_NAME) to return HTTP 200 on /gtg ..."

while true; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_NAME/gtg")

  if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "ALB is ready! HTTP 200 received from http://$ALB_NAME/gtg"
    break
  fi

  echo "Waiting... ALB returned $HTTP_STATUS. Retrying in 30 seconds..."
  sleep 30
done

echo "Application is fully up and running!"

# Execute the validation script

#./validate.sh


