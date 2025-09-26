terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "argocd-terraform/staging/terraform.tfstate"
    region = "us-west-2"
    
    # Enable state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
