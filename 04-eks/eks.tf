# Create EKS Cluster
resource "aws_eks_cluster" "flask_eks" {
  name     = "flask-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.k8s-subnet-1.id, aws_subnet.k8s-subnet-2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_launch_template" "eks_worker_nodes" {
  name = "eks-worker-nodes"

  metadata_options {
    http_endpoint = "enabled"  # Enable the metadata service
    http_tokens   = "required" # Require IMDSv2
  }

  # Optional: Specify instance type, AMI, etc., if needed
  instance_type = "t3.medium"
}

# Create EKS Node Group
resource "aws_eks_node_group" "flask_api" {
  cluster_name    = aws_eks_cluster.flask_eks.name
  node_group_name = "flask-api"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.k8s-subnet-1.id, aws_subnet.k8s-subnet-2.id]
  instance_types  = ["t3.medium"]
  
  # Associate the custom launch template
  launch_template {
    id      = aws_launch_template.eks_worker_nodes.id
    version = aws_launch_template.eks_worker_nodes.latest_version
  }

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

