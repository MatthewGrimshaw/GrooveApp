# Azure Monitor Baseline Alerts Module

This Terraform module implements Azure Monitor metric alerts based on the **Azure Monitor Baseline Alerts (AMBA)** project recommendations.

📚 **Reference**: [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/services/)

## Features

- ✅ **AMBA-Compliant Thresholds**: All alert thresholds follow Microsoft's recommended baselines
- ✅ **Comprehensive Coverage**: Alerts for App Service Plan, Web Apps, SQL Database, Container Registry
- ✅ **Action Groups**: Centralized notification configuration with email and webhook support
- ✅ **Flexible Configuration**: Enable/disable alerts per resource type
- ✅ **Production-Ready**: Severity levels, appropriate evaluation frequencies, and window sizes

## Alerts Implemented

### App Service Plan (serverFarms)
| Alert | Threshold | Severity | Description |
|-------|-----------|----------|-------------|
| CPU Percentage | 90% | 3 | Average CPU across all plan instances |
| Memory Percentage | 90% | 3 | Average memory across all plan instances |
| HTTP Queue Length | 100 | 3 | Requests queued before fulfillment |

### Web Apps (sites)
| Alert | Threshold | Severity | Description |
|-------|-----------|----------|-------------|
| Average Response Time | 60 seconds | 3 | Time to serve requests |
| HTTP 5xx Errors | 10 in 15 min | 1 | Server errors |
| HTTP 4xx Errors | 5 average in 30 min | 1 | Client errors |
| Memory Working Set | 1.5 GB | 3 | App memory usage |
| CPU Time | 120 seconds in 5 min | 3 | CPU consumed by app |

### SQL Database (servers/databases)
| Alert | Threshold | Severity | Description |
|-------|-----------|----------|-------------|
| CPU Used | 80% | 3 | vCore-based database CPU |
| Memory Percentage | 90% | 3 | SQL instance memory usage |
| Connection Failed | 5 in 5 min | 3 | Failed connection attempts |
| Deadlocks | 1 | 3 | Database deadlock occurrences |
| Storage | 870 GB | 3 | Data space used |
| Blocked by Firewall | 5 in 5 min | 2 | Connections blocked by firewall |

### Container Registry (registries)
| Alert | Threshold | Severity | Description |
|-------|-----------|----------|-------------|
| Storage Used | 400 GB | 3 | Total registry storage |

## Usage

### 1. Add Module to main.tf

```hcl
module "monitoring_alerts" {
  source = "./modules/monitoring-alerts"

  resource_group_name = azurerm_resource_group.main.name
  naming_prefix       = "grooveapp-${var.environment}"

  # Action Group Configuration
  action_group_name       = "grooveapp-${var.environment}-alerts"
  action_group_short_name = "ga-${var.environment}"

  email_receivers = [
    {
      name          = "DevOps Team"
      email_address = "devops@example.com"
    },
    {
      name          = "On-Call Engineer"
      email_address = "oncall@example.com"
    }
  ]

  # Optional: Webhook receivers for Teams/Slack
  webhook_receivers = [
    {
      name        = "Teams Channel"
      service_uri = "https://outlook.office.com/webhook/..." # Teams webhook URL
    }
  ]

  # Resource IDs to monitor
  app_service_plan_id = module.app_service_plan.id
  
  web_app_ids = {
    api      = module.web_app_api.id
    frontend = module.web_app_frontend.id
  }
  
  sql_database_id = module.database_sql[0].database_id
  
  container_registry_id = module.container_registry.id
  
  log_analytics_workspace_id = module.log_analytics.id

  # Enable/Disable alert categories
  enable_app_service_plan_alerts = true
  enable_web_app_alerts          = true
  enable_sql_alerts              = true
  enable_acr_alerts              = true
  enable_log_analytics_alerts    = false # Optional

  # Optional: Override default thresholds
  app_service_plan_cpu_threshold    = 85  # Default: 90
  app_service_plan_memory_threshold = 85  # Default: 90

  tags = local.common_tags
}
```

### 2. Add Outputs (Optional)

```hcl
output "monitoring_alerts" {
  description = "Monitoring alerts configuration"
  value = {
    action_group_id = module.monitoring_alerts.action_group_id
    alert_count     = module.monitoring_alerts.alert_count
    alert_ids       = module.monitoring_alerts.alert_ids
  }
}
```

## Microsoft Teams Integration

To send alerts to Microsoft Teams:

1. Create an **Incoming Webhook** in Teams:
   - Go to your Teams channel → Connectors → Incoming Webhook
   - Name it "Azure Alerts" and copy the webhook URL

2. Add to `webhook_receivers`:
```hcl
webhook_receivers = [
  {
    name        = "Teams DevOps Channel"
    service_uri = "https://outlook.office.com/webhook/YOUR-WEBHOOK-URL"
  }
]
```

## Slack Integration

To send alerts to Slack:

1. Create a Slack App with Incoming Webhooks enabled
2. Get the webhook URL from Slack
3. Add to `webhook_receivers`:
```hcl
webhook_receivers = [
  {
    name        = "Slack DevOps Channel"
    service_uri = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
  }
]
```

## Alert Severity Levels

| Severity | Description | Example Use Cases |
|----------|-------------|-------------------|
| 0 (Critical) | System unavailable | Total service outage |
| 1 (Error) | Major degradation | HTTP 5xx errors, high error rates |
| 2 (Warning) | Potential issues | Approaching limits, firewall blocks |
| 3 (Informational) | Performance metrics | CPU/memory thresholds |
| 4 (Verbose) | Detailed tracking | Dynamic threshold anomalies |

## Customization

### Override Individual Thresholds

The module provides variables for common threshold overrides. To customize other thresholds, modify the module's `main.tf` file directly.

### Disable Specific Alerts

Set the corresponding enable variable to `false`:

```hcl
enable_sql_alerts = false  # Disable all SQL alerts
```

### Add Custom Alerts

You can add custom alerts outside the module:

```hcl
resource "azurerm_monitor_metric_alert" "custom_alert" {
  name                = "custom-alert"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [module.web_app_api.id]
  
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10000
  }
  
  action {
    action_group_id = module.monitoring_alerts.action_group_id
  }
}
```

## Testing Alerts

### Test Action Group

```bash
# Send test notification
az monitor action-group test-notifications create \
  --resource-group rg-grooveapp-dev \
  --action-group-name grooveapp-dev-alerts \
  --notification-type Email \
  --alert-type servicehealth
```

### Trigger Test Alerts

```bash
# Trigger CPU alert (run CPU-intensive task)
# Monitor in Azure Portal → Monitor → Alerts

# View alert history
az monitor metrics alert show \
  --resource-group rg-grooveapp-dev \
  --name grooveapp-dev-asp-cpu-alert
```

## Monitoring and Troubleshooting

### View Active Alerts
```bash
az monitor metrics alert list \
  --resource-group rg-grooveapp-dev \
  --output table
```

### View Fired Alerts (Last 24 hours)
```bash
az monitor activity-log list \
  --resource-group rg-grooveapp-dev \
  --caller "Azure Monitor" \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ') \
  --output table
```

### Check Action Group
```bash
az monitor action-group show \
  --resource-group rg-grooveapp-dev \
  --name grooveapp-dev-alerts
```

## Cost Considerations

- **Metric Alerts**: $0.10 per alert rule per month
- **Action Group Notifications**: 
  - Email: $2 per 100,000 emails
  - Webhook: $0.60 per 100,000 webhooks

**Example Cost** (GrooveApp with all alerts enabled):
- ~15 alert rules × $0.10 = **$1.50/month**
- Email notifications: typically < $1/month
- **Total: ~$2.50/month**

## References

- [Azure Monitor Baseline Alerts (AMBA)](https://azure.github.io/azure-monitor-baseline-alerts/)
- [App Service Alerts](https://azure.github.io/azure-monitor-baseline-alerts/services/Web/sites/)
- [SQL Database Alerts](https://azure.github.io/azure-monitor-baseline-alerts/services/Sql/servers/)
- [Azure Monitor Pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [Alert Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices-alerts)

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 3.0 |

## License

MIT License - See root repository LICENSE file
