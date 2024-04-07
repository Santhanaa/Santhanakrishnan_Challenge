## Solution 2: Load Balanced ( Production Scenario where user activity is consistent and not that variable enough and only specific region to be covered.

1. Create an Amazon EC2 instance and use a configuration management tool such as Ansible to configure it as a web server (e.g., Apache or Nginx). Create an Amazon Machine Image (AMI) from this instance.

2. Use AWS Certificate Manager to create a self-signed SSL certificate and configure the web server to use HTTPS with this certificate.

3. Create a Launch Configuration with this AMI.

4. Use this Launch Configuration to set up an Auto Scaling Group. Configure it to scale based on demand.

5. Set up a Load Balancer (ELB) and configure it to use your Auto Scaling Group.

6. Set up security groups to allow only HTTPS (port 443) traffic to your instance.

7. Use CloudWatch and CloudTrail for monitoring and logging.
