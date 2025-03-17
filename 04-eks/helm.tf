provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.flask_eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.flask_eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.flask_eks.token
  }
}

data "aws_eks_cluster_auth" "flask_eks" {
  name = aws_eks_cluster.flask_eks.name
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.flask_eks.name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa.iam_role_arn
  }
}
