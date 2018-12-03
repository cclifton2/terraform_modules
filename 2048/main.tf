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
  # source                             = "../../terraform-modules/ecs_cluster"                  
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


#
# Container Instance IAM resources
#
data "aws_iam_policy_document" "container_instance_ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "container_instance_ec2" {
  name               = "2048-demo-ec2-role"
  assume_role_policy = "${data.aws_iam_policy_document.container_instance_ec2_assume_role.json}"

  lifecycle {
    ignore_changes = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ec2_service_role" {
  role       = "${aws_iam_role.container_instance_ec2.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "container_instance" {
  name = "${aws_iam_role.container_instance_ec2.name}"
  role = "${aws_iam_role.container_instance_ec2.name}"
}

#
# ECS Service IAM permissions
#

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "2048-demo-ecs-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_task_role" {
  role       = "${aws_iam_role.ecs_task_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "ecs_autoscale_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["application-autoscaling.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ecs_autoscale_role" {
  name               = "2048-demo-ecs-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_autoscale_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_service_autoscaling_role" {
  role       = "${aws_iam_role.ecs_autoscale_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "2048-demo"
}

resource "aws_launch_configuration" "this" {
  name_prefix   = "2048-demo-"
  image_id      = "${var.ecs_ami}"
  instance_type = "${var.ecs_instance_type}"

  key_name                    = "${var.ssh_key_name}"
  security_groups             = ["${var.security_groups}"]
  user_data                   = "#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.container_instance.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name_prefix               = "2048-demo-"
  launch_configuration      = "${aws_launch_configuration.this.name}"
  min_size                  = "${var.ecs_min_nodes}"
  max_size                  = "${var.ecs_max_nodes}"
  desired_capacity          = "${var.desired_count}"
  vpc_zone_identifier       = ["${var.subnet_ids}"]
  target_group_arns         = ["${var.target_groups}"]
  health_check_grace_period = "${var.health_check_grace_period}"

  termination_policies = ["${var.termination_policies}"]

  # Enable all metrics - minimal cost and gives more insight into ASG
  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  tags = [
    {
      key                 = "Name"
      value               = "${aws_ecs_cluster.ecs_cluster.name}"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = "${var.environment}"
      propagate_at_launch = true
    },
    {
      key                 = "Application"
      value               = "2048-demo"
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}
