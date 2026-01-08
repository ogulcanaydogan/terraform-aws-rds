variable "identifier" {
  description = "Name of the RDS instance or cluster."
  type        = string

  validation {
    condition     = length(trimspace(var.identifier)) > 0 && length(var.identifier) <= 63
    error_message = "identifier must be between 1 and 63 characters."
  }

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.identifier)) || length(var.identifier) == 1
    error_message = "identifier must start with a letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "engine" {
  description = "Database engine (mysql, postgres, mariadb, aurora-mysql, aurora-postgresql)."
  type        = string

  validation {
    condition     = contains(["mysql", "postgres", "mariadb", "aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "engine must be mysql, postgres, mariadb, aurora-mysql, or aurora-postgresql."
  }
}

variable "engine_version" {
  description = "Database engine version."
  type        = string
}

variable "instance_class" {
  description = "Instance class for the RDS instance."
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "instance_class must start with 'db.' (e.g., db.t3.micro, db.r6g.large)."
  }
}

# Database Configuration
variable "database_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = null

  validation {
    condition     = var.database_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.database_name))
    error_message = "database_name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "master_username" {
  description = "Master username for the database."
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.master_username))
    error_message = "master_username must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "master_password" {
  description = "Master password for the database. If not provided, one will be generated."
  type        = string
  default     = null
  sensitive   = true
}

variable "manage_master_user_password" {
  description = "Manage master user password in AWS Secrets Manager."
  type        = bool
  default     = true
}

variable "port" {
  description = "Database port."
  type        = number
  default     = null
}

# Storage
variable "allocated_storage" {
  description = "Allocated storage in GB (not applicable for Aurora)."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "allocated_storage must be between 20 and 65536 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB (0 to disable)."
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1, io2)."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.storage_type)
    error_message = "storage_type must be gp2, gp3, io1, or io2."
  }
}

variable "iops" {
  description = "Provisioned IOPS (required for io1/io2)."
  type        = number
  default     = null
}

variable "storage_throughput" {
  description = "Storage throughput in MiB/s (gp3 only)."
  type        = number
  default     = null
}

# Network
variable "vpc_id" {
  description = "VPC ID for the database."
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required."
  }
}

variable "publicly_accessible" {
  description = "Make the database publicly accessible."
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the database."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for cidr in var.allowed_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "All values must be valid CIDR blocks."
  }
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to access the database."
  type        = list(string)
  default     = []
}

# High Availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment."
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone for single-AZ deployment."
  type        = string
  default     = null
}

# Aurora Specific
variable "aurora_cluster_instances" {
  description = "Number of Aurora cluster instances."
  type        = number
  default     = 2

  validation {
    condition     = var.aurora_cluster_instances >= 1 && var.aurora_cluster_instances <= 16
    error_message = "aurora_cluster_instances must be between 1 and 16."
  }
}

variable "serverless_v2_scaling" {
  description = "Aurora Serverless v2 scaling configuration."
  type = object({
    min_capacity = number
    max_capacity = number
  })
  default = null

  validation {
    condition = var.serverless_v2_scaling == null || (
      var.serverless_v2_scaling.min_capacity >= 0.5 &&
      var.serverless_v2_scaling.max_capacity <= 128 &&
      var.serverless_v2_scaling.min_capacity <= var.serverless_v2_scaling.max_capacity
    )
    error_message = "Serverless v2 capacity must be between 0.5 and 128 ACU."
  }
}

# Encryption
variable "storage_encrypted" {
  description = "Enable storage encryption."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID for encryption."
  type        = string
  default     = null
}

# Backup and Recovery
variable "backup_retention_period" {
  description = "Backup retention period in days (0 to disable)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35 days."
  }
}

variable "backup_window" {
  description = "Daily backup window (HH:MM-HH:MM UTC)."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Name for the final snapshot."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection."
  type        = bool
  default     = true
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to snapshots."
  type        = bool
  default     = true
}

# Performance
variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention in days (7, 31-731)."
  type        = number
  default     = 7

  validation {
    condition     = var.performance_insights_retention_period == 7 || (var.performance_insights_retention_period >= 31 && var.performance_insights_retention_period <= 731)
    error_message = "performance_insights_retention_period must be 7 (free tier) or between 31-731 days."
  }
}

variable "performance_insights_kms_key_id" {
  description = "KMS key for Performance Insights encryption."
  type        = string
  default     = null
}

# Monitoring
variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 to disable)."
  type        = number
  default     = 60

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be 0, 1, 5, 10, 15, 30, or 60 seconds."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch."
  type        = list(string)
  default     = []
}

# Parameters
variable "parameter_group_family" {
  description = "DB parameter group family (e.g., mysql8.0, postgres15)."
  type        = string
  default     = null
}

variable "parameters" {
  description = "List of DB parameters."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "cluster_parameters" {
  description = "List of cluster parameters (Aurora only)."
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

# IAM
variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication."
  type        = bool
  default     = false
}

# Options (MySQL/MariaDB only)
variable "option_group_name" {
  description = "Name of an existing option group."
  type        = string
  default     = null
}

variable "options" {
  description = "List of options for the option group."
  type = list(object({
    option_name                    = string
    port                           = optional(number)
    version                        = optional(string)
    db_security_group_memberships  = optional(list(string), [])
    vpc_security_group_memberships = optional(list(string), [])
    option_settings = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

# Read Replicas (non-Aurora)
variable "read_replicas" {
  description = "Map of read replica configurations."
  type = map(object({
    instance_class      = optional(string)
    availability_zone   = optional(string)
    publicly_accessible = optional(bool, false)
  }))
  default = {}
}

# Auto Minor Version Upgrade
variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Apply changes immediately instead of during maintenance window."
  type        = bool
  default     = false
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
