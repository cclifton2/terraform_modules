variable region {}

variable "security_groups" {
  type = "list"
}

variable "backup" {
  default = "Backup"
}

variable "ssl_cert" {}

variable "remote_state_bucket" {
  default = {
    "dev"   = "gloom-terraform"
    "stage" = "gloom-terraform"
    "prod"  = "gloom-terraform"
  }
}

variable "remote_state_vpc_key" {
  default = {
    "dev"   = "aws/gloom.tfstate"
    "stage" = "aws/gloom.tfstate"
    "prod"  = "aws/gloom.tfstate"
  }
}

variable "remote_state_region" {
  default = {
    "dev"   = "us-west-2"
    "stage" = "us-west-2"
    "prod"  = "us-west-2"
  }
}

variable ssh_key_name {}

#ALB Variables
variable "logging_bucket" {
  default = {
    "dev"   = "gloom-logging"
    "stage" = "gloom-logging"
    "prod"  = "gloom-logging"
  }
}

variable "public_subnets" {
  type = "list"
}

variable "vpc_id" {
  description = "placeholder until depends on is released in .12"
}
