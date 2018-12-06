# data "terraform_remote_state" "vpc" {
#   backend = "s3"
#
#   config {
#     bucket = "${lookup(var.remote_state_bucket, terraform.workspace)}"
#     key    = "${lookup(var.remote_state_vpc_key, terraform.workspace)}"
#     region = "${lookup(var.remote_state_region, terraform.workspace)}"
#   }
# }

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

######
# ELB
######
module "elb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "1.4.1"

  name = "2048-elb"

  subnets         = "${var.public_subnets}"
  security_groups = ["${var.security_groups}"]
  internal        = false

  listener = [
    {
      instance_port     = "443"
      instance_protocol = "HTTPs"
      lb_port           = "8080"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  # access_logs = [
  #   {
  #     bucket = "gloom logs"
  #   },
  # ]

  // ELB attachments
  // number_of_instances = 2
  // instances           = ["i-06ff41a77dfb5349d", "i-4906ff41a77dfb53d"]

  tags = {
    Environment = "${terraform.workspace}"
  }
}

// module "alb" {
//   source              = "git::git@github.com:contextmedia/terraform-infrastructure-live.git//modules//load_balancer?ref=v1.0.7"
//   load_balancer_name  = "${terraform.workspace}-2048"
//   security_groups     = ["sg-3187805a"]
//   log_bucket_name     = "${lookup(var.logging_bucket, terraform.workspace)}"
//   log_location_prefix = "alb-${terraform.workspace}-2048"
//   subnets             = ["${data.aws_subnet_ids.public.ids}"]

//   tags = "${map("Application", "2048",
//                 "Environment", "${terraform.workspace}",
//                 "Department", "${var.department}",
//                 "Terraform", "true")}"

//   vpc_id                = "${data.terraform_remote_state.vpc.vpc_id}"
//   https_listeners       = "${list(map("certificate_arn", "${var.ssl_cert}", "port", 443))}"
//   https_listeners_count = "1"

//   # Brief deregistration delay - should not have long-running connections
//   target_groups = "${list(map("name", "${terraform.workspace}-2048",
//                               "backend_protocol", "HTTP",
//                               "backend_port", "8080",
//                               "deregistration_delay", "15",
//                               "health_check_path", "/",
//                               "health_check_interval", "15",
//                               "health_check_port", "traffic-port",
//                               "health_check_timeout", "14",
//                               "health_check_healthy_threshold", "3",
//                               "health_check_unhealthy_threshold", "3",
//                               "health_check_matcher", "200-299"))}"

//   target_groups_count = "1"
// }

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
  ssh_key_name                       = "${var.ssh_key_name}"
  security_groups                    = ["${var.security_groups}"]
  template_file                      = "${data.template_file.container_defs.rendered}"
  subnet_ids                         = ["${var.public_subnets}"]
  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "0"
  termination_policies               = ["OldestInstance"]
  service_load_balancer              = "${module.elb.this_elb_id}"
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
  records = ["${module.elb.this_elb_dns_name}"]
}
