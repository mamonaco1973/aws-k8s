# EC2 INSTANCE CONFIGURATION
# This resource block defines an AWS EC2 instance named "kubectl_instance".

resource "aws_instance" "kubectl_instance" {
  
  ami = data.aws_ami.ubuntu_ami.id

  instance_type = "t2.micro"
  subnet_id = aws_subnet.k8s-subnet-1.id

  vpc_security_group_ids = [
    aws_security_group.ad_ssm_sg.id
  ]

  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.eks_kubectl_instance_profile.name

  user_data = file("./scripts/userdata.sh")

  tags = {
    Name = "kubectl-instance"  # The EC2 instance name in AWS.
  }
}

resource "aws_iam_instance_profile" "eks_kubectl_instance_profile" {
  name = "eks-kubectl-instance-profile"
  role = aws_iam_role.eks_node_role.name
}
