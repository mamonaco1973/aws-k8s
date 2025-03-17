# # Security Group for SSM (Port 443) - Used for AWS Systems Manager (SSM) agent communication
# resource "aws_security_group" "ad_ssm_sg" {
#   name        = "ad-ssm-security-group"               # Security Group name
#   description = "Allow SSM access from the internet"  # Description of the security group
#   vpc_id      = aws_vpc.k8s-vpc.id                    # Associates the security group with the specified VPC

#   # INGRESS: Defines inbound rules allowing access to port 443 (HTTPS for SSM communication)
#   ingress {
#     description = "Allow SSM from anywhere"           # This rule permits SSM agent communication from all IPs
#     from_port   = 443                                 # Start of port range (HTTPS default port)
#     to_port     = 443                                 # End of port range (same as start for a single port)
#     protocol    = "tcp"                               # Protocol type (TCP for HTTPS)
#     cidr_blocks = ["0.0.0.0/0"]                       # WARNING: Allows traffic from ANY IP address (highly insecure!)
#   }

#   # EGRESS: Allows all outbound traffic (default open rule)
#   egress {
#     from_port   = 0                                   # Start of port range (0 means all ports)
#     to_port     = 0                                   # End of port range (0 means all ports)
#     protocol    = "-1"                                # Protocol (-1 means all protocols)
#     cidr_blocks = ["0.0.0.0/0"]                       # Allows outbound traffic to ANY destination
#   }
# }