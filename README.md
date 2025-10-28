# aws-terraform-project-generator

aws-terraform-project-generator is a project to deploy basic terraform structure template ready to use with **best practices** and **CI/CD**!
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
```
./project_init/project_init.sh
Example: ./project_init/project_init.sh --workspaces myproject-backend myproject-lock us-east-1 myproject
```

## apply manually

### for `--env-folders` project
apply dev:
```
cd <project_name>/envs/dev
terraform init -reconfigure
terraform plan
terraform apply
```
apply staging:
```
cd <project_name>/envs/staging
terraform init -reconfigure
terraform plan
terraform apply
```
apply prod:
```
cd <project_name>/envs/prod
terraform init -reconfigure
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
Project Link: [github.com/Karuch/aws-ezLogin](https://github.com/Karuch/aws-ezLogin)
