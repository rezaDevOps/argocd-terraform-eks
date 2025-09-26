terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "argocd-terraform/prod/terraform.tfstate"
    region = "us-west-2"
    
    # Enable state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    
    # Production should use KMS encryption
    kms_key_id = "alias/terraform-state-key"
  }
}
