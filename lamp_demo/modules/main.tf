data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${lookup(var.remote_state_bucket, terraform.workspace)}"
    key    = "env:/${terraform.workspace}/aws/gloom.tfstate"
    region = "${lookup(var.remote_state_region, terraform.workspace)}"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "app" {
  # source  = "terraform-aws-modules/ec2-instance/aws"
  source  = "../../terraform-aws-ec2-instance"
  version = "1.12.0"

  name           = "application"
  instance_count = "${var.app_instance_count}"

  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "${var.app_instance_type}"
  key_name      = "${var.master_key == "" ? var.master_key : var.app_key_name}"

  monitoring             = true
  vpc_security_group_ids = ["${data.terraform_remote_state.vpc.lamp_sg}"]
  subnet_id              = "${data.terraform_remote_state.vpc.private_subnets[1]}"
  role                   = "app"

  tags = {
    Terraform   = "true"
    Environment = "${terraform.workspace}"
  }
}

module "data" {
  # source  = "terraform-aws-modules/ec2-instance/aws"
  source  = "../../terraform-aws-ec2-instance"
  version = "1.12.0"

  name           = "database"
  instance_count = "${var.data_instance_count}"

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.data_instance_type}"
  key_name               = "${var.master_key == "" ? var.master_key : var.data_key_name}"
  monitoring             = true
  vpc_security_group_ids = ["${data.terraform_remote_state.vpc.lamp_sg}"]
  subnet_id              = "${data.terraform_remote_state.vpc.private_subnets[0]}"
  role                   = "data"

  tags = {
    Terraform   = "true"
    Environment = "${terraform.workspace}"
  }
}

module "web" {
  # source  = "terraform-aws-modules/ec2-instance/aws"
  source  = "../../terraform-aws-ec2-instance"
  version = "1.12.0"

  name           = "web"
  instance_count = "${var.web_instance_count}"

  ami                    = "${data.aws_ami.ubuntu.id}"
  instance_type          = "${var.web_instance_type}"
  key_name               = "${var.master_key == "" ? var.master_key : var.web_key_name}"
  monitoring             = true
  vpc_security_group_ids = ["${data.terraform_remote_state.vpc.lamp_sg}"]
  subnet_id              = "${data.terraform_remote_state.vpc.public_subnets[0]}"

  role = "web"

  tags = {
    Terraform   = "true"
    Environment = "${terraform.workspace}"
  }
}

locals {
  instance_ip   = "${compact(concat(module.web.private_ip, flatten(module.app.private_ip), flatten(module.data.private_ip)))}"
  instance_name = "${compact(concat(flatten(module.web.instance_names), flatten(module.app.instance_names), flatten(module.data.instance_names), flatten(module.web.instance_names_t2), flatten(module.app.instance_names_t2), flatten(module.data.instance_names_t2)))}"
  instance_role = "${compact(concat(flatten(module.web.instance_roles), flatten(module.app.instance_roles), flatten(module.data.instance_roles), flatten(module.web.instance_roles_t2), flatten(module.app.instance_roles_t2), flatten(module.data.instance_roles_t2)))}"
}

# data "template_file" "_ansible_hosts" {
#   count = "${length(local.instance_name)}"
#
#   template = <<JSON
# {$${join(",\n",
#   compact(
#     list(
#     instance_ip == "" ? "" : "$${ jsonencode("instance_ip") }: $${instance_ip}",
#     "$${jsonencode("instance_name")}: $${instance_name}",
#     instance_role == "" ? "" : "$${ jsonencode("instance_role") }: $${jsonencode(instance_role)}"
#     )
#   )
# )}}
# JSON
#
#   vars {
#     instance_ip = "${local.instance_ip[count.index]}"
#
#     # So that TF will throw an error - this is a required field
#     instance_name = "${local.instance_name[count.index]}"
#     instance_role = "${local.instance_role[count.index]}"
#   }
# }
#
# data "template_file" "ansible_hosts" {
#   template = <<JSON
# "servers":{[$${hosts}]}
# JSON
#
#   vars {
#     hosts = "${join(",",data.template_file._ansible_hosts.*.rendered)}"
#   }
# }

