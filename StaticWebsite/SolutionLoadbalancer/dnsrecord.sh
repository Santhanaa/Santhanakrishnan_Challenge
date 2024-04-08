#!/bin/bash

# Variables
DOMAIN_NAME="santhanatestcomcast.comcastchallenge.com"
HOSTED_ZONE_ID="$(uuidgen)comcastchallenge.com."  # Replace with your Hosted Zone ID
LOAD_BALANCER_DNS_NAME=$LOAD_BALANCER_ARN   # Replace with your Load Balancer DNS name

# Create Hosted Zone
aws route53 create-hosted-zone --name $DOMAIN_NAME --caller-reference $HOSTED_ZONE_ID

# Create DNS Record
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch '{
    "Comment": "Create record set for Load Balancer",
    "Changes": [
        {
            "Action": "CREATE",
            "ResourceRecordSet": {
                "Name": "'"$DOMAIN_NAME"'",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "'"$HOSTED_ZONE_ID"'",
                    "DNSName": "'"$LOAD_BALANCER_DNS_NAME"'",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}'