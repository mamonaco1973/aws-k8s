#!/bin/bash

# This script automates the process of updating the OS, installing required packages,
# joining an Active Directory (AD) domain, configuring system settings, and cleaning
# up permissions.

# ---------------------------------------------------------------------------------
# Section 1: Update the OS and Install Required Packages
# ---------------------------------------------------------------------------------

apt-get update -y
apt-get install unzip nano vim -y

# ---------------------------------------------------------------------------------
# Section 2: Install AWS CLI
# ---------------------------------------------------------------------------------

# Change to the /tmp directory to download and install the AWS CLI.
cd /tmp

# Download the AWS CLI installation package.
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "awscliv2.zip"

# Unzip the downloaded package.
unzip awscliv2.zip

# Install the AWS CLI using the installation script.
sudo ./aws/install

# Clean up by removing the downloaded zip file and extracted files.
rm -f -r awscliv2.zip aws

# ---------------------------------------------------------------------------------
# Section 3: Install kubectl
# ---------------------------------------------------------------------------------

cd /usr/bin
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
chmod +x kubectl 

# ---------------------------------------------------------------------------------
# Section 4: Install eksctl
# ---------------------------------------------------------------------------------

cd /tmp
curl -LO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz
sudo mv eksctl /usr/bin/
