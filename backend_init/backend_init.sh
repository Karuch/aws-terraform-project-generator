#!/bin/sh
# ---------------------------------------------------------------------------
# Terraform Remote State Initializer
# Creates an S3 bucket and DynamoDB table for Terraform remote state backend.
# Outputs ARNs as well.
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

# Validate prefix
if ! echo "$PREFIX" | grep -Eq '^[a-z0-9-]+$'; then
  echo "Error: Prefix must be lowercase letters, numbers, and hyphens only."
  exit 1
fi

echo "Initializing Terraform backend resources..."
echo "  Region: $REGION_NAME"
echo "  Bucket: $BUCKET_NAME"
echo "  Table : $DYNAMO_TABLE_NAME"
echo

# 1. Check bucket
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

# 2. Versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled \
  --region "$REGION_NAME" || ERRORS=$((ERRORS+1))

# 3. Encryption
echo "Enabling encryption..."
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
  --region "$REGION_NAME" || ERRORS=$((ERRORS+1))

# 4. DynamoDB table
echo "Creating DynamoDB table $DYNAMO_TABLE_NAME..."
if aws dynamodb describe-table --table-name "$DYNAMO_TABLE_NAME" --region "$REGION_NAME" >/dev/null 2>&1; then
  echo "DynamoDB table $DYNAMO_TABLE_NAME already exists — skipping creation."
else
  aws dynamodb create-table \
    --table-name "$DYNAMO_TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region "$REGION_NAME" || ERRORS=$((ERRORS+1))
fi

# ---------------------------------------------------------------------------
# 5. Generate backend.tf & print ARNs
# ---------------------------------------------------------------------------

if [ $ERRORS -eq 0 ]; then

  # Compute ARNs
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  S3_ARN="arn:aws:s3:::$BUCKET_NAME"
  DDB_ARN="arn:aws:dynamodb:$REGION_NAME:$ACCOUNT_ID:table/$DYNAMO_TABLE_NAME"

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
  echo
  echo "📌 Resource ARNs:"
  echo "  - S3 Bucket ARN        : $S3_ARN"
  echo "  - DynamoDB Table ARN   : $DDB_ARN"
  echo

else
  echo
  echo "❌ There were errors in creating the resources. backend.tf was not generated."
fi
