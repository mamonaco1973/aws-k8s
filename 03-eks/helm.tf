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
  
  values = [
    templatefile("${path.module}/aws-load-balancer.yaml.tmpl", {
      cluster_name = aws_eks_cluster.flask_eks.name
      role_arn     = module.load_balancer_controller_irsa.iam_role_arn
    })
  ]
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.1" # or latest stable version
  values = [
    templatefile("${path.module}/autoscaler.yaml.tmpl", {
      cluster_name = aws_eks_cluster.flask_eks.name
    })
  ]
}
