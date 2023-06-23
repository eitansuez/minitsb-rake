Provisions the VM for running TSB on GCP.

## Prerequisites

- The terraform CLI
- A GCP account and a target GCP project with a service account key

## Steps

Create a `terraform.tfvars` file and in it, specify your gcp project name, and service account key json file name:

```terraform
gcp_project_name = "my-gcp-project"
credentials_filename = "~/.ssh/my-service-account-key.json"
```

Initialize terraform:

```shell
terraform init
```

Apply the terraform:

```shell
terraform apply
```

See the parent directory's readme file for full context.
