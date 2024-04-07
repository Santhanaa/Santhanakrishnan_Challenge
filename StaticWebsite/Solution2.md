## Solution 2: Load Balanced

1. Follow the same steps as in solution 1 to set up a web server on an EC2 instance, but create an Amazon Machine Image (AMI) from this instance.

2. Create a Launch Configuration with this AMI.

3. Use this Launch Configuration to set up an Auto Scaling Group. Configure it to scale based on demand.

4. Set up a Load Balancer (ELB) and configure it to use your Auto Scaling Group.

5. Use the same security group, SSL, and Route53 settings as in solution 1.

6. Use CloudWatch and CloudTrail for monitoring and logging.
