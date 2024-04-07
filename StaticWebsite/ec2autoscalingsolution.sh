#!/bin/bash

# Variables
REGION="us-east-1"
SECURITY_GROUP_NAME="secure-web-sg"
KEY_NAME="myKeyPair"
IMAGE_ID="ami-0abcd1234efgh5678" 
VPC_ID="vpc-0ffaf925bb1d6ab56" 
SUBNET1_ID="subnet-0c7aee4ed4f354a9d" 
SUBNET2_ID="subnet-0b0260246131bf0d7" 

# Create Security Group
aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --description "Security Group for web server" --vpc-id $VPC_ID --region $REGION

# Add rules to Security Group
aws ec2 authorize-security-group-ingress --group-name $SECURITY_GROUP_NAME --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION
aws ec2 authorize-security-group-ingress --group-name $SECURITY_GROUP_NAME --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION

# Create Key Pair
aws ec2 create-key-pair --key-name $KEY_NAME --query 'KeyMaterial' --output text &gt; $KEY_NAME.pem

# Create Launch Configuration
aws autoscaling create-launch-configuration --launch-configuration-name my-lc --image-id $IMAGE_ID --security-groups $SECURITY_GROUP_NAME --key-name $KEY_NAME --instance-type t2.micro --user-data <file://userdata.sh> --region $REGION

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group --auto-scaling-group-name my-asg --launch-configuration-name my-lc --min-size 1 --max-size 3 --desired-capacity 2 --vpc-zone-identifier $SUBNET1_ID,$SUBNET2_ID --region $REGION

# Create Load Balancer
LOAD_BALANCER_ARN=$(aws elbv2 create-load-balancer --name my-load-balancer --subnets $SUBNET1_ID $SUBNET2_ID --security-groups $SECURITY_GROUP_NAME --region $REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text)

# Create HTTP listener that redirects to HTTPS
aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN --protocol HTTP --port 80 --default-actions Type=redirect,TargetGroupArn=$LOAD_BALANCER_ARN,Order=1,RedirectConfig.Protocol=HTTPS,RedirectConfig.Port=443,RedirectConfig.StatusCode=HTTP_301 --region $REGION

# Create HTTPS listener
# This requires an existing SSL certificate in AWS Certificate Manager
CERTIFICATE_ARN="arn:aws:acm:region:account:certificate/certificate-id" # Replace with your certificate ARN
aws elbv2 create-listener --load-balancer-arn $LOAD_BALANCER_ARN --protocol HTTPS --port 443 --certificates CertificateArn=$CERTIFICATE_ARN --default-actions Type=forward,TargetGroupArn=$LOAD_BALANCER_ARN --region $REGION

# Register ASG with Load Balancer
aws autoscaling attach-load-balancers-v2 --auto-scaling-group-name my-asg --target-group-arns $LOAD_BALANCER_ARN --region $REGION
