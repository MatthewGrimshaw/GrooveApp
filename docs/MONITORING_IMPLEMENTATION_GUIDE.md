# Azure Monitor Baseline Alerts Implementation Guide

## Overview

This guide walks you through implementing production-grade Azure Monitor alerts for your GrooveApp infrastructure based on the **Azure Monitor Baseline Alerts (AMBA)** project.

**Reference**: https://azure.github.io/azure-monitor-baseline-alerts/services/

## What's Been Created

### Module Structure
```
infra/terraform/modules/monitoring-alerts/
├── main.tf          # Alert rules and action groups
├── variables.tf     # Module configuration
├── outputs.tf       # Module outputs
└── README.md        # Module documentation
```

### Alert Coverage (AMBA-Compliant)

#### ✅ App Service Plan (3 alerts)
- CPU Percentage > 90%
- Memory Percentage > 90%
- HTTP Queue Length > 100

#### ✅ Web Apps - API & Frontend (5 alerts each = 10 total)
- Average Response Time > 60 seconds
- HTTP 5xx errors > 10 in 15 minutes
- HTTP 4xx errors average > 5 in 30 minutes
- Memory Working Set > 1.5 GB
- CPU Time > 120 seconds in 5 minutes

#### ✅ SQL Database (6 alerts)
- CPU Used > 80%
- Memory Percentage > 90%
- Connection Failed > 5 in 5 minutes
- Deadlocks > 1
- Storage > 870 GB
- Blocked by Firewall > 5 in 5 minutes

#### ✅ Container Registry (1 alert)
- Storage Used > 400 GB

**Total: ~20 alerts** for comprehensive monitoring

## Implementation Steps

### Step 1: Review Example Files

Three example files have been created to guide your implementation:

1. **EXAMPLE-monitoring-integration.tf** - Shows how to add the module to main.tf
2. **EXAMPLE-monitoring-variables.tf** - Variables to add to variables.tf
3. **EXAMPLE-dev-monitoring.tfvars** - Configuration for dev.tfvars

### Step 2: Add Variables

Add the monitoring variables from `EXAMPLE-monitoring-variables.tf` to your `variables.tf`:

```bash
# Copy variables to your variables.tf
cat infra/terraform/EXAMPLE-monitoring-variables.tf >> infra/terraform/variables.tf
```

Or manually add them to the bottom of your `variables.tf`.

### Step 3: Configure Email Notifications

Edit `infra/terraform/environments/dev.tfvars` and add:

```hcl
# Alert Email Notifications
alert_email_receivers = [
  {
    name          = "Matthew Grimshaw"
    email_address = "matgri@microsoft.com"
  }
]

# Alert Webhook Notifications (optional)
alert_webhook_receivers = []

# Enable alerts
enable_app_service_plan_alerts = true
enable_web_app_alerts          = true
enable_sql_alerts              = true
enable_acr_alerts              = true
enable_log_analytics_alerts    = false
```

Repeat for `staging.tfvars` and `prod.tfvars` with environment-specific emails.

### Step 4: Add Module to main.tf

Add this module block to `infra/terraform/main.tf` (after your existing modules):

```hcl
# ============================================================================
# AZURE MONITOR BASELINE ALERTS
# ============================================================================

module "monitoring_alerts" {
  source = "./modules/monitoring-alerts"

  resource_group_name = azurerm_resource_group.main.name
  naming_prefix       = "${var.naming_prefix}-${var.environment}"

  action_group_name       = "${var.naming_prefix}-${var.environment}-alerts"
  action_group_short_name = var.environment == "prod" ? "ga-prod" : (var.environment == "staging" ? "ga-stage" : "ga-dev")

  email_receivers   = var.alert_email_receivers
  webhook_receivers = var.alert_webhook_receivers

  app_service_plan_id = module.app_service_plan.id
  
  web_app_ids = {
    api      = module.web_app_api.id
    frontend = module.web_app_frontend.id
  }
  
  sql_database_id = var.database_type == "sql" ? module.database_sql[0].database_id : null
  
  container_registry_id = module.container_registry.id
  
  log_analytics_workspace_id = module.log_analytics.workspace_id

  enable_app_service_plan_alerts = var.enable_app_service_plan_alerts
  enable_web_app_alerts          = var.enable_web_app_alerts
  enable_sql_alerts              = var.database_type == "sql" && var.enable_sql_alerts
  enable_acr_alerts              = var.enable_acr_alerts
  enable_log_analytics_alerts    = var.enable_log_analytics_alerts

  app_service_plan_cpu_threshold    = var.environment == "prod" ? 80 : 90
  app_service_plan_memory_threshold = var.environment == "prod" ? 85 : 90

  tags = local.common_tags
}
```

### Step 5: Add Outputs (Optional)

Add to `infra/terraform/outputs.tf`:

```hcl
output "monitoring" {
  description = "Azure Monitor alerts configuration"
  value = {
    action_group_id = module.monitoring_alerts.action_group_id
    alert_count     = module.monitoring_alerts.alert_count
  }
}
```

### Step 6: Deploy

```bash
cd infra/terraform

# Initialize new module
terraform init

# Plan with dev environment
terraform plan -var-file="environments/dev.tfvars"

# Apply alerts
terraform apply -var-file="environments/dev.tfvars"
```

### Step 7: Verify Deployment

```bash
# List created alerts
az monitor metrics alert list \
  --resource-group rg-grooveapp-dev-uhxg \
  --output table

# View action group
az monitor action-group show \
  --resource-group rg-grooveapp-dev-uhxg \
  --name grooveapp-dev-alerts
```

## Microsoft Teams Integration (Optional)

### Create Teams Webhook

1. Open Microsoft Teams
2. Navigate to your DevOps channel
3. Click `•••` → **Connectors** → **Incoming Webhook**
4. Name it "Azure Monitor Alerts"
5. Copy the webhook URL

### Add to Terraform

In your `dev.tfvars`:

```hcl
alert_webhook_receivers = [
  {
    name        = "Teams DevOps Channel"
    service_uri = "https://outlook.office.com/webhook/YOUR-WEBHOOK-URL-HERE"
  }
]
```

Apply Terraform to update the action group.

## Testing Alerts

### Test Email Notification

```bash
# Send test notification to action group
az monitor action-group test-notifications create \
  --resource-group rg-grooveapp-dev-uhxg \
  --action-group-name grooveapp-dev-alerts \
  --notification-type Email \
  --alert-type servicehealth
```

You should receive a test email within minutes.

### Trigger CPU Alert (Development Testing)

```bash
# Deploy a CPU-intensive endpoint to test
# Or use Azure Portal to manually adjust thresholds temporarily

# Monitor alert firing in Azure Portal:
# Monitor → Alerts → Alert rules
```

## Alert Tuning

### Adjusting Thresholds

If you're getting too many/few alerts, adjust thresholds in your tfvars:

```hcl
# More sensitive (production)
app_service_plan_cpu_threshold = 75
app_service_plan_memory_threshold = 80

# Less sensitive (development)
app_service_plan_cpu_threshold = 95
app_service_plan_memory_threshold = 95
```

Then re-apply Terraform.

### Disabling Specific Alerts

To disable SQL alerts in dev but keep in prod:

**dev.tfvars:**
```hcl
enable_sql_alerts = false
```

**prod.tfvars:**
```hcl
enable_sql_alerts = true
```

## Monitoring Alert Health

### View Fired Alerts (Last 24 Hours)

```bash
az monitor activity-log list \
  --resource-group rg-grooveapp-dev-uhxg \
  --caller "Azure Monitor" \
  --start-time $(date -u -d '24 hours ago' '+%Y-%m-%dT%H:%M:%SZ')
```

### Query in Azure Portal

1. Navigate to **Monitor** → **Alerts**
2. Filter by Resource Group: `rg-grooveapp-dev-uhxg`
3. View **Alert History** and **Fired Alerts**

### Application Insights Integration

Alerts automatically integrate with your Application Insights instance for correlation:

1. Navigate to **Application Insights** → `appinsights-grooveapp-dev`
2. View **Failures** and **Performance** tabs
3. Alerts will show contextual data when fired

## Cost

**Monthly Cost Estimate:**
- ~20 metric alert rules × $0.10 = **$2.00/month**
- Email notifications: typically < $0.50/month
- Webhook notifications: typically < $0.50/month
- **Total: ~$3.00/month**

Very cost-effective for production monitoring!

## Best Practices

### ✅ Do's
- Enable all alerts in production
- Use stricter thresholds in prod (80% instead of 90%)
- Add multiple email receivers for redundancy
- Set up Teams/Slack integration for faster response
- Review and tune alerts monthly based on fired alerts
- Document alert responses in runbooks

### ❌ Don'ts
- Don't disable alerts without team discussion
- Don't set thresholds too high (alert fatigue) or too low (noise)
- Don't ignore alert emails - investigate and fix root causes
- Don't use personal emails only - use team distribution lists

## Troubleshooting

### Alerts Not Firing

1. Check metric values are actually exceeding thresholds:
```bash
az monitor metrics list \
  --resource <resource-id> \
  --metric CpuPercentage \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')
```

2. Verify alert is enabled:
```bash
az monitor metrics alert show \
  --resource-group rg-grooveapp-dev-uhxg \
  --name grooveapp-dev-asp-cpu-alert
```

### Emails Not Received

1. Check spam/junk folder
2. Verify email address in action group:
```bash
az monitor action-group show \
  --resource-group rg-grooveapp-dev-uhxg \
  --name grooveapp-dev-alerts
```

3. Send test notification (see Testing section above)

### Webhook Not Working

1. Verify webhook URL is correct
2. Check webhook endpoint logs
3. Test webhook manually:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"text": "Test alert from Azure"}' \
  YOUR-WEBHOOK-URL
```

## Next Steps

1. ✅ Deploy alerts to dev environment
2. ✅ Test email notifications
3. ✅ Set up Teams/Slack webhook (optional)
4. ✅ Deploy to staging and prod
5. ✅ Create runbook for alert responses
6. ✅ Review alert history monthly and tune thresholds

## References

- [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/)
- [Module README](./modules/monitoring-alerts/README.md)
- [Azure Monitor Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices-alerts)
- [Alert Troubleshooting](https://learn.microsoft.com/azure/azure-monitor/alerts/alerts-troubleshoot)
