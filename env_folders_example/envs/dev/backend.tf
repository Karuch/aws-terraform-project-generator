terraform {
  backend "s3" {
    bucket         = "project-generator-test-backend"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "project-generator-test-lock"
    encrypt        = true
  }
}