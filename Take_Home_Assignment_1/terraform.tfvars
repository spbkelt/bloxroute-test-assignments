region              = "us-east-1"
ami_id              = "ami-005fc0f236362e99f" # Ubuntu Server 22.04 LTS (HVM)
instance_type       = "t2.micro"
security_group_name = "nginx-security-group"
allow_http_cidr     = "0.0.0.0/0"
bucket_name         = "bloxroute-dz-terraform-state-bucket"
dynamodb_table_name = "terraform-lock-table"

vpc_cidr = "10.0.0.0/16"
public_subnet_1_cidr = "10.0.1.0/24"
public_subnet_2_cidr = "10.0.2.0/24"
