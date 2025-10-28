# aws-terraform-project-generator

**aws-terraform-project-generator** is a project to deploy basic terraform structure template ready to use with **best practices** and **CI/CD**!
it currently support two structure methodology: `env folders` and `workspaces`.

## Getting Started

Clone the repo:
```bash
git clone git@github.com:Karuch/aws-terraform-project-generator
```

## Generate S3 backend and DynamoDB lock

If you don't have s3 bucket (for remote state) and dynamodb table (for locking the state to prevent simutianisly writes) already
you can use `init_backend` script to creating those:
```
./init_backend/remote_state_init.sh <prefix> <region>
Example: ./init_backend/remote_state_init.sh myproject us-east-1
```
If you already have you can use those later.

## Create project template

Is your project might have different resources across different stages? (e.g prod, dev, staging)
if yes, please use `--env folders`.
```
./project_init/project_init.sh
Example: ./project_init/project_init.sh --env-folders myproject-backend myproject-lock us-east-1 myproject
```

If your project will have the same resources across all stages (e.g prod, dev, staging) and the only  
difference is the values you will use in the variables in each environement, please use `--workspacs`  
note that for `terraform workspace` tfstate file will be created under `env:` directory in the remote state S3 bucket.
```
./project_init/project_init.sh
Example: ./project_init/project_init.sh --workspaces myproject-backend myproject-lock us-east-1 myproject
```

## apply manually

### for `--env-folders` project
apply dev:
```
cd <project_name>/envs/dev
terraform init
terraform plan
terraform apply
```
apply staging:
```
cd <project_name>/envs/staging
terraform init
terraform plan
terraform apply
```
apply prod:
```
cd <project_name>/envs/prod
terraform init
terraform plan
terraform apply
```

### for `--workspaces` project
initiallize project
```
cd <project_name>
terraform init
```
create workspaces
```
terraform workspace new prod
terraform workspace new staging
terraform workspace new dev
```
the current environment is not tied to shell but to `.terraform`,
when you use `terraform workspace select` it will change the current workspace
across all shells.
**make sure you always using `terraform workspace select` before apply! (CI/CD does this automatically)**

plan and apply dev:
```
terraform workspace select dev
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"
```
apply staging:
```
terraform workspace select staging
terraform plan -var-file="vars/staging.tfvars"
terraform apply -var-file="vars/staging.tfvars"
```
apply prod:
```
terraform workspace select prod
terraform plan -var-file="vars/prod.tfvars"
terraform apply -var-file="vars/prod.tfvars"
```

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