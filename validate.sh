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

# Configuration
TARGET_GROUP_NAME="ecs-tg"
MAX_WAIT_TIME=300 # 5 minutes in seconds
INTERVAL=10       # Check every 10 seconds

# Fetch the Target Group ARN
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --names "$TARGET_GROUP_NAME" --query 'TargetGroups[0].TargetGroupArn' --output text 2> /dev/null)

if [ -z "$TARGET_GROUP_ARN" ]; then
    echo "NOTE: ECS Solution is not deployed so skipping ECS validation."
    exit 0
fi

# Start checking for healthy targets
START_TIME=$(date +%s)

echo "NOTE: Testing the ECS Solution."

while true; do
    # Check for healthy targets
    HEALTHY_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$TARGET_GROUP_ARN" \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].Target.Id' --output text)

    if [ -n "$HEALTHY_TARGETS" ]; then
	echo "NOTE: Healthy targets found on $TARGET_GROUP_NAME."
        cd ./02-docker # Navigate to the test scripts directory.
        echo "NOTE: Testing the ECS Solution."

        dns_name=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName=='ecs-alb'].DNSName" --output text) 
	echo "NOTE: URL for ECS Solution is http://$dns_name/gtg?details=true"

        ./test_candidates.py $dns_name

        cd ..

        exit 0
    fi

    # Check if the maximum wait time has been exceeded
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))

    if [ "$ELAPSED_TIME" -ge "$MAX_WAIT_TIME" ]; then
        echo "ERROR: No healthy targets found within $MAX_WAIT_TIME seconds."
        exit 1
    fi

    # Wait for the interval before checking again
    sleep "$INTERVAL"
done
