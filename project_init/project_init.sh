#!/bin/sh
# ---------------------------------------------------------------------------
# Terraform Project Initializer
# Supports:
#   --env-folders : environment-based folders (default if not specified)
#   --workspaces  : single-folder workspace-style project
#
# Usage:
#   ./project_init.sh [--env-folders|--workspaces] <bucket> <table> <region> <project>
#
# Example:
#   ./project_init.sh --env-folders my-bucket my-lock il-central-1 myproj
#   ./project_init.sh --workspaces  my-bucket my-lock il-central-1 myproj
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Parse mode flag
# ---------------------------------------------------------------------------
if [ "$1" = "--env-folders" ] || [ "$1" = "--workspaces" ]; then
  MODE="$1"
  shift
else
  MODE="--env-folders"  # default
fi

if [ "$#" -ne 4 ]; then
  echo "Usage:"
  echo "  $0 [--env-folders|--workspaces] <backend_bucket_name> <lock_dynamodb_table> <region> <project>"
  echo "Example:"
  echo "  $0 --env-folders mybucket mylock il-central-1 myproject"
  echo "  $0 --workspaces  mybucket mylock il-central-1 myproject"
  exit 1
fi

BUCKET_NAME=$1
DYNAMO_TABLE_NAME=$2
REGION_NAME=$3
PROJECT_NAME=$4

# ---------------------------------------------------------------------------
# Validate project name
# ---------------------------------------------------------------------------
echo "$PROJECT_NAME" | grep -Eq '^[a-z0-9-]+$' || {
  echo "Error: Project name must contain only lowercase letters, numbers, and hyphens." >&2
  exit 1
}

# ---------------------------------------------------------------------------
# MODE 1: Environment-based folders
# ---------------------------------------------------------------------------
if [ "$MODE" = "--env-folders" ]; then
  SRC_DIR="env_folders_template"
  DEST_DIR="$PROJECT_NAME"

  if [ -d "$DEST_DIR" ]; then
    echo "Directory '$DEST_DIR' already exists — skipping copy."
  else
    echo "Copying $SRC_DIR -> $DEST_DIR ..."
    cp -r "$SRC_DIR" "$DEST_DIR" || {
      echo "Error: Failed to copy template directory." >&2
      exit 1
    }
  fi

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

    TFVARS_FILE="$ENV_PATH/terraform.tfvars"
    if [ -f "$TFVARS_FILE" ]; then
      if sed --version >/dev/null 2>&1; then
        sed -i "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      else
        sed -i '' "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      fi
      echo "Updated project name in $TFVARS_FILE"
    fi
  done

  echo
  echo "✅ Project '$PROJECT_NAME' initialized successfully in env-folder mode."
  echo "   Backends created under: $DEST_DIR/envs/{dev,staging,prod}"

# ---------------------------------------------------------------------------
# MODE 2: Workspace-based structure
# ---------------------------------------------------------------------------
elif [ "$MODE" = "--workspaces" ]; then
  SRC_DIR="workspaces_template"
  DEST_DIR="$PROJECT_NAME"

  if [ -d "$DEST_DIR" ]; then
    echo "Directory '$DEST_DIR' already exists — skipping copy."
  else
    echo "Copying $SRC_DIR -> $DEST_DIR ..."
    cp -r "$SRC_DIR" "$DEST_DIR" || {
      echo "Error: Failed to copy template directory." >&2
      exit 1
    }
  fi

  BACKEND_FILE="$DEST_DIR/backend.tf"
  cat <<EOF > "$BACKEND_FILE"
terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "${PROJECT_NAME}/terraform.tfstate"
    region         = "$REGION_NAME"
    dynamodb_table = "$DYNAMO_TABLE_NAME"
    encrypt        = true
  }
}
EOF
  echo "Created $BACKEND_FILE"

  TFVARS_FILE="$DEST_DIR/terraform.tfvars"
  if [ -f "$TFVARS_FILE" ]; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    else
      sed -i '' "s/^project[[:space:]]*=.*/project               = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    fi
    echo "Updated project name in $TFVARS_FILE"
  fi

  echo
  echo "✅ Project '$PROJECT_NAME' initialized successfully in workspace mode."
  echo "   Backend and terraform.tfvars updated in: $DEST_DIR/"

# ---------------------------------------------------------------------------
# Invalid mode
# ---------------------------------------------------------------------------
else
  echo "Error: Unknown mode '$MODE'. Use --env-folders or --workspaces." >&2
  exit 1
fi

