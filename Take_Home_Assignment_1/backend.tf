terraform {
  backend "s3" {
    bucket         = "bloxroute-dz-terraform-state-bucket"
    key            = "nginx-server/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bloxroute-dz-terraform-lock-table"
    encrypt        = true
  }
}
