#!/bin/sh
# ---------------------------------------------------------------------------
# Terraform Project Initializer
# Supports:
#   --env-folders : environment-based folders (default if not specified)
#   --workspaces  : single-folder workspace-style project
#
# Usage:
#   ./project_init.sh [--env-folders|--workspaces] --bucket <bucket> --dynamodb-table <table> --region <region> --project <project>
#
# Example:
#   ./project_init.sh --env-folders --bucket my-bucket --dynamodb-table my-lock --region il-central-1 --project myproj
#   ./project_init.sh --workspaces  --bucket my-bucket --dynamodb-table my-lock --region il-central-1 --project myproj
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

# ---------------------------------------------------------------------------
# Parse named arguments instead of positional ones
# ---------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --dynamodb-table)
      DYNAMO_TABLE_NAME="$2"
      shift 2
      ;;
    --region)
      REGION_NAME="$2"
      shift 2
      ;;
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --account-id)
      AWS_ACCOUNT_ID="$2"
      shift 2
      ;;
    --cicd-role)
      AWS_ROLE_NAME="$2"
      shift 2
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
    *)
      echo "Error: Unexpected argument: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validate required args
# ---------------------------------------------------------------------------
if [ -z "$BUCKET_NAME" ] || [ -z "$DYNAMO_TABLE_NAME" ] || [ -z "$REGION_NAME" ] || [ -z "$PROJECT_NAME" ]; then
  echo "Usage:"
  echo "  $0 [--env-folders|--workspaces] --bucket <bucket> --table <table> --region <region> --project <project> [--account-id <id>] [--ci-role-name <role>]"
  exit 1
fi

# ---------------------------------------------------------------------------
# Warn if optional args missing
# ---------------------------------------------------------------------------
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "⚠️  Warning: --account-id not provided. Some CI/CD templates may not have AWS account info replaced."
fi

if [ -z "$AWS_ROLE_NAME" ]; then
  echo "⚠️  Warning: --cicd-role not provided. CICD may lack AWS role configuration for terraform apply."
fi

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
    key            = "${PROJECT_NAME}-tfstates/${ENV}/terraform.tfstate"
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
        sed -i "s/^\([[:space:]]*project\)[[:space:]]*=.*/\1              = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      else
        sed -i '' "s/^\([[:space:]]*project\)[[:space:]]*=.*/\1              = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      fi
      echo "Updated project name in $TFVARS_FILE"
    fi
  done

  echo
  echo "✅ Project '$PROJECT_NAME' initialized successfully in env-folder mode."
  echo "   Backends created under: $DEST_DIR/envs/{dev,staging,prod}"

  # -------------------------------------------------------------------------
  # Copy CI/CD workflows (--env-folders mode)
  # -------------------------------------------------------------------------

  WORKFLOWS_SRC="cicd_templates/env_folders"
  WORKFLOWS_DEST="$DEST_DIR/.github/workflows"

  echo "Setting up GitHub Actions workflows..."
  mkdir -p "$WORKFLOWS_DEST" || {
    echo "Error: Failed to create workflows directory." >&2
    exit 1
  }

  for FILE in pipeline.yml destroy.yml; do
    if [ -f "$WORKFLOWS_SRC/$FILE" ]; then
      cp "$WORKFLOWS_SRC/$FILE" "$WORKFLOWS_DEST/" || {
        echo "Error: Failed to copy $FILE" >&2
        exit 1
      }
      echo "Copied $FILE → $WORKFLOWS_DEST/"
    else
      echo "Warning: $WORKFLOWS_SRC/$FILE not found."
    fi
  done

  echo "   GitHub workflows copied to: $WORKFLOWS_DEST"
  echo

  # -------------------------------------------------------------------------
  # Inject environment variables into pipeline.yml (--env-folders)
  # -------------------------------------------------------------------------

  for FILE in "$WORKFLOWS_DEST/pipeline.yml" "$WORKFLOWS_DEST/destroy.yml"; do
      if [ -f "$FILE" ]; then
          echo "Updating environment variable values in $FILE..."

          sed -i "s|^\([[:space:]]*AWS_REGION:\).*|\1 $REGION_NAME|" "$FILE"
          sed -i "s|^\([[:space:]]*AWS_ACCOUNT_ID:\).*|\1 \"$AWS_ACCOUNT_ID\"|" "$FILE"
          sed -i "s|^\([[:space:]]*AWS_ROLE_NAME:\).*|\1 $AWS_ROLE_NAME|" "$FILE"

          echo "✅ Environment values replaced successfully in $FILE."
      else
          echo "⚠️ $(basename "$FILE") not found — skipping env replacement."
      fi
  done

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
    bucket               = "$BUCKET_NAME"
    key                  = "terraform.tfstate"
    region               = "$REGION_NAME"
    dynamodb_table       = "$DYNAMO_TABLE_NAME"
    encrypt              = true
    workspace_key_prefix = "${PROJECT_NAME}-tfstates"
  }
}
EOF
  echo "Created $BACKEND_FILE"

  TFVARS_FILE="$DEST_DIR/terraform.tfvars"
  if [ -f "$TFVARS_FILE" ]; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s/^project[[:space:]]*=.*/project = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    else
      sed -i '' "s/^project[[:space:]]*=.*/project = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
    fi
    echo "Updated project name in $TFVARS_FILE"
  fi

  # -------------------------------------------------------------------------
  # Copy CI/CD workflows (only for workspaces mode)
  # -------------------------------------------------------------------------
  WORKFLOWS_SRC="cicd_templates/workspaces"
  WORKFLOWS_DEST="$DEST_DIR/.github/workflows"

  echo "Setting up GitHub Actions workflows..."
  mkdir -p "$WORKFLOWS_DEST" || {
    echo "Error: Failed to create workflows directory." >&2
    exit 1
  }

  for FILE in pipeline.yml destroy.yml; do
    if [ -f "$WORKFLOWS_SRC/$FILE" ]; then
      cp "$WORKFLOWS_SRC/$FILE" "$WORKFLOWS_DEST/" || {
        echo "Error: Failed to copy $FILE" >&2
        exit 1
      }
      echo "Copied $FILE → $WORKFLOWS_DEST/"
    else
      echo "Warning: $WORKFLOWS_SRC/$FILE not found."
    fi
  done

  echo "   GitHub workflows copied to: $WORKFLOWS_DEST"
  echo

  # -------------------------------------------------------------------------
  # Inject environment variables into pipeline.yml (--workspaces mode)
  # -------------------------------------------------------------------------

  for FILE in "$WORKFLOWS_DEST/pipeline.yml" "$WORKFLOWS_DEST/destroy.yml"; do
      if [ -f "$FILE" ]; then
          echo "Updating environment variable values in $FILE..."

          sed -i "s|^\([[:space:]]*AWS_REGION:\).*|\1 $REGION_NAME|" "$FILE"
          sed -i "s|^\([[:space:]]*AWS_ACCOUNT_ID:\).*|\1 \"$AWS_ACCOUNT_ID\"|" "$FILE"
          sed -i "s|^\([[:space:]]*AWS_ROLE_NAME:\).*|\1 $AWS_ROLE_NAME|" "$FILE"

          echo "✅ Environment values replaced successfully in $FILE."
      else
          echo "⚠️ $(basename "$FILE") not found — skipping env replacement."
      fi
  done
  
# ---------------------------------------------------------------------------
# Invalid mode
# ---------------------------------------------------------------------------

echo "✅ Project '$PROJECT_NAME' initialized successfully in workspace mode."
echo "   Backend and terraform.tfvars updated in: $DEST_DIR/"

else
  echo "Error: Unknown mode '$MODE'. Use --env-folders or --workspaces." >&2
  exit 1
fi