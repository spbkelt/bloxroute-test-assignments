# ASSIGNMENT.md

## Overview
This project provisions an EC2 instance running Ubuntu 22.04 with Nginx installed and configured using Terraform. The infrastructure is automated and secured with a security group allowing HTTP and SSH traffic.

# Terraform State Management Documentation

---
## Key Assumptions
- We rely on networking resources specified by infrastructure owner
- Public Subnets: A public subnet is defined as one whose route table includes a route to an Internet Gateway.
- Dynamic Filtering: The solution dynamically fetches public subnets, avoiding hardcoding of subnet IDs.

## Approach to Terraform State Management

### Chosen Method: Remote Backend with S3 and DynamoDB

I chose to manage the Terraform state using a **remote backend** hosted in an **AWS S3 bucket**, with **DynamoDB for state locking and consistency**. This approach ensures the state file is securely stored and accessible for collaboration, while also preventing concurrent modifications.

---

## Configuration Details

1. **State Storage: AWS S3 Bucket**
   - An S3 bucket (`bloxroute-dz-terraform-state-bucket`) is used to store the Terraform state file.
   - Bucket versioning and server-side encryption (SSE) are enabled to ensure the integrity and security of the state file.

2. **State Locking: AWS DynamoDB Table**
   - A DynamoDB table (`terraform-lock-table`) is configured for state locking.
   - This prevents multiple users or processes from modifying the state concurrently, ensuring consistency.

3. **Region:**
   - Both the S3 bucket and DynamoDB table are provisioned in the `us-east-1` region for simplicity and low-latency access.

---

## Reasoning

### Benefits of Remote State Management
- **Collaboration**: A remote backend allows multiple team members to work on the infrastructure simultaneously without conflicts.
- **Persistence**: The state file is safely stored in a cloud-based location and not tied to a developer's local environment.
- **Disaster Recovery**: With S3 bucket versioning, any accidental changes to the state file can be reverted.
- **Consistency**: DynamoDB-based locking ensures state consistency, preventing race conditions.

### Security Features
- **Encryption**: S3 bucket encryption (AES256) protects the state file from unauthorized access.
- **Access Control**: IAM policies restrict access to the S3 bucket and DynamoDB table, ensuring only authorized users can manage Terraform state.
- **Auditability**: S3 logging and versioning provide an audit trail for any changes or access to the state file.

---

## Tradeoffs and Considerations

### Pros
- **Scalability**: The solution scales with the size of the state file and the number of team members.
- **Redundancy**: S3 provides high availability and redundancy for state storage.
- **Concurrency**: DynamoDB ensures that only one process can modify the state at a time.

### Cons
- **Complexity**: This setup is more complex than local state management and requires additional AWS resources (S3 and DynamoDB).
- **Cost**: While the costs are minimal, S3 storage and DynamoDB throughput incur charges.
- **AWS Dependency**: This approach ties state management to the AWS ecosystem, which may not be suitable for multi-cloud environments.

### Alternative Options
- **Local Backend**: Simple but lacks collaboration and requires manual backups.
- **Other Remote Backends**: Solutions like Terraform Cloud or other cloud providers can be used, but they may have additional costs or dependencies.

---

## Summary

Using a remote backend with S3 and DynamoDB strikes a balance between security, collaboration, and scalability. While it introduces slight complexity and costs, these tradeoffs are outweighed by the benefits of centralized, secure, and consistent state management. This approach is well-suited for team env


---

## Deployment Instructions

### Prerequisites:
1. Install Terraform: https://www.terraform.io/downloads.html
2. AWS CLI configured with credentials: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
3. Install `jq` CLI tool to parse JSON output from aws-cliv2

---

### Steps to Deploy:
1. Unpack the archive with assessment to a working directory.
2. Initialize Terraform:
   ```bash
   /bin/bash ./deploy.sh
   ```
