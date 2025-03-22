# =============================================
# IAM Policy: Allow Access to DynamoDB
# =============================================
resource "aws_iam_policy" "dynamodb_access" {
  name        = "DynamoDBAccessPolicy"  # Name of the IAM policy
  description = "Policy to allow access to DynamoDB"  # Description of what this policy does

  policy = jsonencode({
    Version = "2012-10-17"  # IAM policy version format
    Statement = [
      {
        Action = [                               # List of actions permitted on DynamoDB
          "dynamodb:Query",                      # Allows querying items based on keys and indexes
          "dynamodb:PutItem",                    # Allows inserting new records into the table
          "dynamodb:Scan"                        # Allows scanning the entire table (expensive operation)
        ],
        Effect   = "Allow",                      # Grant these permissions
        Resource = "${aws_dynamodb_table.candidate-table.arn}" # Restrict access to the specific DynamoDB table
      }
    ]
  })
}

# =============================================
# IAM Role: EKS Cluster Role
# =============================================
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"  # Name of the IAM role for EKS Cluster

  assume_role_policy = jsonencode({
    Version = "2012-10-17"  # IAM policy version
    Statement = [{
      Effect = "Allow"  # Allows AWS services to assume this role
      Principal = {
        Service = "eks.amazonaws.com"  # Grants permission to EKS service
      }
      Action = "sts:AssumeRole"  # Allows the role to be assumed
    }]
  })
}

# ================================================
# Attach Managed AWS Policies to EKS Cluster Role
# ================================================
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name  # Attach policy to EKS cluster IAM role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"  # Predefined AWS policy for EKS clusters
}

# =============================================
# IAM Role: EKS Node Group Role
# =============================================
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"  # Name of IAM role for EKS worker nodes

  assume_role_policy = jsonencode({
    Version = "2012-10-17"  # IAM policy version
    Statement = [{
      Effect = "Allow"  # Allow role assumption
      Principal = {
        Service = "ec2.amazonaws.com"  # Grants permission to EC2 instances (worker nodes)
      }
      Action = "sts:AssumeRole"  # Allows the role to be assumed
    }]
  })
}

# =============================================
# Attach AWS Managed Policies to EKS Node Role
# =============================================
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name                      # Attach policy to EKS worker node IAM role
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"  # Grants permissions required by worker nodes
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name                 # Attach CNI policy for networking
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"  # Allows EKS to manage network interfaces
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node_role.name                               # Attach policy to enable ECR access
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # Grants read-only access to ECR
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.eks_node_role.name                         # Attach policy for SSM agent on EC2 instances
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"  # Allows EC2 instances to use AWS Systems Manager
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "EKSClusterAutoscalerPolicy"
  description = "Permissions for EKS Cluster Autoscaler to manage ASGs"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "cluster_autoscaler" {
  name = "EKSClusterAutoscalerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
          }
        }
      }
    ]
  })
}

