provider "aws" {
  version = "2.19.0"
  region  = var.aws_region
}


terraform {
  backend "s3" {
    bucket = "spash-helloapp"
    key    = "terraform/terraform.tfstate"
    region = "us-west-2"
  }
}

########## AWS account id ###############
data "aws_caller_identity" "current" {
}




