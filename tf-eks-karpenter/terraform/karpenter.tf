################################################################################
# Karpenter IAM roles & policies & queues
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.15"

  cluster_name           = module.eks.cluster_name
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn
  enable_irsa            = true
  create_access_entry    = true

  enable_pod_identity             = false
  create_pod_identity_association = false

  create_instance_profile       = true
  iam_role_use_name_prefix      = false
  node_iam_role_use_name_prefix = false
  iam_policy_use_name_prefix    = true

  iam_role_name      = "${module.eks.cluster_name}-karpenter-controller-irsa"
  node_iam_role_name = "${module.eks.cluster_name}-karpenter-node-role"

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonSSMPatchAssociation    = "arn:aws:iam::aws:policy/AmazonSSMPatchAssociation"
  }

  tags = local.tags

  depends_on = [
    module.eks
  ]
}

################################################################################
# Karpenter Helm chart & manifests
################################################################################

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "0.37.1"
  create_namespace    = true
  wait                = false

  values = [
    <<-EOT
    postInstallHook:
      image:
        repository: bitnami/kubectl
        tag: "1.30"
        digest: sha256:13210e634b6368173205e8559d7c9216cce13795f28f93c39b1bb8784cac8074
    serviceAccount:
      name: ${module.karpenter.service_account}
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
      enablePodENI: true
    EOT
  ]

  depends_on = [
    module.karpenter
  ]
}
# required for karpenter subnet discovery
resource "aws_ec2_tag" "this" {
  for_each    = toset(data.aws_subnets.internal.ids)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
  value       = "*"
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
      - tags:
          "kubernetes.io/cluster/${module.eks.cluster_name}": "*"
      securityGroupSelectorTerms:
        - tags:
            kubernetes.io/cluster/${module.eks.cluster_name}: "owned"
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: dev
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64", "arm64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand", "spot"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["1", "2", "4"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["4"]
      limits:
        cpu: 16
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 1h
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}
