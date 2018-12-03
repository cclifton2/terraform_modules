#### VPC outputs based on terraform registry vpc module

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${lookup(var.remote_state_bucket, var.environment)}"
    key    = "${lookup(var.remote_state_vpc_key, var.environment)}"
    region = "${lookup(var.remote_state_region, var.environment)}"
  }
}

data "aws_ami" "ecs_optimized_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-2017.09.l-amazon-ecs-optimized*"]
  }

  owners = ["amazon"]
}

data "aws_caller_identity" "current" {}

data "template_file" "container_defs" {
  template = "${file("${path.module}/container_defs.json")}"

  vars {
    environment = "${var.environment}"
    region      = "${var.region}"
    app_name    = "2048"
  }
}

module "elb" {
  source = "terraform-aws-modules/elb/aws"

  name = "2048-lb"

  subnets             = ["${data.terraform_remote_state.vpc.public_subnets}"]
  security_groups = ["sg-12345678"]
  internal        = false

  listener = [
    {
      instance_port     = "8080"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:8080/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

  access_logs = [
    {
      bucket = "${lookup(var.logging_bucket, var.environment)}"
    },
  ]

  // ELB attachments
  number_of_instances = 2
  instances           = ["i-06ff41a77dfb5349d", "i-4906ff41a77dfb53d"]

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

# module "alb" {
#   source  = "terraform-aws-modules/elb/aws"
#   version = "1.4.1"
#   load_balancer_name  = "2048-demo"
#   security_groups     = ["sg-3187805a"]
#   log_bucket_name     = "${lookup(var.logging_bucket, var.environment)}"
#   log_location_prefix = "alb-2048-demo"
#   subnets             = ["${data.terraform_remote_state.vpc.public_subnets}"]
#
#
#   vpc_id                = "${data.terraform_remote_state.vpc.vpc_id}"
#   https_listeners       = "${list(map("certificate_arn", "${var.ssl_cert}", "port", 443))}"
#   https_listeners_count = "1"
# }


resource "aws_ecr_repository" "this" {
  name = "2048-demo"
}

module "ecs_cluster" {
  #source                             = "../../terraform-modules/ecs_cluster"
  source = "github.com/gabcoyne/terraform_modules/2048"
  target_groups                      = ["${module.alb.target_group_arns}"]
  app_name                           = "2048"
  backup                             = "${var.backup}"
  region                             = "${var.region}"
  environment                        = "${var.environment}"
  ecs_ami                            = "${data.aws_ami.ecs_optimized_ami.image_id}"
  ssh_key_name                       = "${var.ssh_key_name}"
  security_groups                    = ["sg-3187805a"]
  template_file                      = "${data.template_file.container_defs.rendered}"
  subnet_ids                         = ["${data.terraform_remote_state.vpc.public_subnets}"]
  deployment_maximum_percent         = "100"
  deployment_minimum_healthy_percent = "0"
  termination_policies               = ["OldestInstance"]
}

resource "aws_cloudwatch_log_group" "this" {
  name = "2048-demo"

  tags {
    Environment = "${var.environment}"
    Application = "2048"
    Terraform   = true
  }
}
