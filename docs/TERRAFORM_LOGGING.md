# Infrastructure Logging with Log Analytics

## Overview

This infrastructure now includes comprehensive diagnostic logging using Azure Log Analytics workspace and Application Insights. All major Azure resources send their logs and metrics to a centralized Log Analytics workspace for monitoring, troubleshooting, and analysis.

## Architecture

### Log Analytics Workspace
- **Purpose**: Central repository for all infrastructure logs and metrics
- **Retention**: Configurable via `log_retention_days` variable (default: 30 days, range: 30-730 days)
- **SKU**: PerGB2018 (pay-per-GB ingestion)

### Application Insights
- **Purpose**: Application performance monitoring and telemetry
- **Integration**: Linked to Log Analytics workspace
- **Connection**: Automatically configured in App Service web apps via environment variables

## Resources with Diagnostic Settings

### 1. Azure App Service (Web Apps)
**Logs Collected:**
- `AppServiceHTTPLogs` - HTTP access logs
- `AppServiceConsoleLogs` - Console output from applications
- `AppServiceAppLogs` - Application-generated logs
- `AppServicePlatformLogs` - Platform-level operational logs
- `AppServiceAuditLogs` - Authentication and authorization audit logs
- `AppServiceIPSecAuditLogs` - IP security audit logs
- `AppServiceFileAuditLogs` - File change audit logs

**Metrics:**
- `AllMetrics` - CPU, memory, network, HTTP request metrics

**Resources:**
- API Web App (`grooveapp-<env>-api`)
- Frontend Web App (`grooveapp-<env>-frontend`)

### 2. Azure SQL Database
**Server Logs:**
- `SQLSecurityAuditEvents` - Security audit events
- `DevOpsOperationsAudit` - DevOps operational audit events

**Database Logs:**
- `SQLInsights` - Intelligent insights and recommendations
- `AutomaticTuning` - Automatic tuning operations
- `QueryStoreRuntimeStatistics` - Query performance statistics
- `QueryStoreWaitStatistics` - Query wait statistics
- `Errors` - SQL errors
- `DatabaseWaitStatistics` - Database wait statistics
- `Timeouts` - Query timeouts
- `Blocks` - Blocking sessions
- `Deadlocks` - Deadlock events

**Metrics:**
- Server and database performance metrics

### 3. PostgreSQL Flexible Server
**Logs Collected:**
- `PostgreSQLLogs` - PostgreSQL server logs

**Metrics:**
- Connection, CPU, memory, storage metrics

### 4. Cosmos DB
**Logs Collected:**
- `DataPlaneRequests` - Data operation requests
- `QueryRuntimeStatistics` - Query execution statistics
- `PartitionKeyStatistics` - Partition key distribution
- `PartitionKeyRUConsumption` - RU consumption per partition key
- `ControlPlaneRequests` - Management operation requests

**Metrics:**
- `Requests` - Request metrics and throughput

### 5. Azure Container Registry
**Logs Collected:**
- `ContainerRegistryRepositoryEvents` - Push, pull, delete operations
- `ContainerRegistryLoginEvents` - Authentication events

**Metrics:**
- Storage, pull/push metrics

## Configuration

### Variables

```hcl
# Log retention period
variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace"
  type        = number
  default     = 30
}
```

### Application Insights Integration

The following environment variables are automatically added to App Service web apps:
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Connection string for Application Insights
- `ApplicationInsightsAgent_EXTENSION_VERSION` - Version ~3 of the Application Insights extension

## Querying Logs

### Access Log Analytics Workspace

1. Navigate to Azure Portal
2. Go to Resource Group → Log Analytics Workspace
3. Select "Logs" from the left menu

### Sample KQL Queries

#### View All HTTP Requests to Web Apps
```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, CsHost, CsMethod, CsUriStem, ScStatus, TimeTaken
| order by TimeGenerated desc
```

#### Application Errors
```kql
AppServiceAppLogs
| where TimeGenerated > ago(1h)
| where Level == "Error"
| project TimeGenerated, Message, ExceptionClass, ExceptionMessage
| order by TimeGenerated desc
```

#### SQL Database Performance
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "QueryStoreRuntimeStatistics"
| project TimeGenerated, query_hash_s, avg_duration_s, avg_cpu_time_s
| order by TimeGenerated desc
```

#### Container Registry Activity
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.CONTAINERREGISTRY"
| where Category == "ContainerRegistryRepositoryEvents"
| project TimeGenerated, OperationName, repository_s, tag_s
| order by TimeGenerated desc
```

#### Cosmos DB Request Metrics
```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.DOCUMENTDB"
| where Category == "DataPlaneRequests"
| project TimeGenerated, OperationName, requestCharge_s, statusCode_s
| summarize avg(todouble(requestCharge_s)) by bin(TimeGenerated, 5m)
```

## Monitoring and Alerts

### Recommended Alerts

You can create alerts based on log queries:

1. **High HTTP Error Rate**
   - Query: `AppServiceHTTPLogs | where ScStatus >= 500`
   - Threshold: More than 10 errors in 5 minutes

2. **Application Errors**
   - Query: `AppServiceAppLogs | where Level == "Error"`
   - Threshold: Any error occurrence

3. **SQL Deadlocks**
   - Query: `AzureDiagnostics | where Category == "Deadlocks"`
   - Threshold: Any deadlock occurrence

4. **Container Registry Failed Logins**
   - Query: `AzureDiagnostics | where Category == "ContainerRegistryLoginEvents" | where loginResult_s != "success"`
   - Threshold: More than 5 failed logins in 10 minutes

## Costs

Log Analytics workspace pricing is based on:
- **Data Ingestion**: Per GB of data ingested
- **Data Retention**: Free for first 30 days, charged per GB/month beyond that
- **Data Export**: Charges apply for exporting data

Application Insights is included with the Log Analytics workspace pricing.

**Cost Optimization Tips:**
- Adjust retention period based on compliance requirements
- Filter diagnostic settings to only essential log categories
- Use sampling for high-volume applications
- Archive old logs to Azure Storage for long-term retention

## Terraform Module Structure

```
modules/
└── log-analytics/
    ├── main.tf       # Log Analytics workspace and Application Insights resources
    ├── variables.tf  # Input variables
    └── outputs.tf    # Output values (workspace ID, connection strings, etc.)
```

## Deployment

The Log Analytics workspace is automatically created when deploying the infrastructure:

```bash
cd infra/terraform
terraform init
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

## Outputs

After deployment, retrieve monitoring information:

```bash
# Get Log Analytics workspace name
terraform output log_analytics_workspace_name

# Get Application Insights connection string (sensitive)
terraform output -raw application_insights_connection_string
```

## Best Practices

1. **Regular Review**: Review logs regularly for security and performance issues
2. **Retention Policy**: Set appropriate retention based on compliance requirements
3. **Alerting**: Configure alerts for critical events
4. **Query Optimization**: Use time ranges in queries to reduce processing
5. **Workspace Security**: Restrict access to Log Analytics workspace using Azure RBAC
6. **Data Export**: Export critical logs to Storage Account for long-term archival
7. **Query Performance**: Use summarize and where clauses to filter data early

## Troubleshooting

### No Logs Appearing
1. Verify diagnostic settings are enabled for resources
2. Check that Log Analytics workspace ID is correctly configured
3. Wait 5-15 minutes for initial log ingestion
4. Verify resource is generating activity

### Missing Log Categories
1. Review diagnostic settings on the resource
2. Ensure all desired log categories are enabled
3. Some categories require specific resource SKUs or configurations

### High Costs
1. Review data ingestion volume by resource
2. Disable verbose log categories if not needed
3. Adjust retention period to minimum required
4. Consider using basic logs tier for specific tables

## Additional Resources

- [Azure Monitor documentation](https://docs.microsoft.com/azure/azure-monitor/)
- [Log Analytics query language (KQL)](https://docs.microsoft.com/azure/data-explorer/kusto/query/)
- [Application Insights documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure diagnostic settings](https://docs.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
