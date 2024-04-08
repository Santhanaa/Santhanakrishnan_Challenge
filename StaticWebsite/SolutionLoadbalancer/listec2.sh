#!/bin/bash

# Specify the user and private key
user="ec2-user"
private_key="<pathtopem>"

# List all instances with tag servername:staticwebserver
instances=$(aws ec2 describe-instances --filters "Name=tag:servername,Values=staticwebserver" --query "Reservations[].Instances[].PublicIpAddress" --output text)

# Create an empty inventory file
echo "[webservers]" > inventory.txt

# Add the instances to the inventory file
for instance in $instances; do
  echo "$instance ansible_user=$user ansible_ssh_private_key_file=$private_key" >> inventory.txt
done

# Run the Ansible playbook
ansible-playbook -i inventory.txt YOUR_ANSIBLE_PLAYBOOK.yml
