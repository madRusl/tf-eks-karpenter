### Task

```
Automate EKS cluster setup with Karpenter and Graviton on AWS

You've joined a new and growing startup.

The company wants to build its initial Kubernetes infrastructure on AWS. The team wants to leverage the latest autoscaling capabilities by Karpenter, as well as utilize Graviton instances for better price/performance

They have asked you if you can help create the following:

Terraform code that deploys an EKS cluster (whatever latest version is currently available) into an existing VPC
The terraform code should also deploy Karpenter with node pool(s) that can deploy both x86 and arm64 instances
Include a short readme that explains how to use the Terraform repo and that also demonstrates how an end-user (a developer from the company) can run a pod/deployment on x86 or Graviton instance inside the cluster.
```

### Terraform

[terraform](terraform) contains a demo deployment of eks and karpenter.

```
cd terraform
terraform init
terraform apply
```

| `terraform.tfvars` is excluded through `.gitignore`, containing sensetive variables

### k8s

[k8s/examples](k8s/examples) contains k8s manifests for 2 scenarios - amd64 and arm64 related k8s workloads.

```
k apply -f k8s/examples/amd64.yaml
k apply -f k8s/examples/arm64.yaml
```