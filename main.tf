locals {
  is_aurora   = startswith(var.engine, "aurora")
  common_tags = merge(var.tags, { Name = var.identifier })

  # Default ports
  default_port = {
    mysql               = 3306
    postgres            = 5432
    mariadb             = 3306
    "aurora-mysql"      = 3306
    "aurora-postgresql" = 5432
  }

  port = coalesce(var.port, local.default_port[var.engine])

  # Parameter group family defaults
  default_parameter_family = {
    mysql               = "mysql8.0"
    postgres            = "postgres15"
    mariadb             = "mariadb10.11"
    "aurora-mysql"      = "aurora-mysql8.0"
    "aurora-postgresql" = "aurora-postgresql15"
  }

  parameter_group_family = coalesce(var.parameter_group_family, local.default_parameter_family[var.engine])
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

################################################################################
# DB Subnet Group
################################################################################

resource "aws_db_subnet_group" "this" {
  name        = "${var.identifier}-subnet-group"
  description = "Subnet group for ${var.identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

################################################################################
# Security Group
################################################################################

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier} database"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = local.port
  to_port           = local.port
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Allow database access from CIDR blocks"
}

resource "aws_security_group_rule" "ingress_sg" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = local.port
  to_port                  = local.port
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow database access from security group ${each.value}"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
}

################################################################################
# IAM Role for Enhanced Monitoring
################################################################################

resource "aws_iam_role" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.identifier}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

################################################################################
# Parameter Group
################################################################################

resource "aws_db_parameter_group" "this" {
  count = length(var.parameters) > 0 && !local.is_aurora ? 1 : 0

  name        = "${var.identifier}-params"
  family      = local.parameter_group_family
  description = "Parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Option Group (MySQL/MariaDB only)
################################################################################

resource "aws_db_option_group" "this" {
  count = length(var.options) > 0 && contains(["mysql", "mariadb"], var.engine) ? 1 : 0

  name                     = "${var.identifier}-options"
  engine_name              = var.engine
  major_engine_version     = regex("^\\d+\\.\\d+", var.engine_version)
  option_group_description = "Option group for ${var.identifier}"

  dynamic "option" {
    for_each = var.options

    content {
      option_name = option.value.option_name
      port        = option.value.port
      version     = option.value.version

      db_security_group_memberships  = option.value.db_security_group_memberships
      vpc_security_group_memberships = option.value.vpc_security_group_memberships

      dynamic "option_settings" {
        for_each = option.value.option_settings

        content {
          name  = option_settings.value.name
          value = option_settings.value.value
        }
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# RDS Instance (Non-Aurora)
################################################################################

resource "aws_db_instance" "this" {
  count = !local.is_aurora ? 1 : 0

  identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  password = var.manage_master_user_password ? null : var.master_password
  port     = local.port

  manage_master_user_password = var.manage_master_user_password

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  iops                  = var.iops
  storage_throughput    = var.storage_type == "gp3" ? var.storage_throughput : null
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az
  availability_zone      = var.multi_az ? null : var.availability_zone

  backup_retention_period   = var.backup_retention_period
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.identifier}-final-snapshot")
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = var.copy_tags_to_snapshot

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  parameter_group_name = length(var.parameters) > 0 ? aws_db_parameter_group.this[0].name : null
  option_group_name    = length(var.options) > 0 ? aws_db_option_group.this[0].name : var.option_group_name

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = local.common_tags

  depends_on = [aws_iam_role_policy_attachment.monitoring]
}

################################################################################
# Read Replicas (Non-Aurora)
################################################################################

resource "aws_db_instance" "replica" {
  for_each = !local.is_aurora ? var.read_replicas : {}

  identifier = "${var.identifier}-${each.key}"

  replicate_source_db = aws_db_instance.this[0].identifier
  instance_class      = coalesce(each.value.instance_class, var.instance_class)

  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = each.value.publicly_accessible
  availability_zone      = each.value.availability_zone

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-${each.key}"
  })

  depends_on = [aws_db_instance.this]
}

################################################################################
# Aurora Cluster Parameter Group
################################################################################

resource "aws_rds_cluster_parameter_group" "this" {
  count = local.is_aurora && length(var.cluster_parameters) > 0 ? 1 : 0

  name        = "${var.identifier}-cluster-params"
  family      = local.parameter_group_family
  description = "Cluster parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.cluster_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Aurora DB Parameter Group
################################################################################

resource "aws_db_parameter_group" "aurora" {
  count = local.is_aurora && length(var.parameters) > 0 ? 1 : 0

  name        = "${var.identifier}-db-params"
  family      = local.parameter_group_family
  description = "DB parameter group for ${var.identifier}"

  dynamic "parameter" {
    for_each = var.parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Aurora Cluster
################################################################################

resource "aws_rds_cluster" "this" {
  count = local.is_aurora ? 1 : 0

  cluster_identifier = var.identifier

  engine         = var.engine
  engine_version = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username
  master_password = var.manage_master_user_password ? null : var.master_password
  port            = local.port

  manage_master_user_password = var.manage_master_user_password

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : coalesce(var.final_snapshot_identifier, "${var.identifier}-final-snapshot")
  deletion_protection          = var.deletion_protection
  copy_tags_to_snapshot        = var.copy_tags_to_snapshot

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  db_cluster_parameter_group_name = length(var.cluster_parameters) > 0 ? aws_rds_cluster_parameter_group.this[0].name : null

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  apply_immediately = var.apply_immediately

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverless_v2_scaling != null ? [var.serverless_v2_scaling] : []

    content {
      min_capacity = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity = serverlessv2_scaling_configuration.value.max_capacity
    }
  }

  tags = local.common_tags
}

################################################################################
# Aurora Cluster Instances
################################################################################

resource "aws_rds_cluster_instance" "this" {
  count = local.is_aurora ? var.aurora_cluster_instances : 0

  identifier         = "${var.identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this[0].id

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.serverless_v2_scaling != null ? "db.serverless" : var.instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = var.publicly_accessible

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null

  db_parameter_group_name = length(var.parameters) > 0 ? aws_db_parameter_group.aurora[0].name : null

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-${count.index + 1}"
  })

  depends_on = [aws_iam_role_policy_attachment.monitoring]
}
