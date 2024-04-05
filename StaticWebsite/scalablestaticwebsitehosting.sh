#!/bin/bash

# Variables
S3_BUCKET_NAME="santhana-static-website-bucket"
DOMAIN_NAME="santhanakrishnan.com"
ACCOUNT_ID="<accountid>"
HOSTED_ZONE_ID="<HostedZoneIDHash>"

# Create S3 bucket
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region us-east-1 --create-bucket-configuration LocationConstraint=us-east-1

# Upload HTML file
aws s3 cp index.html "s3://$S3_BUCKET_NAME/"

# Create CloudFront distribution
CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront create-distribution \
  --origin-domain-name "${S3_BUCKET_NAME}.s3.amazonaws.com" \
  --default-root-object "index.html" \
  --viewer-certificate "ACMCertificateArn=arn:aws:acm:us-east-1:${ACCOUNT_ID}:certificate/<certificate-hash>" \
  --default-cache-behavior '{
    "TargetOriginId": "${S3_BUCKET_NAME}.s3.amazonaws.com",
    "ViewerProtocolPolicy": "redirect-to-https",
    "MinTTL": 0,
    "MaxTTL": 31536000,
    "DefaultTTL": 86400
  }' \
  --query 'Distribution.Id' \
  --output text)

# Update Route 53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$DOMAIN_NAME\",
          \"Type\": \"A\",
          \"AliasTarget\": {
            \"HostedZoneId\": \"$HOSTED_ZONE_ID\",
            \"DNSName\": \"${CLOUDFRONT_DISTRIBUTION_ID}.cloudfront.net\",
            \"EvaluateTargetHealth\": false
          }
        }
      }
    ]
  }"

# Validate setup
sleep 60  # Wait for DNS propagation
curl -I "https://$DOMAIN_NAME"  # Check if HTTPS works
curl -I "http://$DOMAIN_NAME"   # Verify HTTP redirects to HTTPS