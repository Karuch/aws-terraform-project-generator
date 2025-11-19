# aws-terraform-project-generator

**aws-terraform-project-generator** is an automation to deploy basic terraform structure template ready to use with **best practices** and **CI/CD to destroy and apply using OIDC**.  
it currently support two structure methodology: `env folders` and `workspaces`.

<img src="https://i.imgur.com/yfldxXh.png" width="40%">

## Getting Started

**1.** Clone the generator repo:
```bash
git clone git@github.com:Karuch/aws-terraform-project-generator
cd aws-terraform-project-generator
```
Terraform requires an **S3 bucket** (to store the remote state) and a **DynamoDB table** (to provide state locking and prevent simultaneous writes).  
**If you don’t already have those**, you can generate them using the helper script:

See: [Generate S3 backend and DynamoDB lock using `backend_init.sh`](#generate-s3-backend-and-dynamodb-lock-using-backend_initsh)


**2.** generate project template:  

**note: the script support combination of flags and interactive usage**  
**if you forget to mention one of the flags it will ask you for it interactivly**  
**you can also put all the flags interactivly.**  

If your project will have a single backend for all environments (e.g prod, dev, staging)
and the same resources, and the only difference is the values you will use in the variables
in each environement (env.tfvars), please use `--workspaces`:
```bash
# --account-id and --cicd-role are optional and needed for CICD
./project_init/project_init.sh --workspaces \
  --project myProject \
  --bucket myTfstateBucket \
  --dynamodb-table myDynamoDBLockTable \
  --region us-east-1 \
  --account-id 123456789012 \
  --cicd-role myTerrafromApplyRole
```
Is your project might have different resources across different environments OR
you might need different credentials/backends per environment? (different account, region, bucket etc') to deploy resources.
if yes, please use `--env-folders`.  
if you want you can use the same cerdentials/backend in all of the environments, `--env-folders`:
```bash
# --account-id and --cicd-role are optional and needed for CICD
./project_init/project_init.sh --env-folders \
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
```
**3.** cd to the newly created project directory.
```bash
cd ./<project-name>
```
**4. create a git repository for the project**  
**5.** set the newly created project repo as the origin and commit:
```bash
git init -b main
git remote add origin <repository-url>.git
git add .
git commit -m "Initial commit"
```
**6.** push the template to git (to `main/dev/staging` branches):
**you might need to merge changes or `--force`** if you deployed the repo with README.md etc'
```bash
git push -u origin main
```

### Generate S3 backend and DynamoDB lock using `backend_init.sh`

If you don't have s3 bucket (for remote state) and dynamodb table (for locking the state to prevent simutianisly writes) already
you can use `backend_init.sh` script to creating those:
```
./backend_init/backend_init.sh <prefix> <region>
Example: ./backend_init/backend_init.sh myproject us-east-1
```
If you already have you can use those later.

### Terraform apply manually

To apply using CI/CD via OIDC instead (recommended) see: [**Apply using CI/CD**](#generate-s3-backend-and-dynamodb-lock-using-backend_initsh)

#### for `--env-folders` project
<details>
<summary>Preview</summary>

apply dev:
    
    cd <project_name>/envs/dev
    terraform init
    terraform plan
    terraform apply

apply staging:
    
    cd <project_name>/envs/staging
    terraform init
    terraform plan
    terraform apply

apply prod:
    
    cd <project_name>/envs/prod
    terraform init
    terraform plan
    terraform apply
</details>

---

#### for `--workspaces` project
<details>
<summary>Preview</summary>

initialize project
    
    cd <project_name>
    terraform init

create workspaces
    
    terraform workspace new prod
    terraform workspace new staging
    terraform workspace new dev

the current environment is not tied to shell but to `.terraform`,  
when you use `terraform workspace select` it will change the current workspace  
across all shells.  
**make sure you always use `terraform workspace select` before apply! (CI/CD does this automatically)**

plan and apply dev:
    
    terraform workspace select dev
    terraform plan -var-file="vars/dev.tfvars"
    terraform apply -var-file="vars/dev.tfvars"

apply staging:
    
    terraform workspace select staging
    terraform plan -var-file="vars/staging.tfvars"
    terraform apply -var-file="vars/staging.tfvars"

apply prod:
    
    terraform workspace select prod
    terraform plan -var-file="vars/prod.tfvars"
    terraform apply -var-file="vars/prod.tfvars"
</details>

### Terraform apply using CI/CD (recommended)

**The branch names must be `main/prod` or `staging` or `dev`.**  

The `Checkov` security scan will fail the CI/CD while scanning `vpc` and `ec2` modules.  
to skip you must add `|| true` in `pipeline.yml` in the `Run Checkov Scan` step commands.  

The `project_init.sh` script generate automatically github workflow files under `project/.github/workflows`  
`pipeline.yml`: used for build, test, scan, deploy your terraform code.  
`destroy.yml`: used for terraform destroy.  
both works differently according to the mode you used to generate the project
folder (`--workspaces`, `--env-folders`).  
and also **both need OIDC configured** to use terraform apply and terraform destroy.
<details>
<summary>Create OIDC provider if not exist</summary>
Create OIDC provider for github actions if not exist:

    aws iam create-open-id-connect-provider \
      --url "https://token.actions.githubusercontent.com" \
      --client-id-list "sts.amazonaws.com"
</details>

---

<details>
<summary>Create IAM policy</summary>

Create a policy file with the required backend permissions  
(add more actions if your Terraform code deploys other AWS resources).  
**make sure to change the fields there `<ACCOUNT_ID>, <S3_BUCKET_NAME>, <DDB_LOCK_TABLE_NAME>, <REGION>`.**

    cat > terraform-backend-policy.json <<'EOF'
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ],
          "Resource": [
            "arn:aws:s3:::<S3_BUCKET_NAME>",
            "arn:aws:s3:::<S3_BUCKET_NAME>/*"
          ]
        },
        {
          "Effect": "Allow",
          "Action": [
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable"
          ],
          "Resource": "arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/<DDB_LOCK_TABLE_NAME>"
        }
      ]
    }
    EOF
</details>

---

<details>
<summary>Create Trust policy for the IAM role</summary>

**make sure to change the fields there `<ACCOUNT_ID>, <ORG>, <REPO>`.**

    cat > trust-policy.json <<'EOF'
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
            },
            "StringLike": {
              "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:*"
            }
          }
        }
      ]
    }
    EOF
</details>

---

<details>
<summary>Create IAM role for the CI/CD pipeline</summary>

    aws iam create-role \
      --role-name <ROLE_NAME> \
      --assume-role-policy-document file://trust-policy.json
</details>

---

<details>
<summary>Create and attach IAM policy to the role</summary>

**make sure to change the fields there `<ROLE_NAME>, <POLICY_NAME>`.**

    aws iam put-role-policy \
      --role-name <ROLE_NAME> \
      --policy-name <POLICY_NAME> \
      --policy-document file://terraform-backend-policy.json
</details>

## Generate subnets easily using the built in `subnet_generator` module (optional)

in `modules/subnet_generator` you've got main.tf with:
```hcl
resource "aws_subnet" "public" {
  count             = var.public_subnet_count
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index)
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-public-${count.index}"
  }

  # do not remove this comment! vvv - Checkov false positive bypass
  # checkov:skip=CKV_AWS_130:Public subnet requires public IP mapping
}


resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index + var.public_subnet_count)
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-${var.environment}-${var.component}-private-${count.index}"
  }
}
```

### Variables

| Variable                | Description                                                 | Example                                      |
| ----------------------- | ----------------------------------------------------------- | -------------------------------------------- |
| `vpc_cidr`              | Base CIDR block for the VPC                                | "10.0.0.0/16"                                 |
| `availability_zones`    | List of AZs to distribute subnets in round-robin           | ["us-east-1a", "us-east-1b"]                  |
| `public_subnet_count`   | Number of public subnets to create                          | 2                                             |
| `private_subnet_count`  | Number of private subnets to create                         | 2                                             |
| `subnet_newbits`        | Bits added to split the VPC network into subnets            | 4                                             |

---

## How subnet allocation works

Public subnets use index:

0 ... public_subnet_count - 1

Private subnets start AFTER the public range:

index + public_subnet_count

This guarantees **no CIDR overlap**.

---

## Example

vpc_cidr             = "10.0.0.0/16"  
public_subnet_count  = 2  
private_subnet_count = 2  
subnet_newbits       = 4  

The resulting subnet prefix is:

/16 + 4 = /20

Terraform creates:

Public Subnets:
| Subnet | CIDR Block   | Availability Zone |
| ------ | ------------ | ----------------- |
| 0      | 10.0.0.0/20  | us-east-1a        |
| 1      | 10.0.16.0/20 | us-east-1b        |

Private Subnets:  
| Subnet | CIDR Block    | Availability Zone |
| ------ | ------------- | ----------------- |
| 0      | 10.0.32.0/20  | us-east-1a        |
| 1      | 10.0.48.0/20  | us-east-1b        |

(Private subnets begin at index 2 because public_subnet_count = 2)

---

### Understanding `subnet_newbits`

`subnet_newbits` controls how many subnet divisions are possible inside the VPC block.

| Newbits | Resulting Prefix | Max Possible Subnets | IPs per Subnet |
| :-----: | :--------------- | :------------------- | :------------- |
|   0     | /16              | 1                    | 65536          |
|   1     | /17              | 2                    | 32768          |
|   2     | /18              | 4                    | 16384          |
|   3     | /19              | 8                    | 8192           |
|   4     | /20              | 16                   | 4096           |

Even though `/20` supports **16 total subnets**, Terraform only creates:

public_subnet_count + private_subnet_count

---

## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/Feature`)
3. Commit your Changes (`git commit -m 'Add some feature'`)
4. Push to the Branch (`git push origin feature/Feature`)
5. Open a Pull Request

## License

Distributed under the Apache License 2.0. See `LICENSE.txt` for more information.

## Contact & Credits

**Tal Karucci**  
Email: talk474747@gmail.com  
Linkedin: [www.linkedin.com/in/tal-karucci](https://www.linkedin.com/in/tal-karucci-678286290)  


special thanks for my colleague for the help and testing:  
**Aharon Ulano**  
Linkedin: [www.linkedin.com/in/aharon-ulano](https://www.linkedin.com/in/aharon-ulano-861222264/)  