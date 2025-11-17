#!/bin/sh

# ---------------------------------------------------------------------------
# HELP MENU (must run BEFORE mode detection)
# ---------------------------------------------------------------------------
case "$1" in
  -h|--help|help)
    cat <<"EOF"
Usage:
  ./project_init.sh [--env-folders|--workspaces] [flags...]

Modes:
  --env-folders   environment-based folders (dev/staging/prod) with
                  per-environment backend + env.config for CI/CD
  --workspaces    single-folder, Terraform workspaces-style project

If no mode is provided, you will be asked to choose interactively.

Flags:
  workspaces mode:
    --project <name>
    --bucket <bucket>
    --dynamodb-table <table>
    --region <region>
    --account-id <id>
    --cicd-role <role>

  env-folders mode:
    --bucket-dev <bucket>            --bucket-staging <bucket>            --bucket-prod <bucket>
    --dynamodb-table-dev <table>     --dynamodb-table-staging <table>     --dynamodb-table-prod <table>
    --region-dev <region>            --region-staging <region>            --region-prod <region>
    --account-id-dev <id>            --account-id-staging <id>            --account-id-prod <id>
    --cicd-role-dev <role>           --cicd-role-staging <role>           --cicd-role-prod <role>

Examples:
  workspaces mode:

  ./project_init.sh --workspaces \
    --project myproj \
    --bucket tfstate-bucket \
    --dynamodb-table tf-locks \
    --region eu-west-1 \
    --account-id 123456789012 \
    --cicd-role TerraformApplyRole

  env-folders mode: 

  ./project_init.sh --env-folders \
    --project myproj \
    --bucket-dev dev-bucket \
    --bucket-staging staging-bucket \
    --bucket-prod prod-bucket \
    --dynamodb-table-dev dev-locks \
    --dynamodb-table-staging staging-locks \
    --dynamodb-table-prod prod-locks \
    --region-dev eu-west-1 \
    --region-staging eu-west-2 \
    --region-prod eu-central-1 \
    --account-id-dev 111111111111 \
    --account-id-staging 222222222222 \
    --account-id-prod 333333333333 \
    --cicd-role-dev DevTerraformRole \
    --cicd-role-staging StagingTerraformRole \
    --cicd-role-prod ProdTerraformRole


EOF
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# MODE SELECTION (explicit or interactive)
# ---------------------------------------------------------------------------
if [ "$1" = "--env-folders" ] || [ "$1" = "--workspaces" ]; then
  MODE="$1"
  shift
else
  echo "Select project mode or use --help/-h:"
  echo "  1) --env-folders: chose if your project might have different resources"
  echo "                    across different environments OR if you need different credentials/backends per environment"
  echo "                    (different account, region, bucket etc') to deploy resources."
  echo "  2) --workspaces:  chose if you have a single backend for all envs and same resources."
  echo "                    and the only difference you expect to be between environments is the values of the variables."
  printf "Enter choice [1/2]: "
  read MODE_CHOICE

  case "$MODE_CHOICE" in
    1) MODE="--env-folders" ;;
    2) MODE="--workspaces" ;;
    *)
      echo "Invalid selection."
      exit 1
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# ARGUMENT PARSING (generic + per-env)
# ---------------------------------------------------------------------------

# Generic flags
BUCKET_NAME=""
DYNAMO_TABLE_NAME=""
REGION_NAME=""
AWS_ACCOUNT_ID=""
AWS_ROLE_NAME=""
PROJECT_NAME=""

# Per-environment flags (env-folders mode)
BUCKET_NAME_DEV=""
BUCKET_NAME_STAGING=""
BUCKET_NAME_PROD=""

DYNAMO_TABLE_NAME_DEV=""
DYNAMO_TABLE_NAME_STAGING=""
DYNAMO_TABLE_NAME_PROD=""

REGION_NAME_DEV=""
REGION_NAME_STAGING=""
REGION_NAME_PROD=""

AWS_ACCOUNT_ID_DEV=""
AWS_ACCOUNT_ID_STAGING=""
AWS_ACCOUNT_ID_PROD=""

AWS_ROLE_NAME_DEV=""
AWS_ROLE_NAME_STAGING=""
AWS_ROLE_NAME_PROD=""

while [ "$#" -gt 0 ]; do
  case "$1" in

    # Workspaces flags
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

    # Per-environment flags
    --bucket-dev)
      BUCKET_NAME_DEV="$2"
      shift 2
      ;;
    --bucket-staging)
      BUCKET_NAME_STAGING="$2"
      shift 2
      ;;
    --bucket-prod)
      BUCKET_NAME_PROD="$2"
      shift 2
      ;;

    --dynamodb-table-dev)
      DYNAMO_TABLE_NAME_DEV="$2"
      shift 2
      ;;
    --dynamodb-table-staging)
      DYNAMO_TABLE_NAME_STAGING="$2"
      shift 2
      ;;
    --dynamodb-table-prod)
      DYNAMO_TABLE_NAME_PROD="$2"
      shift 2
      ;;

    --region-dev)
      REGION_NAME_DEV="$2"
      shift 2
      ;;
    --region-staging)
      REGION_NAME_STAGING="$2"
      shift 2
      ;;
    --region-prod)
      REGION_NAME_PROD="$2"
      shift 2
      ;;

    --account-id-dev)
      AWS_ACCOUNT_ID_DEV="$2"
      shift 2
      ;;
    --account-id-staging)
      AWS_ACCOUNT_ID_STAGING="$2"
      shift 2
      ;;
    --account-id-prod)
      AWS_ACCOUNT_ID_PROD="$2"
      shift 2
      ;;

    --cicd-role-dev)
      AWS_ROLE_NAME_DEV="$2"
      shift 2
      ;;
    --cicd-role-staging)
      AWS_ROLE_NAME_STAGING="$2"
      shift 2
      ;;
    --cicd-role-prod)
      AWS_ROLE_NAME_PROD="$2"
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
# Ask for project name if missing (interactive)
# ---------------------------------------------------------------------------
if [ -z "$PROJECT_NAME" ]; then
  printf "Enter project name (lowercase letters, numbers, and hyphens): "
  read PROJECT_NAME
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
    echo
    echo "────────────────────────────────────────────────────"
    echo "Configuring environment: $ENV"
    echo "────────────────────────────────────────────────────"

    ENV_PATH="$DEST_DIR/envs/$ENV"
    mkdir -p "$ENV_PATH" || exit 1

    # Resolve values for this environment:
    # Priority: per-env flag > generic flag > interactive prompt

    case "$ENV" in
      dev)
        BUCKET="${BUCKET_NAME_DEV:-$BUCKET_NAME}"
        DYNAMO="${DYNAMO_TABLE_NAME_DEV:-$DYNAMO_TABLE_NAME}"
        REGION="${REGION_NAME_DEV:-$REGION_NAME}"
        ACCOUNT="${AWS_ACCOUNT_ID_DEV:-$AWS_ACCOUNT_ID}"
        ROLE="${AWS_ROLE_NAME_DEV:-$AWS_ROLE_NAME}"
        ;;
      staging)
        BUCKET="${BUCKET_NAME_STAGING:-$BUCKET_NAME}"
        DYNAMO="${DYNAMO_TABLE_NAME_STAGING:-$DYNAMO_TABLE_NAME}"
        REGION="${REGION_NAME_STAGING:-$REGION_NAME}"
        ACCOUNT="${AWS_ACCOUNT_ID_STAGING:-$AWS_ACCOUNT_ID}"
        ROLE="${AWS_ROLE_NAME_STAGING:-$AWS_ROLE_NAME}"
        ;;
      prod)
        BUCKET="${BUCKET_NAME_PROD:-$BUCKET_NAME}"
        DYNAMO="${DYNAMO_TABLE_NAME_PROD:-$DYNAMO_TABLE_NAME}"
        REGION="${REGION_NAME_PROD:-$REGION_NAME}"
        ACCOUNT="${AWS_ACCOUNT_ID_PROD:-$AWS_ACCOUNT_ID}"
        ROLE="${AWS_ROLE_NAME_PROD:-$AWS_ROLE_NAME}"
        ;;
    esac

    if [ -z "$BUCKET" ]; then
      printf "Enter S3 bucket name for '%s' environment: " "$ENV"
      read BUCKET
    fi

    if [ -z "$DYNAMO" ]; then
      printf "Enter DynamoDB table name for '%s' environment: " "$ENV"
      read DYNAMO
    fi

    if [ -z "$REGION" ]; then
      printf "Enter AWS region for '%s' environment: " "$ENV"
      read REGION
    fi

    if [ -z "$ACCOUNT" ]; then
      printf "Enter AWS account ID for '%s' environment: " "$ENV"
      read ACCOUNT
    fi

    if [ -z "$ROLE" ]; then
      printf "Enter AWS role name for '%s' environment (for CI/CD assume-role): " "$ENV"
      read ROLE
    fi

    # -----------------------------------------------------------------------
    # backend.tf (per environment)
    # -----------------------------------------------------------------------
    BACKEND_FILE="$ENV_PATH/backend.tf"
    cat <<EOF > "$BACKEND_FILE"
terraform {
  backend "s3" {
    bucket         = "$BUCKET"
    key            = "${PROJECT_NAME}-tfstates/${ENV}/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$DYNAMO"
    encrypt        = true
  }
}
EOF
    echo "Created $BACKEND_FILE"

    # -----------------------------------------------------------------------
    # terraform.tfvars: ensure project is set
    # -----------------------------------------------------------------------
    TFVARS_FILE="$ENV_PATH/terraform.tfvars"
    if [ -f "$TFVARS_FILE" ]; then
      # macOS vs Linux sed compatibility
      if sed --version >/dev/null 2>&1; then
        # GNU sed
        sed -i "s/^\([[:space:]]*project\)[[:space:]]*=.*/\1              = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      else
        # BSD/Mac sed
        sed -i '' "s/^\([[:space:]]*project\)[[:space:]]*=.*/\1              = \"${PROJECT_NAME}\"/" "$TFVARS_FILE"
      fi
      echo "Updated project name in $TFVARS_FILE"
    fi

    # -----------------------------------------------------------------------
    # env.config for CI/CD (per environment)
    # -----------------------------------------------------------------------
    ENV_CONFIG_FILE="$ENV_PATH/env.config"
    cat <<EOF > "$ENV_CONFIG_FILE"
AWS_REGION="$REGION"
AWS_ACCOUNT_ID="$ACCOUNT"
AWS_ROLE_NAME="$ROLE"
EOF
    echo "Created $ENV_CONFIG_FILE"
  done

  echo
  echo "✅ Project '$PROJECT_NAME' initialized successfully in env-folder mode."
  echo "   Backends created under: $DEST_DIR/envs/{dev,staging,prod}"
  echo "   Per-environment env.config files created for CI/CD."

  # ---------------------------------------------------------------------------
  # Copy CI/CD workflows (--env-folders mode)
  # ---------------------------------------------------------------------------

  WORKFLOWS_SRC="cicd_templates/env_folders"
  WORKFLOWS_DEST="$DEST_DIR/.github/workflows"

  echo
  echo "Setting up GitHub Actions workflows for env-folders..."
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

  echo
  echo "   GitHub workflows copied to: $WORKFLOWS_DEST"
  echo
  exit 0

# ---------------------------------------------------------------------------
# MODE 2: Workspace-based structure (single set of credentials)
# ---------------------------------------------------------------------------
elif [ "$MODE" = "--workspaces" ]; then
  SRC_DIR="workspaces_template"
  DEST_DIR="$PROJECT_NAME"

  # Resolve generic values (CLI flags or interactive)
  if [ -z "$BUCKET_NAME" ]; then
    printf "Enter S3 bucket name (workspaces mode): "
    read BUCKET_NAME
  fi

  if [ -z "$DYNAMO_TABLE_NAME" ]; then
    printf "Enter DynamoDB table name (workspaces mode): "
    read DYNAMO_TABLE_NAME
  fi

  if [ -z "$REGION_NAME" ]; then
    printf "Enter AWS region (workspaces mode): "
    read REGION_NAME
  fi

  if [ -z "$AWS_ACCOUNT_ID" ]; then
    printf "Enter AWS account ID (workspaces mode): "
    read AWS_ACCOUNT_ID
  fi

  if [ -z "$AWS_ROLE_NAME" ]; then
    printf "Enter AWS role name (for CI/CD assume-role, workspaces mode): "
    read AWS_ROLE_NAME
  fi

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
  # Copy CI/CD workflows (workspaces mode)
  #   Here we still inject AWS_* values directly into the workflow env.
  # -------------------------------------------------------------------------
  WORKFLOWS_SRC="cicd_templates/workspaces"
  WORKFLOWS_DEST="$DEST_DIR/.github/workflows"

  echo
  echo "Setting up GitHub Actions workflows for workspaces..."
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
  # Inject environment variables into pipeline.yml/destroy.yml (workspaces)
  # -------------------------------------------------------------------------
  for FILE in "$WORKFLOWS_DEST/pipeline.yml" "$WORKFLOWS_DEST/destroy.yml"; do
    if [ -f "$FILE" ]; then
      echo "Updating environment variable values in $FILE..."

      # These lines assume the templates have keys like:
      #   AWS_REGION: ""
      #   AWS_ACCOUNT_ID: ""
      #   AWS_ROLE_NAME: ""
      # We'll replace their values.
      if sed --version >/dev/null 2>&1; then
        sed -i "s|^\([[:space:]]*AWS_REGION:\).*|\1 $REGION_NAME|" "$FILE"
        sed -i "s|^\([[:space:]]*AWS_ACCOUNT_ID:\).*|\1 \"$AWS_ACCOUNT_ID\"|" "$FILE"
        sed -i "s|^\([[:space:]]*AWS_ROLE_NAME:\).*|\1 $AWS_ROLE_NAME|" "$FILE"
      else
        sed -i '' "s|^\([[:space:]]*AWS_REGION:\).*|\1 $REGION_NAME|" "$FILE"
        sed -i '' "s|^\([[:space:]]*AWS_ACCOUNT_ID:\).*|\1 \"$AWS_ACCOUNT_ID\"|" "$FILE"
        sed -i '' "s|^\([[:space:]]*AWS_ROLE_NAME:\).*|\1 $AWS_ROLE_NAME|" "$FILE"
      fi

      echo "✅ Environment values replaced successfully in $FILE."
    else
      echo "⚠️ $(basename "$FILE") not found — skipping env replacement."
    fi
  done

  echo
  echo "✅ Project '$PROJECT_NAME' initialized successfully in workspace mode."
  echo "   Backend and terraform.tfvars updated in: $DEST_DIR/"
  echo
  exit 0

# ---------------------------------------------------------------------------
# Invalid mode
# ---------------------------------------------------------------------------
else
  echo "Error: Unknown mode '$MODE'. Use --env-folders or --workspaces." >&2
  exit 1
fi
