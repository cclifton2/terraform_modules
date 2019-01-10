provider "aws" {
  region = "us-west-2"
}

terraform {
  backend "s3" {
    bucket  = "gloom-terraform"
    key     = "aws/lamp/gloom.tfstate"
    encrypt = true
    region  = "us-west-2"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${lookup(var.remote_state_bucket, terraform.workspace)}"
    key    = "${lookup(var.remote_state_vpc_key, terraform.workspace)}"
    region = "${lookup(var.remote_state_region, terraform.workspace)}"
  }
}

module "lamp" {
  # source          = "github.com/gabcoyne/terraform_modules/lamp_demo"
  source              = "modules"
  master_key          = "prod-coyne-key"
  app_instance_count  = 3
  data_instance_count = 3
  web_instance_count  = 3

  # master_key = "${data.terraform_remote_state.vpc.personal_key0}"
}
