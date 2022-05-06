terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  backend "s3" {
    bucket = "sprint-cloudwatch-alarm-webhook"
    key = "get_alarm_lambda.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "gmail"
  region  = "ap-northeast-2"
}



