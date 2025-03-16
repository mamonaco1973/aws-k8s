# # IAM Role for App Runner to run the service
# resource "aws_iam_role" "app_runner_run_role" {
#   name               = "app-runner-run-role" # Name of the IAM Role
#   assume_role_policy = jsonencode({          # Assume role policy document in JSON format
#     Version = "2012-10-17",                  # Policy version
#     Statement = [
#       {
#         Effect = "Allow",                    # Allow App Runner to assume this role
#         Principal = {
#           Service = "tasks.apprunner.amazonaws.com" # Service principal for App Runner tasks
#         },
#         Action = "sts:AssumeRole"           # Action to allow assuming this role
#       }
#     ]
#   })
# }

# # IAM Role Policy for App Runner to interact with DynamoDB
# resource "aws_iam_role_policy" "app_runner_policy" {
#   name   = "app-runner-policy"                   # Name of the IAM policy
#   role   = aws_iam_role.app_runner_run_role.id   # Attach the policy to the previously created IAM role
#   policy = jsonencode({                          # Inline policy document in JSON format
#     Version = "2012-10-17",                      # Policy version
#     Statement = [
#       {
#         Action = [                               # List of DynamoDB actions allowed
#           "dynamodb:Query",                      # Allow querying items in the DynamoDB table
#           "dynamodb:PutItem",                    # Allow inserting new items into the table
#           "dynamodb:Scan"                        # Allow scanning the entire table
#         ],
#         Effect   = "Allow",                      # Grant the specified actions
#         Resource = "${aws_dynamodb_table.candidate-table.arn}" # Reference the ARN of the target DynamoDB table
#       }
#     ]
#   })
# }

# # IAM Role for App Runner to build the service
# resource "aws_iam_role" "app_runner_build_role" {
#   name               = "app-runner-build-role" # Name of the IAM Role
#   assume_role_policy = jsonencode({            # Assume role policy document in JSON format
#     Version = "2012-10-17",                    # Policy version
#     Statement = [
#       {
#         Effect = "Allow",                      # Allow App Runner to assume this role for builds
#         Principal = {
#           Service = "build.apprunner.amazonaws.com" # Service principal for App Runner builds
#         },
#         Action = "sts:AssumeRole"             # Action to allow assuming this role
#       }
#     ]
#   })
# }

# # IAM Policy Attachment for ECR access
# resource "aws_iam_role_policy_attachment" "attach_ecr_policy" {
#   role       = aws_iam_role.app_runner_build_role.name # Attach the policy to the App Runner build role
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess" # AWS-managed policy for ECR access
# }

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
