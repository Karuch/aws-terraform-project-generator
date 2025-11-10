# aws-terraform-project-generator

**aws-terraform-project-generator** is a project to deploy basic terraform structure template ready to use with **best practices** and **CI/CD**!
it currently support two structure methodology: `env folders` and `workspaces`.

## Getting Started

1. Clone the generator repo:
```bash
git clone git@github.com:Karuch/aws-terraform-project-generator
cd aws-terraform-project-generator
```
2. generate project template:  
Is your project might have different resources across different stages? (e.g prod, dev, staging)  
if yes, please use `--env-folders`:
```
# --acount-id and --cicd-role are optional and needed for CICD
./project_init/project_init.sh \
  --env-folders \
  --bucket backend-bucket-name \
  --dynamodb-table lock-table-name \
  --region us-east-1 \
  --project myproject \
  --account-id 012345678910 \
  --cicd-role terraform-apply-role
```
If your project will have the same resources across all stages (e.g prod, dev, staging) and the only  
difference is the values you will use in the variables in each environement, please use `--workspacs`:
```
# --acount-id and --cicd-role are optional and needed for CICD
./project_init/project_init.sh \
  --workspaces \
  --bucket backend-bucket-name \
  --dynamodb-table lock-table-name \
  --region us-east-1 \
  --project myproject \
  --account-id 012345678910 \
  --cicd-role terraform-apply-role
```
3. cd to the newly created project directory.
```
cd ./<project-name>
```
4. create a git repository for the project
5. set the newly created project repo as the origin:
```
git init -b dev
git remote set-url origin <project_repostiroy>.git
git commit -m "Initial commit"
```
6. push the template to git (to `main/dev/staging` branches):
```
git push -u origin dev
```

### Generate S3 backend and DynamoDB lock using `backend_init.sh`

If you don't have s3 bucket (for remote state) and dynamodb table (for locking the state to prevent simutianisly writes) already
you can use `backend_init.sh` script to creating those:
```
./init_backend/remote_state_init.sh <prefix> <region>
Example: ./init_backend/remote_state_init.sh myproject us-east-1
```
If you already have you can use those later.

### Terraform apply manually

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

note that CI/CD will run automatically each time you commit something to `dev/main/staging`.
<details>
<summary>Create OIDC provider if not exist</summary>
Create OIDC provider for github actions if not exist:

    aws iam create-open-id-connect-provider \
      --url "https://token.actions.githubusercontent.com" \
      --client-id-list "sts.amazonaws.com
</details>

---

<details>
<summary>Create IAM policy</summary>

Create a policy file with the required backend permissions  
(add more actions if your Terraform code deploys other AWS resources).

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
            "arn:aws:s3:::<S3_BUCKET>",
            "arn:aws:s3:::<S3_BUCKET>/*"
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
          "Resource": "arn:aws:dynamodb:<REGION>:<ACCOUNT_ID>:table/<DDB_LOCK_TABLE>"
        }
      ]
    }
    EOF
</details>

---

<details>
<summary>Create Trust policy for the IAM role</summary>

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
              "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:ref:refs/heads/<BRANCH>"
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
<summary>Attach IAM policy to the role</summary>

    aws iam put-role-policy \
      --role-name <ROLE_NAME> \
      --policy-name <POLICY_NAME> \
      --policy-document file://terraform-backend-policy.json
</details>

## Generate subnets easily using the built in VPC module

in `modules/vpc`  you've got main.tf with:
```
resource "aws_subnet" "subnets" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, var.subnet_newbits, count.index)
  availability_zone = element(var.availability_zones, count.index % length(var.availability_zones))

  tags = {
    Name        = "${var.project}-${var.environment}-${var.component}-${count.index}"
  }
}
```
| Variable             | Description                                                      | Example                                      |
| -------------------- | ---------------------------------------------------------------- | -------------------------------------------- |
| `vpc_cidr`           | Base CIDR block for the VPC                                      | `"10.0.0.0/16"`                              |
| `availability_zones` | List of AZs to spread subnets across in a round robin            | `["us-east-1a", "us-east-1b", "us-east-1c"]` |
| `subnet_count`       | Total number of subnets to create                                | `6`                                          |
| `subnet_newbits`     | How many bits to add to split the main CIDR into smaller subnets | `4`                                          |

This configuration creates 4 subnets within your VPC.
| Subnet | CIDR Block   | Availability Zone |
| :----- | :----------- | :---------------- |
| 0      | 10.1.0.0/20  | us-east-1a        |
| 1      | 10.1.16.0/20 | us-east-1b        |
| 2      | 10.1.32.0/20 | us-east-1c        |
| 3      | 10.1.48.0/20 | us-east-1a        |

| Newbits | Resulting Prefix | # of Subnets | IPs per Subnet |
| :-----: | :--------------- | :----------- | :------------- |
|    0    | /16              | 1            | 65,536         |
|    1    | /17              | 2            | 32,768         |
|    2    | /18              | 4            | 16,384         |
|    3    | /19              | 8            | 8,192          |
|    4    | /20              | 16           | 4,096          |

## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/Feature`)
3. Commit your Changes (`git commit -m 'Add some feature'`)
4. Push to the Branch (`git push origin feature/Feature`)
5. Open a Pull Request

## License

Distributed under the Apache License 2.0. See `LICENSE.txt` for more information.

## Contact

Email: talk474747@gmail.com  
Linkedin: [www.linkedin.com/in/tal-karucci](https://www.linkedin.com/in/tal-karucci-678286290)  
Project Link: [github.com/Karuch/aws-terraform-project-generator](https://github.com/Karuch/aws-terraform-project-generator)