variable "region" {
  description = "AWS region to deploy the resources"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "security_group_name" {
  description = "Name for the security group"
  type        = string
  default     = "nginx-security-group"
}

variable "allow_http_cidr" {
  description = "CIDR block allowed to access HTTP"
  type        = string
  default     = "0.0.0.0/0"
}

# Declare variable for S3 bucket name
variable "bucket_name" {
  description = "The name of the S3 bucket for Terraform state storage"
  type        = string
}

# Declare variable for DynamoDB table name used for state locking
variable "dynamodb_table_name" {
  description = "The name of the DynamoDB table for Terraform state locking"
  type        = string
}

# VPC ID
variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet where the EC2 instance will be launched"
  type        = string
  default     = "10.0.4.0/24"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for the first public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
  default     = "10.0.2.0/24"
}