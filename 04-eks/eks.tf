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

module "dynamodb_access_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role                   = true
  role_name                     = "dynamodb-access-role"
  provider_url                  = replace(aws_eks_cluster.flask_eks.identity[0].oidc[0].issuer, "https://", "")
  role_policy_arns              = [aws_iam_policy.dynamodb_access.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:default:dynamodb-access-sa"]
}

