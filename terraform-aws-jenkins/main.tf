provider "aws" {
  region = "${var.aws_region}"
}

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config {
    bucket = "${lookup(var.remote_state_bucket, terraform.workspace)}"
    key    = "env:/${terraform.workspace}/aws/gloom.tfstate"
    region = "${lookup(var.remote_state_region, terraform.workspace)}"
  }
}

data "aws_caller_identity" "current_account" {}

data "template_file" "jenkins_master_ami" {
  template = "${file("${path.module}/packer/jenkins-master-ami/packer.json")}"

  vars = {
    jnlp_port = "${var.jnlp_port}"
    plugins   = "${join(" ", var.plugins)}"
  }
}

data "template_file" "jenkins_slave_ami" {
  template = "${file("${path.module}/packer/jenkins-slave-ami/packer.json")}"

  vars = {
    jnlp_port = "${var.jnlp_port}"
    plugins   = "${join(" ", var.plugins)}"
  }
}

resource "null_resource" "jenkins_master" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"
  }

  provisoner "local-exec" {
    command = "g"
  }
}

resource "null_resource" "jenkins_slave" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers {
    cluster_instance_ids = "${join(",", aws_instance.cluster.*.id)}"
  }
}

# Jenkins Master Instance
module "jenkins-master" {
  source = "./modules/jenkins-master"

  vpc_id = "vpc-069291a71af26445c" #"${data.terraform_remote_state.vpc.vpc_id}"

  name          = "${var.name == "" ? "jenkins-master" : join("-", list(var.name, "jenkins-master"))}"
  alb_prefix    = "${var.name == "" ? "jenkins" : join("-", list(var.name, "jenkins"))}"
  instance_type = "${var.instance_type_master}"

  # ami_id     =  #"${var.master_ami_id == "" ? data.aws_ami.jenkins.image_id : var.master_ami_id}"
  user_data  = ""
  setup_data = "${data.template_file.setup_data_master.rendered}"

  http_port                   = "${var.http_port}"
  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "${var.ssh_key_name}"
  ssh_key_path                = "${var.ssh_key_path}"

  # Config used by the Application Load Balancer
  subnet_ids              = "${data.terraform_remote_state.vpc.public_subnets}"
  private_subnets         = "${data.terraform_remote_state.vpc.private_subnets}"
  public_subnets          = "${data.terraform_remote_state.vpc.public_subnets}"
  aws_ssl_certificate_arn = "${var.aws_ssl_certificate_arn}"
  dns_zone                = "${var.dns_zone}"
  app_dns_name            = "${var.app_dns_name}"
}

data "template_file" "setup_data_master" {
  template = "${file("${path.module}/modules/jenkins-master/setup.sh")}"

  vars = {
    jnlp_port = "${var.jnlp_port}"
    plugins   = "${join(" ", var.plugins)}"
  }
}

# Jenkins Linux Slave Instance(s)
module "jenkins-linux-slave" {
  source = "./modules/jenkins-slave"

  count = "${var.linux_slave_count}"

  name          = "${var.name == "" ? "jenkins-linux-slave" : join("-", list(var.name, "jenkins-linux-slave"))}"
  instance_type = "${var.instance_type_slave}"

  ami_id                    = "${var.linux_slave_ami_id}"
  jenkins_security_group_id = "${module.jenkins-master.jenkins_security_group_id}"

  jenkins_master_ip   = "${module.jenkins-master.private_ip}"
  jenkins_master_port = "${var.http_port}"

  ssh_key_name = "${var.ssh_key_name}"
  ssh_key_path = "${var.ssh_key_path}"

  private_subnets = "${data.terraform_remote_state.vpc.private_subnets}"
  public_subnets  = "${data.terraform_remote_state.vpc.public_subnets}"
}

# data "aws_vpc" "default" {
#   default = true
# }

