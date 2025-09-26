terraform {
  backend "s3" {
    # PLEASE UPDATE THESE VALUES:
    # 1. S3 bucket name has been configured
    # 2. Replace 'us-west-2' with your preferred region if different
  
    bucket = "my-terraform-state-bucket-argocd-terraform-eks-703671892588"
    key    = "argocd-terraform/dev/terraform.tfstate"
    region = "us-west-2"
    
    # Enable state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    
    # Optional: Use KMS key for additional encryption
    # kms_key_id = "alias/terraform-state-key"
  }
}

# To create the S3 bucket and DynamoDB table for the first time, run:
#
# aws s3 mb s3://my-terraform-state-bucket-argocd-terraform-eks-703671892588
# 
# aws dynamodb create-table \
#   --table-name terraform-state-lock \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
