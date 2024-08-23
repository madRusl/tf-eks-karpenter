locals {
  cluster_name = "${var.application}-${var.environment}"
  access_entries_map = {
    cluster_admin = {
      kubernetes_groups = []
      principal_arn     = var.cluster_admin_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    kube-proxy = {
      addon_version     = "v1.30.0-eksbuild.3"
      resolve_conflicts = "OVERWRITE"
    }
    coredns = {
      addon_version     = "v1.11.1-eksbuild.8"
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version     = "v1.18.1-eksbuild.3"
      resolve_conflicts = "OVERWRITE"
    }
  }

  tags = merge(
    var.tags_default,
    var.tags_additional
  )
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  create          = var.create_eks
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = data.aws_vpc.selected.id
  subnet_ids = data.aws_subnets.internal.ids

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = flatten([
    var.custom_public_access_cidr
  ])

  access_entries = local.access_entries_map

  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_group_retention_in_days
  cluster_enabled_log_types              = var.cluster_enabled_log_types

  cluster_addons = local.cluster_addons

  eks_managed_node_group_defaults = {
    iam_role_attach_cni_policy = true
    enable_monitoring          = true
    create_node_security_group = true

    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      AmazonSSMPatchAssociation    = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
    }

    update_config = {
      max_unavailable = 1
    }
  }

  eks_managed_node_groups = {
    karpenter = {
      max_size     = 4
      min_size     = 2
      desired_size = 2

      subnet_ids     = tolist(data.aws_subnets.internal.ids)
      capacity_type  = "ON_DEMAND"
      instance_types = [lookup(var.worker_instance_type, "karpenter")]

      ami_type = "AL2_ARM_64"
      taints = {
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }

      labels = tomap({ "workload" = "karpenter" })
      tags = tomap(merge(
        { "Name" = "${local.cluster_name}-karpenter" },
        { "karpenter.sh/discovery" = local.cluster_name }
      ))
    },
  }

  cluster_security_group_additional_rules = {
    ingress_443 = {
      description = "Ingress 443/tcp from vpc/personal"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = flatten([
        "${data.aws_vpc.selected.cidr_block}",
        var.custom_public_access_cidr
      ])
    }
  }
  node_security_group_additional_rules = {
    ingress_22 = {
      description = "Ingress 22/tcp from vpc/personal"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = flatten([
        "${data.aws_vpc.selected.cidr_block}",
        var.custom_public_access_cidr
      ])
    }
  }
  node_security_group_tags = tomap(merge(
    { "karpenter.sh/discovery" = local.cluster_name },
    local.tags
  ))

  tags = local.tags
}
