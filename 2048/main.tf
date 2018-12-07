data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${lookup(var.remote_state_bucket, terraform.workspace)}"
    key    = "env:/${terraform.workspace}/aws/gloom.tfstate"
    region = "${lookup(var.remote_state_region, terraform.workspace)}"
  }
}

data "template_file" "container_defs" {
  template = "${file("${path.module}/container_defs.json")}"

  vars {
    environment = "${terraform.workspace}"
    region      = "${var.region}"
  }
}

data "aws_caller_identity" "current_account" {}

data "aws_route53_zone" "this" {
  name = "coyne.link"
}

data "aws_acm_certificate" "coyne_link" {
  domain   = "coyne.link"
  statuses = ["ISSUED"]
}

module "alb" {
  source                   = "terraform-aws-modules/alb/aws"
  load_balancer_name       = "${terraform.workspace}-2048"
  subnets                  = "${data.terraform_remote_state.vpc.public_subnets}"
  security_groups          = ["${data.terraform_remote_state.vpc.2048_sg}"]
  log_bucket_name          = "${var.logging_enabled == "true" ? lookup(var.logging_bucket, terraform.workspace) : ""}"
  tags                     = "${map("Environment", "${terraform.workspace}")}"
  vpc_id                   = "${data.terraform_remote_state.vpc.vpc_id}"
  https_listeners          = "${list(map("certificate_arn", "${data.aws_acm_certificate.coyne_link.arn}", "port", 443))}"
  https_listeners_count    = "1"
  http_tcp_listeners       = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count = "1"
  target_groups            = "${list(map("name", "2048-target-group", "backend_protocol", "HTTP", "backend_port", "8080"))}"
  target_groups_count      = "1"
  logging_enabled          = "${var.logging_enabled == "true" ? "true" : "false"}"
}

data "aws_ami" "ecs_optimized_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2017.09.l-amazon-ecs-optimized*"]
  }

  owners = ["amazon"]
}

resource "aws_ecr_repository" "ecr_repo" {
  name = "${terraform.workspace}-2048"
}

module "ecs_cluster" {
  source = "github.com/gabcoyne/terraform_modules/ecs_cluster"

  # source                             = "../../terraform-modules/ecs_cluster"
  app_name                           = "2048"
  backup                             = "${var.backup}"
  region                             = "${var.region}"
  environment                        = "${terraform.workspace}"
  ecs_ami                            = "${data.aws_ami.ecs_optimized_ami.image_id}"
  ssh_key_name                       = "${data.terraform_remote_state.vpc.personal_key0}"
  security_groups                    = ["${data.terraform_remote_state.vpc.2048_sg}"]
  template_file                      = "${data.template_file.container_defs.rendered}"
  subnet_ids                         = ["${data.terraform_remote_state.vpc.public_subnets}"]
  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "0"
  termination_policies               = ["OldestInstance"]
  service_load_balancer              = "${map("target_group_arn", module.alb.target_group_arns[0], "container_name", "2048", "container_port", "80")}"
}

resource "aws_cloudwatch_log_group" "app_cloudwatch_log_group" {
  name = "${terraform.workspace}-2048"

  tags {
    Environment = "${terraform.workspace}"
    Application = "2048"
    Terraform   = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.this.zone_id}"
  name    = "2048.coyne.link"
  type    = "CNAME"
  ttl     = "60"
  records = ["${module.alb.dns_name}"]
}
