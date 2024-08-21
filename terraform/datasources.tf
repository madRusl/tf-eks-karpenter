#################################################################
# Network
#################################################################

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "internal" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

resource "aws_ec2_tag" "this" {
  for_each    = toset(data.aws_subnets.internal.ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
  value       = "*"
}

#################################################################
# ECR
#################################################################

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.use1
}
