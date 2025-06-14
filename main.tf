terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "ditto-sandbox1"
    key    = "terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# サンプルS3バケット
resource "aws_s3_bucket" "sandbox1" {
  bucket = "ditto-sandbox1-testbucket"
}
