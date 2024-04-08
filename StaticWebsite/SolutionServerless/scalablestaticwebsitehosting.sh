#!/bin/bash

S3_BUCKET_NAME="santhana-static-website-bucket"
TARGET_BUCKET="santhana-static-website-bucket-replica"
DOMAIN_NAME="santhanakrishnan.testsancomcast.com"
ACCOUNT_ID="478361937160"
HOSTED_ZONE_ID="Z0618131PYM8FJWPK4S5"

# Create a private key:
openssl genrsa -out privatekey.pem 2048

# Create a self-signed certificate:
openssl req -new -x509 -key privatekey.pem -out cert.pem -days 365

# Import the certificate into ACM:
aws acm import-certificate --certificate fileb://cert.pem --private-key fileb://privatekey.pem --region us-east-1

# Create S3 bucket
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region us-east-1

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
    "Resource":"arn:aws:s3:::'"$S3_BUCKET_NAME"'/*"
  }]
}')
aws s3api put-bucket-policy --bucket $S3_BUCKET_NAME --policy $POLICY


CLOUDFRONT_DISTRIBUTION_ID=$(aws cloudfront create-distribution \
  --distribution-config '{
    "CallerReference": "'$(date +%Y%m%d%H%M%S)'",
    "Comment": "",
    "DefaultRootObject": "index.html",
    "Origins": {
      "Quantity": 1,
      "Items": [{
        "Id": "S3Origin",
        "DomainName": "testsancomcast.s3.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        }
      }]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "S3Origin",
      "ViewerProtocolPolicy": "redirect-to-https",
      "MinTTL": 0,
      "MaxTTL": 31536000,
      "DefaultTTL": 86400,
      "ForwardedValues": {
        "QueryString": false,
        "Cookies": {
          "Forward": "none"
        }
      }
    },
    "ViewerCertificate": {
      "ACMCertificateArn": "arn:aws:acm:us-east-1:478361937160:certificate/b5cb173d-fd1e-4c90-a9ee-b4feae2b0e5c",
      "SSLSupportMethod": "sni-only"
    },
    "Enabled": true
  }' \
  --query 'Distribution.Id' \
  --output text)

# Update Route 53 record
 aws route53 change-resource-record-sets \
  --hosted-zone-id "Z0618131PYM8FJWPK4S5" \
  --change-batch "{
    \"Changes\": [
      {
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"staticwebsite.testsancomcast.com\",
          \"Type\": \"CNAME\",
          \"ResourceRecords\": [
            {
              \"Value\": \"d2dzh1dhjb2hkl.cloudfront.net\"
            }
          ],
          \"TTL\": 300
        }
      }
    ]
  }"

# Validate setup
sleep 60  # Wait for DNS propagation
curl -I "https://$DOMAIN_NAME"  # Check if HTTPS works
curl -I "http://$DOMAIN_NAME"   # Verify HTTP redirects to HTTPS
