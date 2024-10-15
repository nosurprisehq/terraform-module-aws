# Terraform Module AWS
This module creates the required resources from No Surprise at the AWS account.

## How does it works?
The integration between the AWS account and No Surprise is done through a data plane that runs on a Lambda at the AWS
account.

## What are the permissions that No Surprise have in my account?
No Surprise control plane can:
- List users.
- Get, create, update, and delete inline policies on an user.
- Write logs on CloudWatch Logs.

## Is it safe?
Yes. This Terraform module is configured with a very limited set of permissions and it doesn't grant anything more than
the necesary. The communication with the Lambda is authenticated. The control plane is also
[open source](https://github.com/nosurprisehq/aws).

## How can I use this module?
Create an account at No Surprise and get a token.

Create a Terraform project:
```bash
mkdir nosurprise
cd nosurprise
terraform init
```

Add the following content on a `main.tf` file:
```terraform
module "nosurprise" {
  source               = "nosurprisehq/aws/module"
  version              = "0.0.1"
  nosurprise_api_token = "Add the API token here"
}
```
For more details check the
[documentation of the module](https://registry.terraform.io/modules/nosurprisehq/aws/module/latest).

Initialize the project:
```shell
terraform init
```

Set the environment variables to access the AWS account:
```shell
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_DEFAULT_REGION=""
```

Plan and apply the changes:
```shell
# The plan will present all the changes that will be made at the AWS account.
terraform plan

# Apply the previous plan.
terraform apply
```

If you want to completly remove No Surprise from your account:
```shell
terraform destroy
```

Please, be aware that this is just a quick example. Terraform require more things to a production ready deployment,
e.g., saving the state.

## How much this will cost in terms of infrastructure?
It depends on the quantity of users but as a rule of thumb, less than $1 per month.
