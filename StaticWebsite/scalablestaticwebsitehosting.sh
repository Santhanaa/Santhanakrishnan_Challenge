#!/bin/bash

S3_BUCKET_NAME="santhana-static-website-bucket"
TARGET_BUCKET="santhana-static-website-bucket-replica"
DOMAIN_NAME="santhanakrishnan.com"
ACCOUNT_ID="<accountid>"
HOSTED_ZONE_ID="<HostedZoneIDHash>"

# Create S3 bucket
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region us-east-1 --create-bucket-configuration LocationConstraint=us-east-1

# Enable versioning on the bucket
aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" --versioning-configuration Status=Enabled

# Create second S3 bucket for replication
aws s3api create-bucket --bucket "$TARGET_BUCKET" --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2

# Enable versioning on the replication bucket
aws s3api put-bucket-versioning --bucket "$TARGET_BUCKET" --versioning-configuration Status=Enabled

# Create replication configuration file
echo '{
  "Role":"arn:aws:iam::'$ACCOUNT_ID':role/CrossRegionReplicationRole",
  "Rules":[{
    "Status":"Enabled",
    "Priority":1,
    "DeleteMarkerReplication":{"Status":"Enabled"},
    "Filter":{"Prefix":""},
    "Destination":{
      "Bucket":"arn:aws:s3:::'$TARGET_BUCKET'",
      "StorageClass":"STANDARD"
    }
  }]
}' > replication.json

# Enable replication on the bucket
aws s3api put-bucket-replication --bucket "$S3_BUCKET_NAME" --replication-configuration file://replication.json

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
