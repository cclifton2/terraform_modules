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

variable "app_instance_count" {
  default = "1"
}

variable "data_instance_count" {
  default = "1"
}

variable "web_instance_count" {
  default = "1"
}

variable "app_instance_type" {
  default = "t2.micro"
}

variable "data_instance_type" {
  default = "t2.micro"
}

variable "web_instance_type" {
  default = "t2.micro"
}

variable "master_key" {
  default = ""
}

variable "app_key_name" {
  default = ""
}

variable "web_key_name" {
  default = ""
}

variable "data_key_name" {
  default = ""
}
