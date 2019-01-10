# output "ansible_hosts" {
#   value = "${data.template_file.ansible_hosts.rendered}"
# }

output "tags" {
  value = "${module.web.tags}"
}

# output "servers" {
#   value ="${compact(concat("web", module.web.id, module.web.private_ip, "app", module.app.id, module.app.private_ip, "data", module.data.id, module.data.private_ip))}"
# }

output "server_ips" {
  value = "${compact(concat(coalescelist(module.web.private_ip, module.app.private_ip, module.data.private_ip)))}"
}

# output "server_names" {
#   value = "${compact(concat(coalescelist(module.web.name, module.app.name, module.data.name)))}"
#
# }


# output "server_roles" {
#   value = "${compact(concat(coalescelist(module.web.role, module.app.role, module.data.role)))}"
# }

