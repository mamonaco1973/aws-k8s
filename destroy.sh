#!/bin/bash

# Delete Kubernetes deployment
kubectl delete -f stress.yaml > /dev/null 2> /dev/null
kubectl delete -f flask-app.yaml || {
    echo "WARNING: Failed to delete Kubernetes deployment. It may not exist."
}

helm uninstall nginx-ingress -n ingress-nginx

# Navigate to the EKS setup directory and destroy resources
cd "03-eks" || { echo "ERROR: Failed to change directory to 04-eks. Exiting."; exit 1; }
echo "NOTE: Destroying EKS cluster."

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init
fi

# Destroy EKS resources
#terraform destroy -auto-approve -target=aws_eks_node_group.flask_api -target=aws_eks_cluster.flask_eks -target=helm_release.aws_load_balancer_controller
terraform destroy -auto-approve || { echo "ERROR: Terraform destroy failed. Exiting."; exit 1; }

# Clean up Terraform-related files
rm -rf terraform* .terraform*
cd ..

echo "NOTE: Deleting ECR repository contents."

# Define ECR repository name
ECR_REPOSITORY_NAME="flask-app"

# Force delete the ECR repository and its contents
aws ecr delete-repository --repository-name "$ECR_REPOSITORY_NAME" --force || {
    echo "WARNING: Failed to delete ECR repository. It may not exist."
}

# Navigate to the ECR setup directory and clean up Terraform files
cd "01-ecr" || { echo "ERROR: Failed to change directory to 01-ecr. Exiting."; exit 1; }
terraform destroy -auto-approve || { echo "ERROR: Terraform destroy failed. Exiting."; exit 1; }
rm -rf terraform* .terraform*
cd ..

echo "NOTE: Cleanup process completed successfully."
