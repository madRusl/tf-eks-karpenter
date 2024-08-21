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

#################################################################
# ECR
#################################################################

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.use1
}
