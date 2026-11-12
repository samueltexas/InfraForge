variable "workspace_name" {
  description = "Name of the Log Analytics Workspace."
  type        = string

  validation {
    condition = (
      length(var.workspace_name) >= 4 &&
      length(var.workspace_name) <= 63 &&
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.workspace_name))
    )
    error_message = "Workspace name must contain 4-63 valid characters."
  }
}

variable "location" {
  description = "Azure region for monitoring resources."
  type        = string
}

variable "resource_group_name" {
  description = "Existing Azure resource group."
  type        = string
}

variable "diagnostic_target_id" {
  description = "Resource ID of the Azure resource being monitored."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/[^/]+/[^/]+/[^/]+",
      var.diagnostic_target_id
    ))
    error_message = "Provide an Azure resource-level ID."
  }
}

variable "diagnostic_name" {
  description = "Name of the diagnostic settings configuration."
  type        = string
  default     = "infraforge-diagnostics"
}

variable "log_categories" {
  description = "Supported diagnostic log categories for the target."
  type        = set(string)
  default     = ["AuditEvent"]
}

variable "metric_categories" {
  description = "Supported diagnostic metric categories for the target."
  type        = set(string)
  default     = ["AllMetrics"]
}

variable "retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

variable "tags" {
  description = "Tags applied to monitoring resources."
  type        = map(string)
  default     = {}
}

variable "action_group_name" {
  description = "Name of the Azure Monitor Action Group."
  type        = string
  default     = "ag-infraforge-dev"

  validation {
    condition     = length(trimspace(var.action_group_name)) >= 3
    error_message = "Action group name must contain at least 3 characters."
  }
}

variable "action_group_short_name" {
  description = "Short name of the Azure Monitor Action Group."
  type        = string
  default     = "infraforge"

  validation {
    condition = (
      length(var.action_group_short_name) >= 1 &&
      length(var.action_group_short_name) <= 12
    )
    error_message = "Action group short name must contain between 1 and 12 characters."
  }
}

variable "alert_name" {
  description = "Name of the metric alert."
  type        = string
  default     = "alert-infraforge-dev"
}

variable "alert_target_id" {
  description = "Azure resource ID monitored by the metric alert."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]+/resourceGroups/[^/]+/providers/[^/]+/.+",
      var.alert_target_id
    ))
    error_message = "Alert target must be a valid Azure resource-level ID."
  }
}

variable "metric_namespace" {
  description = "Azure Monitor metric namespace."
  type        = string
  default     = "Microsoft.KeyVault/vaults"
}

variable "metric_name" {
  description = "Azure Monitor metric name."
  type        = string
  default     = "Availability"
}

variable "alert_threshold" {
  description = "Threshold that triggers the metric alert."
  type        = number
  default     = 80

  validation {
    condition = (
      var.alert_threshold > 0 &&
      var.alert_threshold <= 100
    )
    error_message = "Alert threshold must be greater than 0 and at most 100."
  }
}

variable "alert_severity" {
  description = "Azure Monitor alert severity."
  type        = number
  default     = 2

  validation {
    condition     = contains([0, 1, 2, 3, 4], var.alert_severity)
    error_message = "Alert severity must be between 0 and 4."
  }
}

variable "private_link_scope_name" {
  description = "Name of the Azure Monitor Private Link Scope."
  type        = string
  default     = "ampls-infraforge-dev"
}

variable "private_endpoint_name" {
  description = "Name of the Azure Monitor private endpoint."
  type        = string
  default     = "pe-infraforge-monitoring"
}

variable "private_endpoint_subnet_id" {
  description = "Azure subnet resource ID for the monitoring private endpoint."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+/subnets/[^/]+$",
      var.private_endpoint_subnet_id
    ))
    error_message = "Provide a valid Azure subnet resource ID."
  }
}

variable "virtual_network_id" {
  description = "Azure virtual network resource ID used for private DNS links."
  type        = string

  validation {
    condition = can(regex(
      "^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.Network/virtualNetworks/[^/]+$",
      var.virtual_network_id
    ))
    error_message = "Provide a valid Azure virtual network resource ID."
  }
}

variable "alert_email_receivers" {
  description = "Optional email recipients for Azure Monitor alerts."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for name, email in var.alert_email_receivers :
      length(trimspace(name)) > 0 &&
      can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", email))
    ])
    error_message = "Each alert recipient must have a non-empty name and valid email address."
  }
}
