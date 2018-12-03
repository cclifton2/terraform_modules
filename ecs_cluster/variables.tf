variable "region" {}

variable "environment" {
  description = "OH environment (one of development, qa, staging, uat, production). Defined in app main .tfvars"
}

variable "department" {
  description = "OH department (one of platform, devops, finance, product analytics). Defined in app main .tfvars"
  default     = ""
}

variable "backup" {
  description = "If value is Backup - EBS volumes will be backed up. Defined in app main .tfvars"
  default     = ""
}

variable "app_name" {
  description = "Name of the application. Hyphenated. Defined in app main .tfvars"
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

variable "ecs_ami" {}

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

variable "ssh_key_name" {
  default = ""
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
