variable region {}
variable environment {}

variable "remote_state_bucket" {
  default = "gloom-terraform"
}

variable "remote_state_vpc_key" {
  default = "dev/vpc/terraform.tfstate"
}

variable "remote_state_region" {
  default = "us-west-2"
}

variable ssl_cert {}

variable ssh_key_name {}

#ALB Variables
variable "logging_bucket" {
  default = {
    "dev"        = "gloom-terraform"
    "staging"    = "gloom-terraform"
    "production" = "gloom-terraform"
  }
}

variable "region" {}

variable "backup" {
  description = "If value is Backup - EBS volumes will be backed up. Defined in app main .tfvars"
  default     = ""
}

variable "ecs_instance_type" {
  default = "t2.small"
}

variable "ecs_instance_root_disk_size" {
  default = "100G"
}

variable "ecs_min_nodes" {
  default = "1"
}

variable "ecs_max_nodes" {
  default = "2"
}

variable "desired_count" {
  default = "1"
}

variable "target_groups" {
  default = []
}

variable "template_file" {}

variable "subnet_ids" {
  type = "list"
}

variable "security_groups" {
  type    = "list"
  default = []
}

variable "deployment_maximum_percent" {
  default = "100"
}

variable "deployment_minimum_healthy_percent" {
  default = "0"
}

variable "health_check_grace_period" {
  default = "300"
}

variable "termination_policies" {
  type    = "list"
  default = ["OldestInstance"]
}

# TODO: create a volume by default - while this is not ideal, there doesn't appear to be an easy way
# around being able to set/not set volumes at will
variable "task_volume" {
  type = "map"

  default = {
    "name" = "task-volume"
  }
}

variable "service_load_balancer" {
  type = "map"
}
