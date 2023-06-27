module "vpc" {
  source= "git::https://github.com/PranathiAT/tf-module-vpc.git"

  for_each = var.vpc
  cidr_block = each.value["cidr_block"]
  subnets = each.value["subnets"]
  tags = local.tags
  env = var.env
  default_vpc_id = var.default_vpc_id
  default_vpc_cidr = var.default_vpc_cidr
  default_vpc_rtid = var.default_vpc_rtid
}


module "docdb"{
  source= "git::https://github.com/PranathiAT/tf-module-docdb.git"

  for_each = var.docdb
  subnets = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  allow_db_cidr = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_db_cidr"], null), "subnet_cidrs", null)
  kms_arn = var.kms_arn
  engine_version = each.value["engine_version"]
  instance_count = each.value["instance_count"]
  instance_class = each.value["instance_class"]

  tags = local.tags
  env = var.env
  vpc_id = local.vpc_id


}


module "rds"{
  source= "git::https://github.com/PranathiAT/tf-module-rds.git"

  for_each = var.rds
  subnets = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  allow_db_cidr = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_db_cidr"], null), "subnet_cidrs", null)
  kms_arn = var.kms_arn
  engine_version = each.value["engine_version"]
  instance_count = each.value["instance_count"]
  instance_class = each.value["instance_class"]

  tags = local.tags
  env = var.env
  vpc_id = local.vpc_id

}


module "elasticache"{
  source= "git::https://github.com/PranathiAT/tf-module-elasticache.git"

  for_each = var.elasticache
  subnets = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  allow_db_cidr = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_db_cidr"], null), "subnet_cidrs", null)
  kms_arn = var.kms_arn
  engine_version = each.value["engine_version"]
  replicas_per_node_group = each.value["replicas_per_node_group"]
  num_node_groups = each.value["num_node_groups"]
  node_type = each.value["node_type"]
  tags = local.tags
  env = var.env
  vpc_id = local.vpc_id

}

module "rabbitmq"{
  source= "git::https://github.com/PranathiAT/tf-module-amazon-mq.git"

  for_each = var.rabbitmq
  subnets = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  allow_db_cidr = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_db_cidr"], null), "subnet_cidrs", null)
  kms_arn = var.kms_arn
  instance_type = each.value["instance_type"]
  tags = local.tags
  env = var.env
  vpc_id = local.vpc_id
  bastion_cidr = var.bastion_cidr
  domain_id = var.domain_id
}

module "alb"{
  source= "git::https://github.com/PranathiAT/tf-module-alb.git"

  for_each = var.alb
  subnets = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  allow_alb_cidr = each.value["name"]== "public" ? ["0.0.0.0/0"] :concat(lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_alb_cidr"], null), "subnet_cidrs", null),lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), "app", null), "subnet_cidrs", null))
  internal = each.value["internal"]
  name = each.value["name"]
  tags = local.tags
  env = var.env
  vpc_id = local.vpc_id

}

module "app" {
  depends_on = [module.vpc,module.alb,module.docdb,module.rabbitmq,module.elasticache,module.rds]
  source= "git::https://github.com/PranathiAT/tf-module-app.git"

  for_each = var.app
  instance_type = each.value["instance_type"]
  name = each.value["name"]
  desired_capacity = each.value["desired_capacity"]
  max_size = each.value["max_size"]
  min_size = each.value["min_size"]
  app_port = each.value["app_port"]
  listener_priority = each.value["listener_priority"]
  dns_name          = each.value["name"] == "frontend" ? each.value["dns_name"] : "${each.value["name"]}-${var.env}"
  parameters = each.value["parameters"]

  env = var.env
  bastion_cidr = var.bastion_cidr
  tags = merge(local.tags,{Monitor = "true"})
  domain_name = var.domain_name
  domain_id = var.domain_id
  kms_arn = var.kms_arn
  monitor_cidr = var.monitor_cidr

  subnet_ids     = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["subnet_name"], null), "subnet_ids", null)
  vpc_id =lookup(lookup(module.vpc, "main" , null ), "vpc_id" , null)
  allow_app_cidr = lookup(lookup(lookup(lookup(module.vpc, "main", null), "subnets", null), each.value["allow_app_cidr"], null), "subnet_cidrs", null)
  listener_arn = lookup(lookup(module.alb, each.value["lb_type"] , null ), "listener_arn" , null)
  lb_dns_name = lookup(lookup(module.alb, each.value["lb_type"] , null ), "dns_name" , null)
}

#### Load Runner
data "aws_ami" "ami" {
  most_recent = true
  name_regex  = "Centos-8-DevOps-Practice"
  owners      = ["973714476881"]
}

resource "aws_instance" "load" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.medium"
  vpc_security_group_ids = ["sg-0e469a040afeac7ab"]
  tags = {
    Name = "load-runner"
  }
}

resource "null_resource" "load" {
  provisioner "remote-exec" {

    connection {
      host     = aws_instance.load.private_ip
      user     = "root"
      password = "DevOps321"
    }

    inline = [
      "curl -s https://raw.githubusercontent.com/linuxautomations/labautomation/master/tools/docker/install.sh | bash",
      "docker pull robotshop/rs-load"
    ]


  }
} 