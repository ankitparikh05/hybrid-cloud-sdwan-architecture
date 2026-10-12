# Description: Create Backend resources for Terraform state management and locking

# ------------------------------------------------------
# Terraform Backend Configuration
# ------------------------------------------------------
terraform {
  backend "s3" {
    bucket       = "ankit-networking-tfstate-bucket-2026"
    key          = "networking/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
