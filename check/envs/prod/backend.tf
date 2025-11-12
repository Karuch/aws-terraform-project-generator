terraform {
  backend "s3" {
    bucket         = "project-generator-test-backend"
    key            = "terraform/check/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "project-generator-test-lock"
    encrypt        = true
  }
}
