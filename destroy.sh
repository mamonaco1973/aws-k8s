
kubectl delete -f flask-app.yaml

cd "04-eks"

echo "NOTE: Destroying EKS."

if [ ! -d ".terraform" ]; then
    terraform init
fi
terraform destroy -auto-approve
rm -f -r terraform* .terraform*

cd ..

echo "NOTE: Deleting ECR repository contents."

ECR_REPOSITORY_NAME="flask-app"
aws ecr delete-repository --repository-name $ECR_REPOSITORY_NAME --force

cd 01-ecr
rm -f -r terraform* .terraform*
cd ..




