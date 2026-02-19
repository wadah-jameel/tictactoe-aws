# 1- Architecture Overview
```bash

 Internet → ALB (Port 80/443) → Target Group → EC2 Instances (Docker)
                                              ↓
                                         IAM Role (EC2)
```

# 2- Repository Structure

```bash

tictactoe-aws-deployment/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   ├── MONITORING.md
│   ├── TROUBLESHOOTING.md
│   └── COST_OPTIMIZATION.md
├── src/
│   ├── index.html
│   ├── Dockerfile
│   └── nginx.conf
├── infrastructure/
│   ├── cloudformation/
│   │   └── infrastructure.yaml
│   └── terraform/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   ├── deploy.sh
│   ├── setup-monitoring.sh
│   └── cleanup.sh
├── cloudwatch/
│   ├── dashboard.json
│   ├── alarms.json
│   └── log-insights-queries.md
├── .github/
│   └── workflows/
│       └── deploy.yml
├── LICENSE
└── CONTRIBUTING.md

```


# 3- Prepare Your Files

## Create Dockerfile

## Create nginx.conf

## Create Index.html


# 4- Create IAM Roles

## Role Name: TicTacToe-EC2-Role
## Description: "IAM role for TicTacToe EC2 instances with Docker"
## Trusted entity type: AWS service
## Use case: EC2
## Add permissions policies:
### ✅ AmazonEC2ContainerRegistryReadOnly (for ECR if needed)
### ✅ CloudWatchAgentServerPolicy (for monitoring)
### ✅ AmazonSSMManagedInstanceCore (for Systems Manager)

## Create Custom Policy for Additional Permissions (Optional)
### If you need S3 access or other services:
### Create Policy: 
### Ploicy name: TicTacToe-EC2-CustomPolicy
### Ploicy file: ec2-policy.json

## Via AWS CLI:

```bash

# Create the policy
aws iam create-policy \
    --policy-name TicTacToe-EC2-CustomPolicy \
    --policy-document file://ec2-policy.json

# Attach to role
aws iam attach-role-policy \
    --role-name TicTacToe-EC2-Role \
    --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/TicTacToe-EC2-CustomPolicy

```
## Attach IAM Role to Existing EC2 Instance

# 5- Create Application Load Balancer

## Create Target Group First
### Configure Target Group:
#### - Choose target type: Instances
#### - Target group name: tictactoe-tg
#### - Protocol: HTTP
#### - Port: 80
#### - VPC: Select your VPC (default)
#### - Protocol version: HTTP1

## Health check settings:
### Health check protocol: HTTP
#### - Health check path: /
#### - Advanced health check settings:
#### - Healthy threshold: 2
#### - Unhealthy threshold: 2
#### - Timeout: 5 seconds
#### - Interval: 30 seconds
#### - Success codes: 200

## Register targets:
### ✅ Select your EC2 instance
#### - Port: 80
#### - Click "Include as pending below"
#### - Click "Create target group"

# Create Application Load Balancer

## Configure Load Balancer:
### Basic Configuration:
#### - Load balancer name: tictactoe-alb
#### - Scheme: Internet-facing
#### - IP address type: IPv4


## Network mapping:
### VPC: Select your VPC (default)
### Mappings: Select at least 2 Availability Zones
#### ✅ us-east-1a (example)
#### ✅ us-east-1b (example)
#### Select public subnets for each AZ


## Create ALB Security Group
### Security group name: tictactoe-alb-sg
### Description: Security group for TicTacToe ALB
### VPC: Your VPC
### Inbound rules:

```bash

HTTP    TCP    80    0.0.0.0/0    Allow HTTP
HTTPS   TCP    443   0.0.0.0/0    Allow HTTPS

```

### Outbound rule: Default - Allow all 


### Go back to ALB configuration and select this security group
### Listeners and routing:
#### - Listener: HTTP : 80
#### - Default action: Forward to tictactoe-tg
#### - Click "Create load balancer"

### Update EC2 Security Group
#### EC2 instances should only accept traffic from the ALB

#### Edit inbound rules

```bash

SSH    TCP    22    Your IP/0.0.0.0/0    SSH access
HTTP   TCP    80    tictactoe-alb-sg     Allow from ALB only

```

#### Source for HTTP: Select the ALB security group ID (sg-xxxxx)


# 6 - Create Launch Template (For Auto Scaling)

## Navigate to EC2 → Launch Templates
## Create launch template
## Launch template configuration:

### Launch template name: tictactoe-lt
### Template version description: Initial version with Docker
### Auto Scaling guidance: ✅ Check the box
### Application and OS Images:
### - AMI: Amazon Linux 2023 or Ubuntu 22.04
### - Instance type: t2.micro (or t3.micro)
### - Key pair: Select your key pair
### Network settings:
### - Don't include in launch template (we'll configure in Auto Scaling)
### Security groups: Select your EC2 security group
### Storage: 8 GB gp3
### Resource tags:
### Key: Name, Value: TicTacToe-Instance
### Advanced details:
### - IAM instance profile: TicTacToe-EC2-Role
### User data (Bootstrap script):


# 7 - Create Auto Scaling Group

## Navigate to EC2 → Auto Scaling Groups
## Click "Create Auto Scaling group"
## Choose launch template:
### Auto Scaling group name: tictactoe-asg
### Launch template: tictactoe-lt
### Version: Latest
### Click Next

## Choose instance launch options:
### VPC: Your VPC
### Availability Zones and subnets: Select same AZs as ALB (at least 2)
### Click Next

## Configure advanced options:
### Load balancing: ✅ Attach to an existing load balancer
### Choose from your load balancer target groups: tictactoe-tg
### Health checks:
### ✅ Turn on Elastic Load Balancing health checks
### Health check grace period: 300 seconds
### Additional settings:
### ✅ Enable group metrics collection within CloudWatch
### Click Next

## Configure group size and scaling:
### Desired capacity: 2
### Minimum capacity: 1
### Maximum capacity: 4

## Scaling policies (Optional - Target tracking):
### ✅ Target tracking scaling policy
### Scaling policy name: tictactoe-cpu-policy
### Metric type: Average CPU utilization
### Target value: 70
### Click Next

## Add notifications (Optional):
### Skip or configure SNS notifications
### Click Next

## Add tags:
### Key: Name, Value: TicTacToe-ASG-Instance
### Key: Environment, Value: Production
### Click Next

## Review:
### Review all settings
### Click Create Auto Scaling group

# 8 - Test the Deployment

## Get ALB DNS Name
### Go to EC2 → Load Balancers
### Select tictactoe-alb
### Copy the DNS name (e.g., tictactoe-alb-123456789.us-east-1.elb.amazonaws.com)

## Access Your Application
### Open browser and navigate to:

```bash

http://tictactoe-alb-123456789.us-east-1.elb.amazonaws.com

```

## Verify Health Checks

### AWS Console:
#### EC2 → Target Groups → tictactoe-tg
#### Targets tab → Check health status (should be "healthy")


### AWS CLI:

```bash

# Check target health
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:region:account:targetgroup/tictactoe-tg/xxxxx

```

















