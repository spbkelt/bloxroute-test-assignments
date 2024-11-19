#!/bin/bash -x

S3_BUCKET_NAME=bloxroute-dz-terraform-state-bucket
S3_POLICY_NAME=bloxroute-dz-terraform-s3-policy
DYNAMODB_TABLE_NAME=bloxroute-dz-terraform-lock-table
DYNAMODB_POLICY_NAME=bloxroute-dz-terraform-dynamodb-policy
TERRAFORM_ROLE_NAME=bloxroute-dz-terraform-role
ADMIN_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
REGION=us-east-1

# Configure the Terraform Backend
aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $REGION
aws s3api put-bucket-encryption --bucket $S3_BUCKET_NAME --server-side-encryption-configuration '{
    "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
        }
    }]
}'

# Enable Versioning on S3
aws s3api put-bucket-versioning --bucket $S3_BUCKET_NAME --versioning-configuration Status=Enabled

# Enable Logging on S3
aws s3api put-bucket-logging --bucket $S3_BUCKET_NAME --bucket-logging-status "{
    \"LoggingEnabled\": {
        \"TargetBucket\": \"$S3_BUCKET_NAME\",
        \"TargetPrefix\": \"logs/\"
    }
}"

# Check if the DynamoDB table already exists
DYNAMODB_TABLE_EXISTS=$(aws dynamodb list-tables --region $REGION --query "TableNames" --output text | grep -w $DYNAMODB_TABLE_NAME)

if [ -n "$DYNAMODB_TABLE_EXISTS" ]; then
    echo "DynamoDB table '$DYNAMODB_TABLE_NAME' already exists in region '$REGION'. Skipping creation."
else
    echo "Creating DynamoDB table '$DYNAMODB_TABLE_NAME' in region '$REGION'..."
    aws dynamodb create-table --table-name $DYNAMODB_TABLE_NAME \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
      --region $AWS_SESSION_TOKENREGION

    # Wait until the table is active
    echo "Waiting for DynamoDB table '$DYNAMODB_TABLE_NAME' to become active..."
    aws dynamodb wait table-exists --table-name $DYNAMODB_TABLE_NAME --region $REGION
    echo "DynamoDB table '$DYNAMODB_TABLE_NAME' is now active."
fi

# Check if the policy exists
S3_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$S3_POLICY_NAME'].Arn" --output text)

if [ -z "$S3_POLICY_ARN" ]; then
    echo "Policy '$S3_POLICY_NAME' does not exist. Creating the policy..."
    S3_POLICY_ARN=$(aws iam create-policy --policy-name "$S3_POLICY_NAME" --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"s3:GetObject\",
                    \"s3:PutObject\",
                    \"s3:ListS3_BUCKET_NAME\"
                ],
                \"Resource\": [
                    \"arn:aws:s3:::$S3_BUCKET_NAME\",
                    \"arn:aws:s3:::$S3_BUCKET_NAME/*\"
                ]
            }
        ]
    }" --query 'Policy.Arn' --output text)
    echo "S3 access policy created: $S3_POLICY_ARN"
else
    echo "Policy '$S3_POLICY_NAME' already exists: $S3_POLICY_ARN"
fi

# Create IAM Policy for DynamoDB Access
# Check if the policy exists
DYNAMODB_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$DYNAMODB_POLICY_NAME'].Arn" --output text)

if [ -z "$DYNAMODB_POLICY_ARN" ]; then
    echo "Policy '$DYNAMODB_POLICY_NAME' does not exist. Creating the policy..."
    DYNAMODB_POLICY_ARN=$(aws iam create-policy --policy-name "$DYNAMODB_POLICY_NAME" --policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Action\": [
                    \"dynamodb:PutItem\",
                    \"dynamodb:GetItem\",
                    \"dynamodb:DeleteItem\"
                ],
                \"Resource\": \"arn:aws:dynamodb:$REGION:$(aws sts get-caller-identity --query Account --output text):table/$DYNAMODB_TABLE_NAME\"
            }
        ]
    }" --query 'Policy.Arn' --output text)
    echo "DynamoDB access policy created: $DYNAMODB_POLICY_ARN"
else
    echo "Policy '$DYNAMODB_POLICY_NAME' already exists: $DYNAMODB_POLICY_ARN"
fi

# Check if IAM Role Exists
echo "Checking if IAM role '$TERRAFORM_ROLE_NAME' exists..."
TERRAFORM_ROLE_EXISTS=$(aws iam list-roles --query "Roles[?RoleName=='$TERRAFORM_ROLE_NAME']" --output text)

if [ -z "$TERRAFORM_ROLE_EXISTS" ]; then
    echo "IAM role '$TERRAFORM_ROLE_NAME' does not exist. Creating the role..."

    # Create the IAM Role with an Assume Role Policy
    aws iam create-role --role-name "$TERRAFORM_ROLE_NAME" --assume-role-policy-document "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Principal\": {
                    \"AWS\": \"$ADMIN_USER_ARN\"
                },
                \"Action\": \"sts:AssumeRole\"
            }
        ]
    }"

    echo "IAM role '$TERRAFORM_ROLE_NAME' created successfully."
else
    echo "IAM role '$TERRAFORM_ROLE_NAME' already exists."
fi

# Create the IAM policy for EC2, VPC, and IAM actions
CUSTOM_POLICY_NAME="bloxroute-dz-terraform-ec2-vpc-policy"
CUSTOM_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$CUSTOM_POLICY_NAME'].Arn" --output text)

if [ -z "$CUSTOM_POLICY_ARN" ]; then
    echo "Creating custom policy '$CUSTOM_POLICY_NAME'..."
    CUSTOM_POLICY_ARN=$(aws iam create-policy --policy-name "$CUSTOM_POLICY_NAME" --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "iam:Get*",
                    "iam:List*",
                    "iam:PassRole",
                    "iam:CreateRole",
                    "iam:AttachRolePolicy",
                    "iam:AddRoleToInstanceProfile",
                    "iam:DeleteInstanceProfile",
                    "iam:CreateInstanceProfile",
                    "ec2:Describe*",     
                    "ec2:CreateVpc",
                    "ec2:AllocateAddress",
                    "ec2:CreateSubnet",
                    "ec2:ReleaseAddress",
                    "ec2:CreateRouteTable",
                    "ec2:AssociateRouteTable",
                    "ec2:CreateInternetGateway",
                    "ec2:AttachInternetGateway",
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:AuthorizeSecurityGroupEgress",
                    "ec2:RunInstances",
                    "ec2:CreateNatGateway",
                    "ec2:ModifyVpcAttribute",
                    "ec2:CreateRoute",
                    "ec2:CreateTags",
                    "ec2:DeleteSubnet",
                    "ec2:DeleteSecurityGroup",
                    "ec2:DeleteRouteTable",
                    "ec2:CreateSecurityGroup",
                    "ec2:ModifySubnetAttribute",
                    "ec2:RevokeSecurityGroupEgress",
                    "ec2:TerminateInstances",
                    "ec2:StartInstances",
                    "ec2:StopInstances",
                    "ec2:ModifyInstanceAttribute",
                    "elasticloadbalancing:Describe*",
                    "elasticloadbalancing:CreateLoadBalancer",
                    "elasticloadbalancing:CreateTargetGroup",
                    "elasticloadbalancing:ModifyTargetGroupAttributes",
                    "elasticloadbalancing:DeleteTargetGroup",
                    "elasticloadbalancing:ModifyLoadBalancerAttributes",
                    "elasticloadbalancing:RegisterTargets",
                    "elasticloadbalancing:CreateListener",
                    "elasticloadbalancing:DeleteLoadBalancer",
                    "elasticloadbalancing:DeregisterTargets",
                    "elasticloadbalancing:DeleteListener",
                    "elasticloadbalancing:AddTags"
                ],
                "Resource": "*"
            }
        ]
    }' --query 'Policy.Arn' --output text)

    echo "Custom policy created: $CUSTOM_POLICY_ARN"
else
    echo "Custom policy '$CUSTOM_POLICY_NAME' already exists: $CUSTOM_POLICY_ARN"
fi

# Step 3: Attach Policies to the Role
echo "Attaching policies to the IAM role..."
aws iam attach-role-policy --role-name "$TERRAFORM_ROLE_NAME" --policy-arn "$S3_POLICY_ARN"
aws iam attach-role-policy --role-name "$TERRAFORM_ROLE_NAME" --policy-arn "$DYNAMODB_POLICY_ARN"
aws iam attach-role-policy --role-name "$TERRAFORM_ROLE_NAME" --policy-arn "$CUSTOM_POLICY_ARN"

echo "Policies attached to IAM role: $TERRAFORM_ROLE_NAME"

# Assume IAM role and configure terraform security variables
echo "Assuming IAM role: $TERRAFORM_ROLE_NAME..."
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$TERRAFORM_ROLE_NAME"
ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "terraform-session")

# Parse the credentials
export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_SESSION_TOKEN" ]; then
    echo "Error: Failed to retrieve temporary credentials from assume-role output."
    exit 1
fi

echo "Temporary credentials obtained successfully."

# Terraform Init and Infrastructure Provisioning
terraform init -upgrade
terraform apply -auto-approve
