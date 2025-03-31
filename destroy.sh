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
terraform destroy -auto-approve || { echo "ERROR: Terraform destroy failed. Exiting."; exit 1; }

# Clean up Terraform-related files
rm -rf terraform* .terraform*
cd ..

# Get list of all security group IDs where the GroupName starts with "k8s"
group_ids=$(aws ec2 describe-security-groups \
  --query "SecurityGroups[?starts_with(GroupName, 'k8s')].GroupId" \
  --output text)

if [ -z "$group_ids" ]; then
  echo "NOTE: No security groups starting with 'k8s' found."
  exit 0
fi

# Loop through each group ID and attempt deletion
for group_id in $group_ids; do
  echo "NOTE: Deleting security group: $group_id"
  aws ec2 delete-security-group --group-id "$group_id"

  if [ $? -eq 0 ]; then
    echo "NOTE: Successfully deleted $group_id"
  else
    echo "WARNING: Failed to delete $group_id — possibly still in use"
  fi
done

echo "NOTE: Deleting ECR repository contents."

# Define ECR repository name
ECR_REPOSITORY_NAME="flask-app"

# Force delete the ECR repository and its contents
aws ecr delete-repository --repository-name "$ECR_REPOSITORY_NAME" --force || {
    echo "WARNING: Failed to delete ECR repository. It may not exist."
}

# Force delete the ECR games repository and its contents
aws ecr delete-repository --repository-name "games" --force || {
    echo "WARNING: Failed to delete ECR repository. It may not exist."
}


# Navigate to the ECR setup directory and clean up Terraform files
cd "01-ecr" || { echo "ERROR: Failed to change directory to 01-ecr. Exiting."; exit 1; }
terraform destroy -auto-approve || { echo "ERROR: Terraform destroy failed. Exiting."; exit 1; }
rm -rf terraform* .terraform*
cd ..

echo "NOTE: Cleanup process completed successfully."
