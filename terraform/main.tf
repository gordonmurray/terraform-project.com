terraform {

  required_version = "1.10.5"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "6.7.0"
    }

  }

}

provider "aws" {
  region                   = var.region
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "gordonmurray"

  default_tags {
    tags = {
      Name = var.default_tag
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
