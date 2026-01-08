# Instance Outputs (Non-Aurora)
output "db_instance_id" {
  description = "RDS instance ID."
  value       = try(aws_db_instance.this[0].id, null)
}

output "db_instance_arn" {
  description = "RDS instance ARN."
  value       = try(aws_db_instance.this[0].arn, null)
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint (hostname:port)."
  value       = try(aws_db_instance.this[0].endpoint, null)
}

output "db_instance_address" {
  description = "RDS instance hostname."
  value       = try(aws_db_instance.this[0].address, null)
}

output "db_instance_port" {
  description = "RDS instance port."
  value       = try(aws_db_instance.this[0].port, null)
}

output "db_instance_status" {
  description = "RDS instance status."
  value       = try(aws_db_instance.this[0].status, null)
}

output "db_instance_resource_id" {
  description = "RDS instance resource ID."
  value       = try(aws_db_instance.this[0].resource_id, null)
}

# Aurora Cluster Outputs
output "cluster_id" {
  description = "Aurora cluster ID."
  value       = try(aws_rds_cluster.this[0].id, null)
}

output "cluster_arn" {
  description = "Aurora cluster ARN."
  value       = try(aws_rds_cluster.this[0].arn, null)
}

output "cluster_endpoint" {
  description = "Aurora cluster writer endpoint."
  value       = try(aws_rds_cluster.this[0].endpoint, null)
}

output "cluster_reader_endpoint" {
  description = "Aurora cluster reader endpoint."
  value       = try(aws_rds_cluster.this[0].reader_endpoint, null)
}

output "cluster_port" {
  description = "Aurora cluster port."
  value       = try(aws_rds_cluster.this[0].port, null)
}

output "cluster_resource_id" {
  description = "Aurora cluster resource ID."
  value       = try(aws_rds_cluster.this[0].cluster_resource_id, null)
}

output "cluster_instances" {
  description = "Aurora cluster instance details."
  value = {
    for instance in aws_rds_cluster_instance.this : instance.identifier => {
      id       = instance.id
      arn      = instance.arn
      endpoint = instance.endpoint
      writer   = instance.writer
    }
  }
}

# Read Replica Outputs
output "read_replica_endpoints" {
  description = "Map of read replica endpoints."
  value = {
    for key, replica in aws_db_instance.replica : key => {
      endpoint = replica.endpoint
      address  = replica.address
      port     = replica.port
      arn      = replica.arn
    }
  }
}

# Common Outputs
output "endpoint" {
  description = "Primary database endpoint (works for both RDS and Aurora)."
  value       = try(aws_db_instance.this[0].endpoint, aws_rds_cluster.this[0].endpoint, null)
}

output "address" {
  description = "Primary database hostname."
  value       = try(aws_db_instance.this[0].address, aws_rds_cluster.this[0].endpoint, null)
}

output "port" {
  description = "Database port."
  value       = try(aws_db_instance.this[0].port, aws_rds_cluster.this[0].port, null)
}

output "database_name" {
  description = "Name of the database."
  value       = var.database_name
}

output "master_username" {
  description = "Master username."
  value       = var.master_username
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret containing master credentials."
  value       = try(aws_db_instance.this[0].master_user_secret[0].secret_arn, aws_rds_cluster.this[0].master_user_secret[0].secret_arn, null)
}

# Security
output "security_group_id" {
  description = "Security group ID."
  value       = aws_security_group.this.id
}

output "db_subnet_group_name" {
  description = "DB subnet group name."
  value       = aws_db_subnet_group.this.name
}

output "db_subnet_group_arn" {
  description = "DB subnet group ARN."
  value       = aws_db_subnet_group.this.arn
}

# Parameter Groups
output "parameter_group_name" {
  description = "Parameter group name."
  value       = try(aws_db_parameter_group.this[0].name, aws_db_parameter_group.aurora[0].name, null)
}

output "cluster_parameter_group_name" {
  description = "Cluster parameter group name (Aurora only)."
  value       = try(aws_rds_cluster_parameter_group.this[0].name, null)
}

# Option Group
output "option_group_name" {
  description = "Option group name."
  value       = try(aws_db_option_group.this[0].name, null)
}

# Monitoring
output "monitoring_role_arn" {
  description = "Enhanced monitoring IAM role ARN."
  value       = try(aws_iam_role.monitoring[0].arn, null)
}

# Connection String Examples
output "connection_string_mysql" {
  description = "MySQL connection string example."
  value = startswith(var.engine, "mysql") || startswith(var.engine, "aurora-mysql") ? (
    "mysql -h ${try(aws_db_instance.this[0].address, aws_rds_cluster.this[0].endpoint, "HOSTNAME")} -P ${local.port} -u ${var.master_username} -p"
  ) : null
}

output "connection_string_postgres" {
  description = "PostgreSQL connection string example."
  value = startswith(var.engine, "postgres") || startswith(var.engine, "aurora-postgres") ? (
    "psql -h ${try(aws_db_instance.this[0].address, aws_rds_cluster.this[0].endpoint, "HOSTNAME")} -p ${local.port} -U ${var.master_username} -d ${coalesce(var.database_name, "postgres")}"
  ) : null
}
