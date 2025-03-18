#!/bin/bash

# Get all security groups with names starting with "eks-cluster"
SECURITY_GROUPS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=eks-cluster*" --query "SecurityGroups[*].GroupId" --output text)

if [ -z "$SECURITY_GROUPS" ]; then
    echo "No security groups found with name starting 'eks-cluster'."
    exit 0
fi

echo "Found security groups: $SECURITY_GROUPS"

# Loop through each security group and find associated network interfaces
for SG in $SECURITY_GROUPS; do
    echo "Processing security group: $SG"

    # Get network interfaces attached to this security group
    NETWORK_INTERFACES=$(aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG" --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)

    if [ -z "$NETWORK_INTERFACES" ]; then
        echo "No network interfaces found for security group $SG"
        continue
    fi

    echo "Detaching and deleting network interfaces: $NETWORK_INTERFACES"

    # Loop through each network interface and detach + delete it
    for ENI in $NETWORK_INTERFACES; do
        echo "Detaching and deleting ENI: $ENI"
        
        # Get attachment ID (if any)
        ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --network-interface-ids $ENI --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text)
        
        if [ "$ATTACHMENT_ID" != "None" ]; then
            echo "Detaching ENI: $ENI (Attachment ID: $ATTACHMENT_ID)"
            aws ec2 detach-network-interface --attachment-id $ATTACHMENT_ID --force
            sleep 5  # Wait for detachment to complete
        fi

        # Delete the network interface
        echo "Deleting ENI: $ENI"
        aws ec2 delete-network-interface --network-interface-id $ENI
    done
done

echo "All network interfaces detached and deleted for security groups matching 'eks-cluster*'."
