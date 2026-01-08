# terraform-aws-rds

Terraform module that creates AWS RDS instances and Aurora clusters with encryption, monitoring, and high availability options.

## Features

- **Multiple Engines** - MySQL, PostgreSQL, MariaDB, Aurora MySQL, Aurora PostgreSQL
- **Aurora Clusters** - Multi-instance Aurora with reader/writer endpoints
- **Aurora Serverless v2** - Auto-scaling serverless capacity
- **Encryption** - Storage encryption with AWS KMS
- **Secrets Manager** - Automatic master password management
- **Performance Insights** - Query performance monitoring
- **Enhanced Monitoring** - Real-time OS metrics
- **Read Replicas** - Horizontal read scaling for non-Aurora
- **Parameter Groups** - Custom database parameters
- **Multi-AZ** - High availability deployment
- **IAM Authentication** - Token-based database access

## Usage

### Basic MySQL Instance

```hcl
module "mysql" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "my-mysql-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "admin"

  # Security - allow from app servers
  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "production"
  }
}
```

### PostgreSQL with High Availability

```hcl
module "postgres" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "my-postgres-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.r6g.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "postgres_admin"

  # Storage
  allocated_storage     = 100
  max_allocated_storage = 500
  storage_type          = "gp3"
  iops                  = 3000
  storage_throughput    = 125

  # High Availability
  multi_az = true

  # Backup
  backup_retention_period = 14
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"

  # Security
  deletion_protection = true
  allowed_security_group_ids = [module.app.security_group_id]

  # Monitoring
  monitoring_interval = 30
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Performance
  performance_insights_enabled          = true
  performance_insights_retention_period = 31

  tags = {
    Environment = "production"
  }
}
```

### Aurora MySQL Cluster

```hcl
module "aurora_mysql" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "my-aurora-cluster"
  engine         = "aurora-mysql"
  engine_version = "8.0.mysql_aurora.3.04.0"
  instance_class = "db.r6g.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "admin"

  # Aurora instances
  aurora_cluster_instances = 3  # 1 writer + 2 readers

  # Backup
  backup_retention_period = 7

  # Security
  allowed_security_group_ids = [module.app.security_group_id]

  # Logging
  enabled_cloudwatch_logs_exports = ["audit", "error", "slowquery"]

  tags = {
    Environment = "production"
  }
}
```

### Aurora Serverless v2

```hcl
module "aurora_serverless" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "serverless-cluster"
  engine         = "aurora-postgresql"
  engine_version = "15.4"
  instance_class = "db.serverless"  # Will be overridden by module

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "postgres_admin"

  # Serverless v2 scaling
  serverless_v2_scaling = {
    min_capacity = 0.5   # 0.5 ACU minimum
    max_capacity = 16    # 16 ACU maximum
  }

  aurora_cluster_instances = 2

  # Security
  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "development"
  }
}
```

### With Read Replicas

```hcl
module "mysql_with_replicas" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "my-mysql-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.r6g.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "admin"

  allocated_storage     = 100
  max_allocated_storage = 500

  # Read replicas
  read_replicas = {
    replica-1 = {
      availability_zone = "us-east-1b"
    }
    replica-2 = {
      instance_class    = "db.r6g.xlarge"  # Larger replica
      availability_zone = "us-east-1c"
    }
  }

  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "production"
  }
}
```

### With Custom Parameters

```hcl
module "mysql_custom" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "custom-mysql"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.r6g.large"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "admin"

  # Custom parameters
  parameter_group_family = "mysql8.0"
  parameters = [
    {
      name  = "character_set_server"
      value = "utf8mb4"
    },
    {
      name  = "collation_server"
      value = "utf8mb4_unicode_ci"
    },
    {
      name  = "max_connections"
      value = "500"
    },
    {
      name         = "innodb_buffer_pool_size"
      value        = "{DBInstanceClassMemory*3/4}"
      apply_method = "pending-reboot"
    }
  ]

  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "production"
  }
}
```

### With IAM Authentication

```hcl
module "postgres_iam" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "iam-postgres"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.medium"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "myapp"
  master_username = "postgres_admin"

  # Enable IAM authentication
  iam_database_authentication_enabled = true

  allowed_security_group_ids = [module.app.security_group_id]

  tags = {
    Environment = "production"
  }
}
```

### Development Instance (Cost Optimized)

```hcl
module "dev_db" {
  source = "ogulcanaydogan/rds/aws"

  identifier     = "dev-database"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.database_subnet_ids

  database_name   = "devapp"
  master_username = "dev_admin"

  # Minimal storage
  allocated_storage     = 20
  max_allocated_storage = 0  # Disable autoscaling

  # No high availability
  multi_az = false

  # Minimal backups
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  # Disable enhanced monitoring
  monitoring_interval          = 0
  performance_insights_enabled = false

  allowed_cidr_blocks = ["10.0.0.0/8"]

  tags = {
    Environment = "development"
  }
}
```

## Inputs

### Required

| Name | Description | Type |
|------|-------------|------|
| `identifier` | Database identifier | `string` |
| `engine` | Database engine | `string` |
| `engine_version` | Engine version | `string` |
| `vpc_id` | VPC ID | `string` |
| `subnet_ids` | Subnet IDs (min 2) | `list(string)` |

### Database

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `instance_class` | Instance class | `string` | `"db.t3.micro"` |
| `database_name` | Initial database name | `string` | `null` |
| `master_username` | Master username | `string` | `"admin"` |
| `master_password` | Master password | `string` | `null` |
| `manage_master_user_password` | Use Secrets Manager | `bool` | `true` |
| `port` | Database port | `number` | Engine default |

### Storage (Non-Aurora)

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `allocated_storage` | Storage in GB | `number` | `20` |
| `max_allocated_storage` | Max storage for autoscaling | `number` | `100` |
| `storage_type` | Storage type (gp2, gp3, io1, io2) | `string` | `"gp3"` |
| `iops` | Provisioned IOPS | `number` | `null` |
| `storage_throughput` | Throughput (gp3 only) | `number` | `null` |
| `storage_encrypted` | Enable encryption | `bool` | `true` |
| `kms_key_id` | KMS key ID | `string` | `null` |

### High Availability

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `multi_az` | Enable Multi-AZ | `bool` | `false` |
| `availability_zone` | AZ for single-AZ | `string` | `null` |

### Aurora

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `aurora_cluster_instances` | Number of Aurora instances | `number` | `2` |
| `serverless_v2_scaling` | Serverless v2 config | `object` | `null` |

### Network

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `publicly_accessible` | Public access | `bool` | `false` |
| `allowed_cidr_blocks` | Allowed CIDRs | `list(string)` | `[]` |
| `allowed_security_group_ids` | Allowed SG IDs | `list(string)` | `[]` |

### Backup

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `backup_retention_period` | Retention days (0-35) | `number` | `7` |
| `backup_window` | Backup window | `string` | `"03:00-04:00"` |
| `maintenance_window` | Maintenance window | `string` | `"Mon:04:00-Mon:05:00"` |
| `skip_final_snapshot` | Skip final snapshot | `bool` | `false` |
| `final_snapshot_identifier` | Final snapshot name | `string` | `null` |
| `deletion_protection` | Enable deletion protection | `bool` | `true` |
| `copy_tags_to_snapshot` | Copy tags | `bool` | `true` |

### Monitoring

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `performance_insights_enabled` | Enable PI | `bool` | `true` |
| `performance_insights_retention_period` | PI retention (7, 31-731) | `number` | `7` |
| `monitoring_interval` | Enhanced monitoring interval | `number` | `60` |
| `enabled_cloudwatch_logs_exports` | Log exports | `list(string)` | `[]` |

### Parameters

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `parameter_group_family` | Parameter group family | `string` | Auto-detected |
| `parameters` | DB parameters | `list(object)` | `[]` |
| `cluster_parameters` | Cluster parameters (Aurora) | `list(object)` | `[]` |

### Read Replicas

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `read_replicas` | Map of read replica configs | `map(object)` | `{}` |

### Other

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `iam_database_authentication_enabled` | Enable IAM auth | `bool` | `false` |
| `auto_minor_version_upgrade` | Auto minor upgrades | `bool` | `true` |
| `apply_immediately` | Apply changes immediately | `bool` | `false` |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

### RDS Instance

| Name | Description |
|------|-------------|
| `db_instance_id` | Instance ID |
| `db_instance_arn` | Instance ARN |
| `db_instance_endpoint` | Endpoint (host:port) |
| `db_instance_address` | Hostname |
| `db_instance_port` | Port |

### Aurora Cluster

| Name | Description |
|------|-------------|
| `cluster_id` | Cluster ID |
| `cluster_arn` | Cluster ARN |
| `cluster_endpoint` | Writer endpoint |
| `cluster_reader_endpoint` | Reader endpoint |
| `cluster_instances` | Instance details |

### Common

| Name | Description |
|------|-------------|
| `endpoint` | Primary endpoint |
| `address` | Primary hostname |
| `port` | Database port |
| `database_name` | Database name |
| `master_username` | Master username |
| `master_user_secret_arn` | Secrets Manager ARN |
| `security_group_id` | Security group ID |
| `connection_string_mysql` | MySQL connection example |
| `connection_string_postgres` | PostgreSQL connection example |

## CloudWatch Log Exports

### MySQL/Aurora MySQL
- `audit` - Audit logs
- `error` - Error logs
- `general` - General logs
- `slowquery` - Slow query logs

### PostgreSQL/Aurora PostgreSQL
- `postgresql` - PostgreSQL logs
- `upgrade` - Upgrade logs

### MariaDB
- `audit` - Audit logs
- `error` - Error logs
- `general` - General logs
- `slowquery` - Slow query logs

## Examples

See [`examples/`](./examples/) for complete configurations.
