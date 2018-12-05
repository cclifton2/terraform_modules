variable region {}

variable "security_groups" {
  type = "list"
}

variable backup {
  default = "Backup"
}

variable "remote_state_bucket" {
  default = {
    "dev"    = "gloom-terraform"
    "stage"  = "gloom-terraform"
    "master" = "gloom-terraform"
  }
}

variable "remote_state_vpc_key" {
  default = {
    "dev"    = "gloom.tfstate"
    "stage"  = "gloom.tfstate"
    "master" = "gloom.tfstate"
  }
}

variable "remote_state_region" {
  default = {
    "dev"    = "us-west-2"
    "stage"  = "us-west-2"
    "master" = "us-west-2"
  }
}

variable ssh_key_name {}

#ALB Variables
variable "logging_bucket" {
  default = {
    "dev"    = "gloom-logging"
    "stage"  = "gloom-logging"
    "master" = "gloom-logging"
  }
}

variable "vpc_id" {
  description = "placeholder until depends on is released in .12"
}
