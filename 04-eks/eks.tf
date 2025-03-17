# Create EKS Cluster
resource "aws_eks_cluster" "flask_eks" {
  name     = "flask-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.k8s-subnet-1.id, aws_subnet.k8s-subnet-2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Create EKS Node Group
resource "aws_eks_node_group" "flask_api" {
  cluster_name    = aws_eks_cluster.flask_eks.name
  node_group_name = "flask-api"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.k8s-subnet-1.id, aws_subnet.k8s-subnet-2.id]
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
    aws_iam_role_policy_attachment.ssm_policy
  ]
}

# Create IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "alb_controller" {
  name = "eks-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_eks_cluster.flask_eks.identity[0].oidc[0].issuer
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${aws_eks_cluster.flask_eks.identity[0].oidc[0].issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# Attach ALB Controller Policy
resource "aws_iam_role_policy_attachment" "alb_controller_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerController"
  role       = aws_iam_role.alb_controller.name
}

# Create Kubernetes Service Account for ALB Controller
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }
}

# Deploy AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.4"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.flask_eks.name
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }

  set {
    name  = "region"
    value = "us-east-2"
  }

  set {
    name  = "vpcId"
    value = aws_vpc.k8s-vpc.id
  }

  depends_on = [kubernetes_service_account.alb_controller]
}