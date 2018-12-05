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
  name               = "${terraform.workspace}-${var.app_name}-ec2-role"
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
  name               = "${terraform.workspace}-${var.app_name}-ecs-task-role"
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
  name               = "${terraform.workspace}-${var.app_name}-ecs-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_autoscale_assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_service_autoscaling_role" {
  role       = "${aws_iam_role.ecs_autoscale_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${terraform.workspace}-${var.app_name}"
}

resource "aws_launch_configuration" "lc" {
  name_prefix   = "${terraform.workspace}-${var.app_name}-"
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

resource "aws_autoscaling_group" "create_asg" {
  name_prefix               = "${terraform.workspace}-${var.app_name}-"
  launch_configuration      = "${aws_launch_configuration.lc.name}"
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
      value               = "${terraform.workspace}"
      propagate_at_launch = true
    },
    {
      key                 = "Backup"
      value               = "${var.backup}"
      propagate_at_launch = true
    },
    {
      key                 = "Application"
      value               = "${terraform.workspace}-${var.app_name}"
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_task_definition" "task_def" {
  family                = "${terraform.workspace}-${var.app_name}"
  network_mode          = "bridge"
  task_role_arn         = "${aws_iam_role.ecs_task_role.arn}"
  container_definitions = "${var.template_file}"

  volume = ["${var.task_volume}"]
}

# Use the current revision in AWS to determine which to use for the service - we don't want to override with Terraform (if you want to do this, comment this out, comment out task_definition below)
data "aws_ecs_task_definition" "current_task_defn" {
  task_definition = "${terraform.workspace}-${var.app_name}"

  depends_on = ["aws_ecs_task_definition.task_def"]
}

resource "aws_ecs_service" "ecs_service" {
  name                               = "${terraform.workspace}-${var.app_name}"
  task_definition                    = "${aws_ecs_task_definition.task_def.family}:${aws_ecs_task_definition.task_def.revision}"
  desired_count                      = "${var.desired_count}"
  cluster                            = "${aws_ecs_cluster.ecs_cluster.arn}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"

  load_balancer {
    target_group_arn = "${lookup(var.service_load_balancer, "target_group_arn")}"
    container_name   = "${lookup(var.service_load_balancer, "container_name")}"
    container_port   = "${lookup(var.service_load_balancer, "container_port")}"
  }

  # TODO: want to be able to call this way. Wait for https://github.com/hashicorp/terraform/issues/17968
  #load_balancer = ["${var.service_load_balancer}"]

  depends_on = ["aws_ecs_task_definition.task_def"]
}
