# Infrastructure as Code

This directory contains Terraform configuration for the EKS infrastructure.

## Files

- **`eks.tf`** - EKS cluster configuration
- **`vpc.tf`** - VPC with public/private subnets
- **`variables.tf`** - Terraform variables
- **`output.tf`** - Terraform outputs
- **`versions.tf`** - Provider versions
- **`backend.example.tf`** - Backend configuration example
- **`aws-waf-example.tf`** - AWS WAF configuration example

## Usage

1. Configure backend (optional):
   ```bash
   cp backend.example.tf backend.tf
   # Edit backend.tf with your S3 bucket details
   ```

2. Deploy infrastructure:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name eks-interview-lab
   ```

4. Cleanup:
   ```bash
   terraform destroy
   ```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Appropriate AWS permissions for EKS, VPC, and IAM

## Recovering a failed managed node group

EKS module v21 disables automatic self-managed add-on bootstrapping. The
`addons` map in `eks.tf` explicitly installs VPC CNI, kube-proxy, and CoreDNS.
Without VPC CNI, a node can remain `NotReady` and the managed node group can
fail with `NodeCreationFailure: Unhealthy nodes in the kubernetes cluster`.

Before retrying a failed deployment, check the cluster in the region configured
in `terraform.tfvars` (the commands below use `us-east-2`):

```bash
aws eks list-addons --region us-east-2 --cluster-name eks-interview-lab
aws eks describe-nodegroup --region us-east-2 \
  --cluster-name eks-interview-lab \
  --nodegroup-name default-1efb8a261d6adb94d198068905 \
  --query 'nodegroup.{status:status,issues:health.issues}'
```

If VPC CNI is absent, use this one-time recovery step to install it before
retrying the failed node group. Run these commands from this directory and
review each saved plan before applying it:

```bash
terraform plan -target='module.eks.aws_eks_addon.before_compute["vpc-cni"]' -out=cni-recovery.tfplan
terraform apply cni-recovery.tfplan
rm cni-recovery.tfplan
```

Then create a full plan. A node group still in `CREATE_FAILED` needs replacement;
the following requests replacement of only that resource. This terminates its
existing worker instances, so use it only after confirming the group is failed:

```bash
terraform plan -replace='module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]' -out=node-recovery.tfplan
terraform apply node-recovery.tfplan
rm node-recovery.tfplan
```

If the group has recovered to `ACTIVE`, use a normal `terraform plan` and
`terraform apply` instead. Resource targeting above is for recovery only; the
full plan also installs kube-proxy and CoreDNS and reconciles remaining changes.

Verify the result using an AWS identity with cluster access and a host allowed
by `endpoint_public_access_cidrs`, or a host with access to the private endpoint:

```bash
aws eks update-kubeconfig --region us-east-2 --name eks-interview-lab
kubectl get nodes -o wide
kubectl -n kube-system get pods -o wide
```

If nodes remain unhealthy, inspect `kubectl describe node <node-name>` and the
`aws-node` pod logs. If no nodes register, check the private subnet routes and
NAT gateway, DNS, the actual security groups attached by the EKS module, and the
node IAM role. The standalone security groups in `security.tf` are not attached
to the cluster or node group by the current `eks.tf` configuration.
