# Local author checks (optional)

These checks are separate from the assignment's four-command student workflow. They use Terraform's mocked AWS provider and create **no AWS resources**. They still need the provider downloaded by initialization.

```text
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
```

Run from the project root, with Terraform 1.7+ and the committed lock file. No real AWS credentials are required by the mocked tests.

The tests verify instance type, the selected existing subnet, public IP assignment, association with the existing VPC, public HTTP and configurable SSH ingress, encrypted root disk deletion, key usage, replacement on user-data changes, and startup commands/content. They verify public SSH works by default without a personal IP. Negative tests reject malformed IPv4 CIDRs and an empty key name.

Mock checks do not prove regional AMI availability, IAM permissions, VPC routes/ACLs, package repository access, actual Nginx startup, or live teardown. The deployment guide and real screenshots supply that evidence. The bootstrap also fails on command errors and checks the Nginx configuration, active service and exact HTML text.
