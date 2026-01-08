# Azure Monitor Baseline Alerts - Implementation Summary

## ✅ What's Been Created

A complete Terraform module implementing **Azure Monitor Baseline Alerts (AMBA)** best practices for your GrooveApp infrastructure.

### 📁 Files Created

```
infra/terraform/
├── modules/monitoring-alerts/
│   ├── main.tf                          # 20+ AMBA-compliant alert rules
│   ├── variables.tf                     # Module configuration
│   ├── outputs.tf                       # Module outputs
│   └── README.md                        # Complete module documentation
│
├── MONITORING_IMPLEMENTATION_GUIDE.md   # Step-by-step setup guide
├── EXAMPLE-monitoring-integration.tf    # How to add to main.tf
├── EXAMPLE-monitoring-variables.tf      # Variables to add
└── EXAMPLE-dev-monitoring.tfvars        # Example tfvars config
```

## 🎯 Alerts Implemented (AMBA-Compliant)

### App Service Plan (3 alerts)
- ⚠️ CPU > 90%
- ⚠️ Memory > 90%
- ⚠️ HTTP Queue > 100 requests

### Web Apps - API & Frontend (10 alerts total)
- ⚠️ Response Time > 60 seconds
- 🚨 HTTP 5xx errors > 10 in 15 min
- 🚨 HTTP 4xx errors avg > 5 in 30 min
- ⚠️ Memory > 1.5 GB
- ⚠️ CPU Time > 120 seconds

### SQL Database (6 alerts)
- ⚠️ CPU > 80%
- ⚠️ Memory > 90%
- ⚠️ Failed Connections > 5
- ⚠️ Deadlocks > 1
- ⚠️ Storage > 870 GB
- 🔔 Firewall Blocks > 5

### Container Registry (1 alert)
- ⚠️ Storage > 400 GB

**Total: ~20 production-ready alerts**

## 🚀 Quick Start

### 1. Add Variables
```bash
# Copy monitoring variables to your variables.tf
cat EXAMPLE-monitoring-variables.tf >> variables.tf
```

### 2. Configure Email Notifications
Edit `environments/dev.tfvars`:
```hcl
alert_email_receivers = [
  {
    name          = "Matthew Grimshaw"
    email_address = "matgri@microsoft.com"
  }
]

enable_app_service_plan_alerts = true
enable_web_app_alerts          = true
enable_sql_alerts              = true
enable_acr_alerts              = true
```

### 3. Add Module to main.tf
Copy the module block from `EXAMPLE-monitoring-integration.tf` to your `main.tf`.

### 4. Deploy
```bash
cd infra/terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### 5. Test
```bash
# Send test alert
az monitor action-group test-notifications create \
  --resource-group rg-grooveapp-dev-uhxg \
  --action-group-name grooveapp-dev-alerts \
  --notification-type Email \
  --alert-type servicehealth
```

## 💰 Cost

- **~$2-3/month** for all alerts
- Very cost-effective production monitoring!

## 📧 Notification Options

### Email (Included)
- Instant alerts to any email address
- Multiple receivers supported

### Microsoft Teams (Optional)
```hcl
alert_webhook_receivers = [
  {
    name        = "Teams DevOps"
    service_uri = "https://outlook.office.com/webhook/YOUR-URL"
  }
]
```

### Slack (Optional)
```hcl
alert_webhook_receivers = [
  {
    name        = "Slack DevOps"
    service_uri = "https://hooks.slack.com/services/YOUR/URL"
  }
]
```

## 📊 Alert Severity Levels

| Level | Icon | Description | Example |
|-------|------|-------------|---------|
| 1 | 🚨 | Error - Major degradation | HTTP 5xx errors |
| 2 | 🔔 | Warning - Potential issues | Firewall blocks |
| 3 | ⚠️ | Info - Performance metrics | CPU/memory thresholds |

## 📖 Full Documentation

- **Implementation Guide**: [MONITORING_IMPLEMENTATION_GUIDE.md](./MONITORING_IMPLEMENTATION_GUIDE.md)
- **Module README**: [modules/monitoring-alerts/README.md](./modules/monitoring-alerts/README.md)
- **AMBA Reference**: https://azure.github.io/azure-monitor-baseline-alerts/services/

## 🎓 Key Benefits

✅ **Production-Ready**: Based on Microsoft's recommended thresholds
✅ **Comprehensive**: Covers all GrooveApp resources
✅ **Flexible**: Easy to customize thresholds and enable/disable per environment
✅ **Cost-Effective**: ~$3/month for complete monitoring
✅ **Well-Documented**: Full implementation guide and examples included
✅ **Best Practices**: Follows Azure Monitor recommended practices

## 🛠️ Next Steps

1. Review [MONITORING_IMPLEMENTATION_GUIDE.md](./MONITORING_IMPLEMENTATION_GUIDE.md)
2. Configure email receivers in tfvars
3. Deploy to dev environment
4. Test notifications
5. Deploy to staging and production

## 📞 Support

For questions or issues:
- Check the implementation guide
- Review module README
- Consult AMBA documentation: https://azure.github.io/azure-monitor-baseline-alerts/
