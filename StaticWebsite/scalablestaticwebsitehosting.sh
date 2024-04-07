#!/bin/bash

S3_BUCKET_NAME="santhana-comcast-test-static-website-bucket"
TARGET_BUCKET="santhana-comcast-test-static-website-bucket-replica"
DOMAIN_NAME="santhanakrishnan.com"
ACCOUNT_ID="<accountid>"
HOSTED_ZONE_ID="<HostedZoneIDHash>"

# Create S3 bucket
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region us-east-1 

# Enable versioning on the bucket
aws s3api put-bucket-versioning --bucket "$S3_BUCKET_NAME" --versioning-configuration Status=Enabled

# Create second S3 bucket for replication
aws s3api create-bucket --bucket "$TARGET_BUCKET" --region us-west-2 

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

# Create Origin Access Identity
OAI_ID=$(aws cloudfront create-cloud-front-origin-access-identity \
  --cloud-front-origin-access-identity-config CallerReference=string,Comment=string \
  --query 'CloudFrontOriginAccessIdentity.Id' \
  --output text)

# Update S3 bucket policy to restrict access to OAI
POLICY=$(echo -n '{
  "Version":"2012-10-17",
  "Statement":[{
    "Sid":"1",
    "Effect":"Allow",
    "Principal":{"AWS":"arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity '"$OAI_ID"'"},
    "Action":"s3:GetObject",
    "Resource":"arn:aws:s3:::'$S3_BUCKET_NAME'/*"
  }]
}' | base64)
aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy $POLICY


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
