
resource "aws_iam_policy" "dynamodb_access" {
  name        = "DynamoDBAccessPolicy"
  description = "Policy to allow access to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [                               # List of DynamoDB actions allowed
          "dynamodb:Query",                      # Allow querying items in the DynamoDB table
          "dynamodb:PutItem",                    # Allow inserting new items into the table
          "dynamodb:Scan"                        # Allow scanning the entire table
        ],
        Effect   = "Allow",                      # Grant the specified actions
        Resource = "${aws_dynamodb_table.candidate-table.arn}" # Reference the ARN of the target DynamoDB table
      }
    ]
  })
}

# Create IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Policies to Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Create IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach Policies to Node Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Configure the Kubernetes provider
provider "kubernetes" {
  host                   = aws_eks_cluster.flask_eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.flask_eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.flask_eks.token
}


# Create the Kubernetes service account
resource "kubernetes_service_account" "dynamodb_access_sa" {
  metadata {
    name      = "dynamodb-access-sa"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.dynamodb_access_irsa.iam_role_arn
    }
  }
}
