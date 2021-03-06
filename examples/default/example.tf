provider "aws" {
  version = "1.30.0"
  region  = "eu-west-1"
}

locals {
  name_prefix = "grafana-test"
  username    = "admin"
  password    = "changeme"

  auth_anonymous_enabled            = true
  auth_anonymous_role               = "Admin"
  auth_basic_enabled                = false
  server_protocol                   = "http"
  users_allow_org_create            = true
  grafana_plugins_enabled           = true
  public_port                       = 80
  task_container_port               = 3000
  rds_instance_type                 = "db.m3.medium"
  rds_instance_engine               = "postgres"
  rds_instance_multi_az             = false
  rds_instance_port                 = "5432"
  rds_instance_username             = "root"
  rds_instance_password             = "changeme"
  desired_count                     = 1
  assign_public_ip                  = true
  health_check_grace_period_seconds = 6000

  tags = {
    terraform   = "true"
    environment = "stage"
    application = "grafana"
  }
}

data "aws_vpc" "main" {
  default = true
}

data "aws_subnet_ids" "main" {
  vpc_id = "${data.aws_vpc.main.id}"
}

module "alb" {
  source  = "telia-oss/loadbalancer/aws"
  version = "0.1.1"

  name_prefix = "${local.name_prefix}"
  type        = "application"
  internal    = "false"
  vpc_id      = "${data.aws_vpc.main.id}"
  subnet_ids  = "${data.aws_subnet_ids.main.ids}"

  tags {
    environment = "test"
    terraform   = "true"
  }
}

module "rds_instance" {
  source  = "telia-oss/rds-instance/aws"
  version = "0.2.0"

  name_prefix   = "${local.name_prefix}"
  username      = "${local.rds_instance_username}"
  password      = "${local.rds_instance_password}"
  database_name = "grafana"
  subnet_ids    = "${data.aws_subnet_ids.main.ids}"
  vpc_id        = "${data.aws_vpc.main.id}"
  port          = "${local.rds_instance_port}"
  engine        = "${local.rds_instance_engine}"
  instance_type = "${local.rds_instance_type}"
  multi_az      = "${local.rds_instance_multi_az}"
}

module "grafana" {
  source      = "../../"
  name_prefix = "${local.name_prefix}"
  vpc_id      = "${data.aws_vpc.main.id}"

  desired_count                     = "${local.desired_count}"
  private_subnet_ids                = "${data.aws_subnet_ids.main.ids}"
  tags                              = "${local.tags}"
  alb_arn                           = "${module.alb.arn}"
  task_container_assign_public_ip   = "${local.assign_public_ip}"
  health_check_grace_period_seconds = "${local.health_check_grace_period_seconds}"

  task_container_environment = {
    "GF_SERVER_ROOT_URL"      = "${local.server_protocol}://${module.alb.dns_name}:${local.public_port}"
    "GF_SERVER_PROTOCOL"      = "${local.server_protocol}"
    "GRAFANA_PLUGINS_ENABLED" = "${local.grafana_plugins_enabled}"

    "GF_DATABASE_TYPE"     = "${local.rds_instance_engine}"
    "GF_DATABASE_USER"     = "${local.rds_instance_username}"
    "GF_DATABASE_PASSWORD" = "${local.rds_instance_password}"
    "GF_DATABASE_HOST"     = "${module.rds_instance.endpoint}"

    "GF_SECURITY_ADMIN_USER"     = "${local.username}"
    "GF_SECURITY_ADMIN_PASSWORD" = "${local.password}"
    "GRAFANA_PASSWD"             = "${local.password}"

    "GF_AUTH_BASIC_ENABLED"      = "${local.auth_basic_enabled}"
    "GF_AUTH_ANONYMOUS_ENABLED"  = "${local.auth_anonymous_enabled}"
    "GF_AUTH_ANONYMOUS_ORG_ROLE" = "${local.auth_anonymous_role}"

    "GF_USERS_ALLOW_SIGN_UP"    = true
    "GF_USERS_ALLOW_ORG_CREATE" = true

    "GF_DASHBOARDS_JSON_ENABLED" = true
  }

  task_container_environment_count = "16"
}

# ----------------------------------------
# ALB Listener
# ----------------------------------------
resource "aws_lb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = "${local.public_port}"
  protocol          = "http"

  default_action {
    type             = "forward"
    target_group_arn = "${module.grafana.target_group_arn}"
  }
}

# ----------------------------------------
# Security Group Rules
# ----------------------------------------

resource "aws_security_group_rule" "lb_ingress" {
  type              = "ingress"
  description       = "Allow HTTP from internet"
  from_port         = "${local.public_port}"
  to_port           = "${local.public_port}"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = "${module.alb.security_group_id}"
}

resource "aws_security_group_rule" "lb_grafana_ingress_rule" {
  security_group_id        = "${module.grafana.service_sg_id}"
  description              = "Allow LB to communicate the Fargate ECS service."
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${local.task_container_port}"
  to_port                  = "${local.task_container_port}"
  source_security_group_id = "${module.alb.security_group_id}"
}

resource "aws_security_group_rule" "grafana_rds_ingress" {
  security_group_id        = "${module.rds_instance.security_group_id}"
  description              = "Allow Grafana to communicate the RDS service."
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.rds_instance.port}"
  to_port                  = "${module.rds_instance.port}"
  source_security_group_id = "${module.grafana.service_sg_id}"
}
