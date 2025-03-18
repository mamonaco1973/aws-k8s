#!/bin/bash

# Function to retrieve the ALB DNS name from Kubernetes Ingress
get_alb_name() {
  kubectl get ingress flask-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
}

# Wait until Kubernetes Ingress has an assigned hostname
while true; do
  ALB_NAME=$(get_alb_name)
  
  if [ -n "$ALB_NAME" ]; then
    break
  fi

  echo "WARNING: Ingress not ready yet. Waiting 30 seconds..."
  sleep 30
done

# Wait for ALB to return HTTP 200 on /gtg

while true; do
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_NAME/gtg")
  
  if [ "$HTTP_STATUS" -eq 200 ]; then
    break
  fi

  echo "WARNING: Waiting... ALB not ready yet. Retrying in 30 seconds..."
  sleep 30
done

# Navigate to the Docker directory for testing
cd "02-docker" || { echo "ERROR: Failed to change directory to 02-docker"; exit 1; }

# Define the service URL
SERVICE_URL="http://$ALB_NAME"
echo "NOTE: Testing the EKS Solution."
echo "NOTE: URL for EKS Solution is $SERVICE_URL/gtg?details=true"

# Run the test script
./test_candidates.py "$SERVICE_URL" || { echo "ERROR: Application test failed. Exiting."; exit 1; }

cd ..

