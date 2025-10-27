#!/bin/sh
# ---------------------------------------------------------------------------
# Terraform Project Initializer (POSIX-compatible)
# Copies env_folders_template -> <project_name> if not existing
# Generates backend.tf for dev/staging/prod
# Updates project name inside terraform.tfvars
# ---------------------------------------------------------------------------

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <backend_bucket_name> <lock_dynamodb_table> <region> <project>"
  echo "Example: $0 myproject-backend myproject-lock il-central-1 myproject"
  exit 1
fi

BUCKET_NAME=$1
DYNAMO_TABLE_NAME=$2
REGION_NAME=$3
PROJECT_NAME=$4
SRC_DIR="env_folders_template"
DEST_DIR="$PROJECT_NAME"

# ---------------------------------------------------------------------------
# 1. Validate project name
# ---------------------------------------------------------------------------
echo "$PROJECT_NAME" | grep -Eq '^[a-z0-9-]+$' || {
  echo "Error: Project name must contain only lowercase letters, numbers, and hyphens." >&2
  exit 1
}

# ---------------------------------------------------------------------------
# 2. Copy template if not existing
# ---------------------------------------------------------------------------
if [ -d "$DEST_DIR" ]; then
  echo "Directory '$DEST_DIR' already exists — skipping copy."
else
  echo "Copying $SRC_DIR -> $DEST_DIR ..."
  cp -r "$SRC_DIR" "$DEST_DIR" || {
    echo "Error: Failed to copy template directory." >&2
    exit 1
  }
fi

# ---------------------------------------------------------------------------
# 3. Generate backend.tf for each environment
# ---------------------------------------------------------------------------
for ENV in dev staging prod; do
  ENV_PATH="$DEST_DIR/envs/$ENV"
  mkdir -p "$ENV_PATH" || exit 1

  BACKEND_FILE="$ENV_PATH/backend.tf"
  cat <<EOF > "$BACKEND_FILE"
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "terraform/${PROJECT_NAME}/${ENV}/terraform.tfstate"
    region         = "$REGION_NAME"
    dynamodb_table = "$DYNAMO_TABLE_NAME"
    encrypt        = true
  }
}
EOF
  echo "Created $BACKEND_FILE"

  # -----------------------------------------------------------------------
  # 4. Update terraform.tfvars project name if file exists
  # -----------------------------------------------------------------------
  TFVARS_FILE="$ENV_PATH/terraform.tfvars"
  if [ -f "$TFVARS_FILE" ]; then
    # Replace only the line starting with project =
    # Works on both GNU and BSD sed
    if sed --version >/dev/null 2>&1; then
      # GNU sed
      sed -i "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    else
      # BSD/macOS sed
      sed -i '' "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    fi
    echo "Updated project name in $TFVARS_FILE"
  fi
done

echo
echo "Project '$PROJECT_NAME' initialized successfully."
echo "Backend files and terraform.tfvars updated under:"
echo "  $DEST_DIR/envs/dev/"
echo "  $DEST_DIR/envs/staging/"
echo "  $DEST_DIR/envs/prod/"
