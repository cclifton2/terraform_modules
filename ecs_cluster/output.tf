#output "aws_ecs_task_definition_revision" {
#value = ["${aws_ecs_task_definition.task_def.revision}"]
#}

output "id" {
  value = "${aws_ecs_cluster.ecs_cluster.id}"
}

output "name" {
  value = "${aws_ecs_cluster.ecs_cluster.name}"
}

output "container_instance_ecs_for_ec2_service_role_name" {
  value = "${aws_iam_role.container_instance_ec2.name}"
}

output "ecs_task_role_name" {
  value = "${aws_iam_role.ecs_task_role.name}"
}

output "ecs_autoscale_role_name" {
  value = "${aws_iam_role.ecs_autoscale_role.name}"
}

output "ecs_task_role_arn" {
  value = "${aws_iam_role.ecs_task_role.arn}"
}

output "ecs_autoscale_role_arn" {
  value = "${aws_iam_role.ecs_autoscale_role.arn}"
}

output "autoscaling_group_name" {
  value = "${aws_autoscaling_group.create_asg.name}"
}
