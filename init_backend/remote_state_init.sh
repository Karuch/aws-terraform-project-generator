#!/bin/sh
# ---------------------------------------------------------------------------
# Terraform Remote State Initializer
# Creates an S3 bucket and DynamoDB table for Terraform remote state backend.
# Supports all AWS regions, including dynamic handling for us-east-1.
# ---------------------------------------------------------------------------

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <prefix> <region>"
  echo "Example: $0 myproject il-central-1"
  exit 1
fi

PREFIX=$1
REGION_NAME=$2
BUCKET_NAME="${PREFIX}-backend"
DYNAMO_TABLE_NAME="${PREFIX}-lock"
ERRORS=0

# Validate prefix format
if ! echo "$PREFIX" | grep -Eq '^[a-z0-9-]+$'; then
  echo "Error: Prefix must be lowercase letters, numbers, and hyphens only."
  exit 1
fi

echo "Initializing Terraform backend resources..."
echo "  Region: $REGION_NAME"
echo "  Bucket: $BUCKET_NAME"
echo "  Table : $DYNAMO_TABLE_NAME"
echo

# ---------------------------------------------------------------------------
# 1. Check if the bucket already exists
# ---------------------------------------------------------------------------
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "S3 bucket $BUCKET_NAME already exists — skipping creation."
else
  echo "Creating S3 bucket $BUCKET_NAME..."

  if [ "$REGION_NAME" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION_NAME"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION_NAME" \
      --create-bucket-configuration LocationConstraint="$REGION_NAME"
  fi

  if [ $? -ne 0 ]; then
    echo "Error: Failed to create S3 bucket $BUCKET_NAME."
    ERRORS=$((ERRORS+1))
  fi
fi

# ---------------------------------------------------------------------------
# 2. Enable versioning
# ---------------------------------------------------------------------------
echo "Enabling versioning for S3 bucket..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --region "$REGION_NAME"
if [ $? -ne 0 ]; then
  echo "Error: Failed to enable versioning for S3 bucket $BUCKET_NAME."
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# 3. Enable server-side encryption
# ---------------------------------------------------------------------------
echo "Enabling encryption for S3 bucket..."
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }' \
  --region "$REGION_NAME"
if [ $? -ne 0 ]; then
  echo "Error: Failed to enable encryption for S3 bucket $BUCKET_NAME."
  ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# 4. Create DynamoDB table for state locking
# ---------------------------------------------------------------------------
echo "Creating DynamoDB table $DYNAMO_TABLE_NAME..."
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE_NAME" --region "$REGION_NAME" >/dev/null 2>&1; then
  echo "DynamoDB table $DYNAMO_TABLE_NAME already exists — skipping creation."
else
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$REGION_NAME"

  if [ $? -ne 0 ]; then
    echo "Error: Failed to create DynamoDB table $DYNAMO_TABLE_NAME."
    ERRORS=$((ERRORS+1))
  fi
fi

# ---------------------------------------------------------------------------
# 5. Generate backend.tf if everything succeeded
# ---------------------------------------------------------------------------
if [ $ERRORS -eq 0 ]; then
  cat <<EOF > backend.tf
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform/backend/terraform_aws.tfstate"
    region         = "$REGION_NAME"
    dynamodb_table = "$DYNAMO_TABLE_NAME"
    encrypt        = true
  }
}
EOF
  echo
  echo "✅ backend.tf has been generated successfully."
else
  echo
  echo "❌ There were errors in creating the resources. backend.tf was not generated."
fi

