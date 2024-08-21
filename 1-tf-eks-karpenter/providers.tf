provider "aws" {
  region  = var.region
  profile = var.aws_profile
  default_tags {
    tags = {}
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "opsfleet"
  alias   = "use1"
}

provider "kubectl" {
  apply_retry_count      = 3
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "--profile", var.aws_profile, "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "--profile", var.aws_profile, "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
