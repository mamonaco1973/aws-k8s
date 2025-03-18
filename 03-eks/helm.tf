# Configure the Helm provider for deploying Kubernetes applications

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.flask_eks.endpoint         # Use the EKS cluster API endpoint for communication
    cluster_ca_certificate = base64decode(aws_eks_cluster.flask_eks.certificate_authority[0].data)  
                                                                        # Decode and use the cluster's CA certificate
    token                  = data.aws_eks_cluster_auth.flask_eks.token  # Retrieve the authentication token for the EKS cluster
  }
}

# Fetch authentication credentials for the EKS cluster

data "aws_eks_cluster_auth" "flask_eks" {
  name = aws_eks_cluster.flask_eks.name  # Use the EKS cluster name to retrieve authentication details
}

# Deploy AWS Load Balancer Controller using Helm
# This controller integrates with AWS ALB and NLB to manage Kubernetes services

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"      # Define the Helm release name
  repository = "https://aws.github.io/eks-charts"  # Specify the Helm chart repository URL
  chart      = "aws-load-balancer-controller"      # Define the Helm chart name to be installed
  namespace  = "kube-system"                       # Deploy the controller in the "kube-system" namespace for cluster-wide use

  # Set the EKS cluster name in the Helm values

  set {
    name  = "clusterName"
    value = aws_eks_cluster.flask_eks.name         # Pass the cluster name as a Helm chart parameter
  }

  # Configure the service account name for the controller
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"         # Use a dedicated service account for ALB controller
  }

  # Annotate the service account with the IAM role ARN for AWS permissions
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa.iam_role_arn  # Attach IAM role for ALB controller to assume necessary permissions
  }

}
